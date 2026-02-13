package main

import (
	"database/sql"
	"eatclean/internal/config"
	"eatclean/internal/handler"
	"eatclean/internal/middleware"
	"eatclean/internal/repository"
	"eatclean/internal/service"
	"fmt"
	"log"

	"github.com/labstack/echo/v4"
	echomiddleware "github.com/labstack/echo/v4/middleware"
	_ "github.com/lib/pq"
)

func main() {
	// 加载配置
	cfg, err := config.Load()
	if err != nil {
		log.Fatal("Failed to load config:", err)
	}

	// 连接数据库
	db, err := sql.Open("postgres", cfg.Database.DSN())
	if err != nil {
		log.Fatal("Failed to connect to database:", err)
	}
	defer db.Close()

	// 测试数据库连接
	if err := db.Ping(); err != nil {
		log.Fatal("Failed to ping database:", err)
	}
	log.Println("Database connected successfully")

	// 初始化 repositories
	userRepo := repository.NewUserRepository(db)
	settingsRepo := repository.NewSettingsRepository(db)
	mealRecordRepo := repository.NewMealRecordRepository(db)
	menuScanRepo := repository.NewMenuScanRepository(db)
	chatMessageRepo := repository.NewChatMessageRepository(db)
	dailyIntakeRepo := repository.NewDailyIntakeRepository(db)
	dishRepo := repository.NewDishRepository(db)
	weeklyMenuRepo := repository.NewWeeklyMenuRepository(db)
	subscriptionRepo := repository.NewSubscriptionRepository(db)

	// 初始化 services
	authService := service.NewAuthService(userRepo, &cfg.JWT, &cfg.Apple)
	menuService := service.NewMenuService()
	settingsService := service.NewSettingsService(settingsRepo)
	mealRecordService := service.NewMealRecordService(mealRecordRepo)
	menuScanService := service.NewMenuScanService(menuScanRepo)
	visionService := service.NewVisionService(&cfg.Qwen)
	chatAIService := service.NewChatAIService(&cfg.Qwen)
	ossService := service.NewOssService(&cfg.OSS)
	chatMessageService := service.NewChatMessageService(chatMessageRepo)
	dailyIntakeService := service.NewDailyIntakeService(dailyIntakeRepo)
	dishService := service.NewDishService(dishRepo)
	weeklyMenuService := service.NewWeeklyMenuService(weeklyMenuRepo)
	subscriptionService := service.NewSubscriptionService(subscriptionRepo)

	// 初始化 handlers
	authHandler := handler.NewAuthHandler(authService, settingsService, subscriptionService)
	menuHandler := handler.NewMenuHandler(menuService, menuScanService, visionService, ossService, settingsService, dishService, mealRecordService, dailyIntakeService, subscriptionService)
	settingsHandler := handler.NewSettingsHandler(settingsService)
	mealRecordHandler := handler.NewMealRecordHandler(mealRecordService, visionService, ossService, settingsService, dishService, dailyIntakeService, subscriptionService)
	ossHandler := handler.NewOssHandler(ossService, &cfg.OSS)
	chatHandler := handler.NewChatMessageHandler(chatMessageService, ossService)
	chatCompleteHandler := handler.NewChatCompleteHandler(chatAIService, settingsService, chatMessageService, ossService, mealRecordService, dailyIntakeService, subscriptionService)
	dailyIntakeHandler := handler.NewDailyIntakeHandler(dailyIntakeService)
	discoverHandler := handler.NewDiscoverHandler(chatAIService, settingsService, dishService, mealRecordService, weeklyMenuService, dailyIntakeService, subscriptionService)
	subscriptionHandler := handler.NewSubscriptionHandler(subscriptionService, &cfg.Apple)
	usageHandler := handler.NewUsageHandler(menuScanService, mealRecordService, chatMessageService, subscriptionService)
	foodHandler := handler.NewFoodHandler(dishRepo, chatAIService)

	// 创建 Echo 实例
	e := echo.New()

	// 中间件
	e.Use(echomiddleware.Logger())
	e.Use(echomiddleware.Recover())
	e.Use(echomiddleware.CORS())

	// 健康检查
	e.GET("/health", func(c echo.Context) error {
		return c.JSON(200, map[string]string{"status": "ok"})
	})

	// API 路由
	api := e.Group("/eatclean/api/v1")

	// 认证路由（无需 JWT）
	auth := api.Group("/auth")
	auth.POST("/login", authHandler.Login)
	auth.POST("/register", authHandler.Register)

	// 需要认证的路由
	protected := api.Group("")
	protected.Use(middleware.JWTAuth(authService))

	quotaGuard := middleware.UsageQuotaGuard(
		menuScanService,
		mealRecordService,
		chatMessageService,
		subscriptionService,
	)

	metered := protected.Group("")
	metered.Use(quotaGuard)
	protected.GET("/auth/profile", authHandler.GetProfile)
	protected.POST("/auth/profile/nickname", authHandler.UpdateNickname)
	protected.POST("/user/avatar", authHandler.UpdateAvatar)
	metered.POST("/menu/parse", menuHandler.ParseMenu)
	metered.POST("/menu/scan", menuHandler.ScanImages)
	protected.POST("/user/settings", settingsHandler.Upsert)
	protected.GET("/user/settings", settingsHandler.Get)
	protected.POST("/meals", mealRecordHandler.Create)
	metered.POST("/meals/photo", mealRecordHandler.CreateFromPhoto)
	metered.POST("/meals/analyze", mealRecordHandler.AnalyzeFromPhoto)
	metered.POST("/ingredients/scan", mealRecordHandler.ScanIngredients)
	protected.GET("/meals", mealRecordHandler.List)
	protected.POST("/intake/daily", dailyIntakeHandler.UpsertDailyIntake)
	metered.GET("/oss/sts", ossHandler.GetSTS)
	metered.POST("/oss/sign", ossHandler.SignURLs)
	metered.POST("/chat/messages", chatHandler.Create)
	protected.GET("/chat/messages", chatHandler.List)
	metered.POST("/chat/complete", chatCompleteHandler.Complete)
	metered.POST("/discover/recommendations", discoverHandler.Recommendations)
	metered.POST("/discover/replace", discoverHandler.Replace)
	metered.POST("/discover/weekly/generate", discoverHandler.GenerateWeeklyMenus)
	metered.POST("/discover/weekly/save", discoverHandler.SaveWeeklyMenus)
	metered.POST("/food/search", foodHandler.Search)
	protected.POST("/subscription/verify", subscriptionHandler.Verify)
	protected.POST("/subscription/restore", subscriptionHandler.Restore)
	protected.POST("/usage/check", usageHandler.Check)

	// 启动服务器
	addr := fmt.Sprintf(":%s", cfg.Server.Port)
	log.Printf("Server starting on %s", addr)
	if err := e.Start(addr); err != nil {
		log.Fatal("Failed to start server:", err)
	}
}
