package handler

import (
	"eatclean/internal/model"
	"eatclean/internal/service"
	"eatclean/pkg/response"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/labstack/echo/v4"
)

type MenuHandler struct {
	menuService     *service.MenuService
	menuScanService *service.MenuScanService
	visionService   *service.VisionService
	ossService      *service.OssService
	settingsService *service.SettingsService
	dishService     *service.DishService
	mealService     *service.MealRecordService
	dailyService    *service.DailyIntakeService
	subscriptions   *service.SubscriptionService
}

func NewMenuHandler(
	menuService *service.MenuService,
	menuScanService *service.MenuScanService,
	visionService *service.VisionService,
	ossService *service.OssService,
	settingsService *service.SettingsService,
	dishService *service.DishService,
	mealService *service.MealRecordService,
	dailyService *service.DailyIntakeService,
	subscriptions *service.SubscriptionService,
) *MenuHandler {
	return &MenuHandler{
		menuService:     menuService,
		menuScanService: menuScanService,
		visionService:   visionService,
		ossService:      ossService,
		settingsService: settingsService,
		dishService:     dishService,
		mealService:     mealService,
		dailyService:    dailyService,
		subscriptions:   subscriptions,
	}
}

// ParseMenu 解析菜单文本
// POST /api/v1/menu/parse
func (h *MenuHandler) ParseMenu(c echo.Context) error {
	req := new(model.MenuParseRequest)
	if err := c.Bind(req); err != nil {
		return response.BadRequest(c, "invalid request body")
	}
	req.Text = strings.TrimSpace(req.Text)
	if req.Text == "" {
		return response.BadRequest(c, "text is required")
	}

	result := h.menuService.ParseMenuText(req.Text)
	return response.Success(c, result)
}

// ScanImages 上传菜单图片
// POST /api/v1/menu/scan
func (h *MenuHandler) ScanImages(c echo.Context) error {
	userID, ok := c.Get("user_id").(int64)
	if !ok {
		return response.Unauthorized(c, "invalid user context")
	}
	req := new(model.MenuScanRequest)
	if err := c.Bind(req); err != nil {
		return response.BadRequest(c, "invalid request body")
	}
	if len(req.ImageUrls) == 0 {
		return response.BadRequest(c, "image_urls are required")
	}
	clientTime := parseClientTime(req.ClientTime)
	note := strings.TrimSpace(req.Note)
	if note == "" {
		note = "无"
	}
	if err := h.enforceMenuScanQuota(c, userID, clientTime); err != nil {
		return err
	}

	recognizedText := ""
	var aiSummary string
	var dishes []map[string]interface{}
	var actions []string
	signedUrls := req.ImageUrls
	if h.ossService != nil {
		if signed, err := h.ossService.SignURLs(req.ImageUrls, 15*time.Minute); err == nil {
			signedUrls = signed
		} else {
			return response.InternalError(c, "oss signing failed")
		}
	}
	if h.visionService != nil && h.visionService.IsEnabled() {
		recentMealSummary := ""
		if h.mealService != nil {
			if records, err := h.mealService.ListByUser(userID, 20); err == nil {
				recentMealSummary = service.SummarizeMealRecords(records, 3)
			}
		}
		if strings.TrimSpace(recentMealSummary) == "" {
			recentMealSummary = "暂无"
		}
		systemPrompt := ""
		if h.settingsService != nil {
			if raw, err := h.settingsService.Get(userID); err == nil && len(raw) > 0 {
				var settings map[string]interface{}
				if err := json.Unmarshal(raw, &settings); err == nil {
					if template, err := service.LoadMenuScanPromptTemplate(); err == nil {
						isTraining, isCheat := computeDayFlagsForDate(settings, clientTime)
						dayType := dayTypeLabel(isTraining, isCheat)
						timeOfDay := timeOfDayLabel(clientTime)
						intake := buildIntakeContext(h.dailyService, userID, clientTime, settings)
						systemPrompt = service.BuildSystemPrompt(template, settings, map[string]string{
							"food_photo_taken":    "false",
							"menu_scanned":        "true",
							"recent_chat_summary": "暂无",
							"recent_meal_summary": recentMealSummary,
							"current_time":        formatPromptTime(clientTime),
							"time_of_day":         timeOfDay,
							"day_type":            dayType,
							"is_training_day":     formatYesNo(isTraining),
							"is_cheat_day":        formatYesNo(isCheat),
							"calories_consumed":   intake.CaloriesConsumed,
							"macro_consumed":      intake.MacroConsumed,
							"calorie_remaining":   intake.CalorieRemaining,
							"menu_scan_note":      note,
						})
					}
				}
			}
		}

		text, err := h.visionService.AnalyzeMenuFromURLs(c.Request().Context(), signedUrls, systemPrompt)
		if err != nil {
			return response.InternalError(c, "menu recognition failed")
		}
		recognizedText = strings.TrimSpace(text)
		if parsedDishes, summary, parsedActions := parseAIDishes(recognizedText); len(parsedDishes) > 0 {
			dishes = parsedDishes
			aiSummary = summary
			actions = parsedActions
			if extracted := extractMenuText(recognizedText); extracted != "" {
				recognizedText = extracted
			}
		}
	} else {
		return response.InternalError(c, "vision service is not configured")
	}

	var parsedMenu []byte
	if len(dishes) == 0 {
		parsed := h.menuService.ParseMenuText(recognizedText)
		parsedMenu, _ = json.Marshal(parsed)
		for idx, item := range parsed.Items {
			dishes = append(dishes, map[string]interface{}{
				"id":          fmt.Sprintf("menu_%d_%d", time.Now().Unix(), idx),
				"name":        item.Name,
				"restaurant":  "菜单识别",
				"score":       72,
				"scoreLabel":  "待评估",
				"scoreColor":  "ff37f07a",
				"kcal":        0,
				"protein":     0,
				"carbs":       0,
				"fat":         0,
				"tag":         "菜单",
				"recommended": true,
				"reason":      "",
			})
		}
	}

	if h.dishService != nil {
		dishes = h.dishService.HydrateDishMapsPreferFresh(dishes)
	}

	if recognizedText == "" {
		var names []string
		for _, dish := range dishes {
			if name, ok := dish["name"].(string); ok && strings.TrimSpace(name) != "" {
				names = append(names, strings.TrimSpace(name))
			}
		}
		recognizedText = strings.Join(names, "\n")
	}
	parsedMenu, _ = json.Marshal(map[string]interface{}{
		"items":      dishes,
		"item_count": len(dishes),
		"raw_text":   recognizedText,
		"summary":    aiSummary,
	})

	var rawImageURL *string
	if len(req.ImageUrls) > 0 {
		rawImageURL = &req.ImageUrls[0]
	}
	var restaurantHint *string
	if strings.TrimSpace(req.RestaurantHint) != "" {
		value := strings.TrimSpace(req.RestaurantHint)
		restaurantHint = &value
	}

	scan := &model.MenuScan{
		UserID:         userID,
		RawImageURL:    rawImageURL,
		RawImageURLs:   mustMarshalJSON(req.ImageUrls),
		OCRText:        recognizedText,
		ParsedMenu:     parsedMenu,
		RestaurantHint: restaurantHint,
	}
	if h.menuScanService != nil {
		if err := h.menuScanService.Create(scan); err != nil {
			return response.InternalError(c, "failed to save menu scan")
		}
	}
	if len(actions) == 0 {
		actions = []string{"action=discover", "action=record_meal"}
	}

	return response.Success(c, map[string]interface{}{
		"scan_id":         scan.ID,
		"image_count":     len(req.ImageUrls),
		"recognized_text": recognizedText,
		"summary":         aiSummary,
		"actions":         actions,
		"items":           dishes,
	})
}

func (h *MenuHandler) enforceMenuScanQuota(
	c echo.Context,
	userID int64,
	clientTime time.Time,
) error {
	if h.menuScanService == nil {
		return nil
	}
	if h.subscriptions != nil {
		if active, err := h.subscriptions.IsUserActive(userID); err == nil && active {
			return nil
		}
	}
	start := startOfDay(clientTime)
	end := start.Add(24 * time.Hour)
	count, err := h.menuScanService.CountByUserBetween(userID, start, end)
	if err != nil {
		c.Logger().Errorf("menu scan quota check failed: %v", err)
		return response.InternalError(c, "usage check failed")
	}
	if count >= 1 {
		return response.Error(c, http.StatusTooManyRequests, "今日菜单扫描次数已用完，开通订阅可无限使用")
	}
	return nil
}

func extractMenuText(raw string) string {
	payload := extractJSONPayload(raw)
	if payload == "" {
		return ""
	}
	var decoded map[string]interface{}
	if err := json.Unmarshal([]byte(payload), &decoded); err != nil {
		return ""
	}
	if text, ok := decoded["recognized_text"].(string); ok {
		return strings.TrimSpace(text)
	}
	return ""
}
