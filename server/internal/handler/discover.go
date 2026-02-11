package handler

import (
	"context"
	"eatclean/internal/service"
	"eatclean/pkg/response"
	"encoding/json"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/labstack/echo/v4"
)

type DiscoverHandler struct {
	aiService       *service.ChatAIService
	settingsService *service.SettingsService
	dishService     *service.DishService
	mealService     *service.MealRecordService
	weeklyMenu      *service.WeeklyMenuService
	dailyService    *service.DailyIntakeService
	subscriptions   *service.SubscriptionService
}

func NewDiscoverHandler(
	aiService *service.ChatAIService,
	settingsService *service.SettingsService,
	dishService *service.DishService,
	mealService *service.MealRecordService,
	weeklyMenu *service.WeeklyMenuService,
	dailyService *service.DailyIntakeService,
	subscriptions *service.SubscriptionService,
) *DiscoverHandler {
	return &DiscoverHandler{
		aiService:       aiService,
		settingsService: settingsService,
		dishService:     dishService,
		mealService:     mealService,
		weeklyMenu:      weeklyMenu,
		dailyService:    dailyService,
		subscriptions:   subscriptions,
	}
}

// Recommendations 发现页推荐
// POST /api/v1/discover/recommendations
func (h *DiscoverHandler) Recommendations(c echo.Context) error {
	userID, ok := c.Get("user_id").(int64)
	if !ok {
		return response.Unauthorized(c, "invalid user context")
	}
	if h.aiService == nil || !h.aiService.IsEnabled() {
		return response.InternalError(c, "ai service is not configured")
	}
	var req struct {
		PlanMode      string `json:"plan_mode"`
		Weekday       int    `json:"weekday"`
		ClientTime    string `json:"client_time"`
		ForceGenerate bool   `json:"force_generate"`
	}
	_ = c.Bind(&req)
	clientTime := parseClientTime(req.ClientTime)
	forceGenerate := req.ForceGenerate

	mode := strings.TrimSpace(req.PlanMode)
	if mode == "" {
		mode = "weekly"
	}
	weekday := req.Weekday
	if weekday <= 0 || weekday > 7 {
		weekday = weekdayFromDate(clientTime)
	}

	isSubscriber := false
	if h.subscriptions != nil {
		if active, err := h.subscriptions.IsUserActive(userID); err == nil && active {
			isSubscriber = true
		}
	}
	if !isSubscriber {
		planMeals, recommendations := defaultWeeklyMenus(weekday)
		return response.Success(c, map[string]interface{}{
			"plan_meals":      planMeals,
			"recommendations": recommendations,
		})
	}
	weekStart := weekStartForDate(clientTime)
	targetDate := weekStart.AddDate(0, 0, weekday-1)
	if h.weeklyMenu != nil && h.weeklyMenu.IsEnabled() {
		if cached, err := h.weeklyMenu.Get(userID, weekStart, weekday); err == nil && cached != nil {
			planMeals := decodeDiscoverMeals(cached.PlanMeals)
			recommendations := decodeDiscoverMeals(cached.Recommendations)
			if len(planMeals) > 0 || len(recommendations) > 0 {
				return response.Success(c, map[string]interface{}{
					"plan_meals":      planMeals,
					"recommendations": recommendations,
				})
			}
		}
	}
	if !forceGenerate && startOfDay(targetDate).After(startOfDay(clientTime)) {
		return response.Success(c, map[string]interface{}{
			"plan_meals":      []interface{}{},
			"recommendations": []interface{}{},
		})
	}
	planMeals, recommendations, err := h.generateDiscoverMenus(
		c.Request().Context(),
		userID,
		mode,
		weekday,
		targetDate,
		clientTime,
	)
	if err != nil {
		c.Logger().Errorf("discover recommendations failed: %v", err)
		return response.InternalError(c, "failed to generate recommendations")
	}
	if h.dishService != nil {
		for _, meal := range append(append([]map[string]interface{}{}, planMeals...), recommendations...) {
			meal["name"] = readStringOr(meal["name"], readString(meal["title"]))
			_ = h.dishService.UpsertFromMap(meal)
		}
	}
	if h.weeklyMenu != nil && h.weeklyMenu.IsEnabled() {
		_ = h.weeklyMenu.Upsert(userID, weekStart, weekday, planMeals, recommendations)
	}

	return response.Success(c, map[string]interface{}{
		"plan_meals":      planMeals,
		"recommendations": recommendations,
	})
}

// Replace 生成替换餐食
// POST /api/v1/discover/replace
func (h *DiscoverHandler) Replace(c echo.Context) error {
	userID, ok := c.Get("user_id").(int64)
	if !ok {
		return response.Unauthorized(c, "invalid user context")
	}
	if h.aiService == nil || !h.aiService.IsEnabled() {
		return response.InternalError(c, "ai service is not configured")
	}
	var req map[string]interface{}
	if err := c.Bind(&req); err != nil {
		return response.BadRequest(c, "invalid request body")
	}
	clientTime := time.Now()
	if raw, ok := req["client_time"]; ok {
		clientTime = parseClientTime(fmt.Sprint(raw))
		delete(req, "client_time")
	}

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
				if template, err := service.LoadDiscoverReplacePromptTemplate(); err == nil {
					isTraining, isCheat := computeDayFlagsForDate(settings, clientTime)
					dayType := dayTypeLabel(isTraining, isCheat)
					timeOfDay := timeOfDayLabel(clientTime)
					intake := buildIntakeContext(h.dailyService, userID, clientTime, settings)
					settings["userId"] = userID
					systemPrompt = service.BuildSystemPrompt(template, settings, map[string]string{
						"menu_scanned":        "false",
						"food_photo_taken":    "false",
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
					})
				}
			}
		}
	}

	payload, _ := json.Marshal(req)
	prompt := fmt.Sprintf(`你需要为用户提供更健康的“替换餐食”方案。
请参考以下餐食卡片 JSON，给出 2-3 个更健康的替换方案。
必须输出 JSON（不要输出额外文本）：
{
  "meals": [
    {
      "title": "菜品名",
      "meal_type": "推荐",
      "calories": 360,
      "protein": 28,
      "fat": 9,
      "carbs": 38,
      "ingredients": ["食材1", "食材2"],
      "instructions": "简短做法",
      "benefits": "一句健康益处",
      "time_minutes": 12
    }
  ]
}
要求：
- 每个方案必须包含完整的 title、ingredients、instructions、benefits，不允许为空。
- 如果信息不足，请合理生成可执行的菜品名称与食材搭配，保持真实可做。
参考卡片：%s`, string(payload))

	reply, err := h.aiService.Chat(c.Request().Context(), systemPrompt, "", nil, prompt, nil)
	if err != nil {
		c.Logger().Errorf("discover replace failed: %v", err)
		return response.InternalError(c, "failed to generate replacements")
	}

	meals := parseDiscoverMeals(reply)
	if h.dishService != nil {
		for _, meal := range meals {
			meal["name"] = readStringOr(meal["name"], readString(meal["title"]))
			_ = h.dishService.UpsertFromMap(meal)
		}
	}

	return response.Success(c, map[string]interface{}{
		"meals": meals,
	})
}

// GenerateWeeklyMenus 手动生成本周菜单
// POST /api/v1/discover/weekly/generate
func (h *DiscoverHandler) GenerateWeeklyMenus(c echo.Context) error {
	userID, ok := c.Get("user_id").(int64)
	if !ok {
		return response.Unauthorized(c, "invalid user context")
	}
	if h.aiService == nil || !h.aiService.IsEnabled() {
		return response.InternalError(c, "ai service is not configured")
	}
	if h.weeklyMenu == nil || !h.weeklyMenu.IsEnabled() {
		return response.InternalError(c, "weekly menu store unavailable")
	}

	var req struct {
		ClientTime string `json:"client_time"`
		PlanMode   string `json:"plan_mode"`
		Weekday    int    `json:"weekday"`
	}
	_ = c.Bind(&req)
	clientTime := parseClientTime(req.ClientTime)
	mode := strings.TrimSpace(req.PlanMode)
	if mode == "" {
		mode = "weekly"
	}

	weekStart := weekStartForDate(clientTime)
	startDay := 1
	endDay := 7
	if req.Weekday >= 1 && req.Weekday <= 7 {
		startDay = req.Weekday
		endDay = req.Weekday
	}

	var respPlan []map[string]interface{}
	var respRecs []map[string]interface{}

	for weekday := startDay; weekday <= endDay; weekday++ {
		targetDate := weekStart.AddDate(0, 0, weekday-1)
		planMeals, recommendations, err := h.generateDiscoverMenus(
			c.Request().Context(),
			userID,
			mode,
			weekday,
			targetDate,
			clientTime,
		)
		if err != nil {
			c.Logger().Errorf("manual weekly menu generate failed (day %d): %v", weekday, err)
			return response.InternalError(c, "failed to generate weekly menu")
		}
		if h.dishService != nil {
			for _, meal := range append(append([]map[string]interface{}{}, planMeals...), recommendations...) {
				meal["name"] = readStringOr(meal["name"], readString(meal["title"]))
				_ = h.dishService.UpsertFromMap(meal)
			}
		}
		if err := h.weeklyMenu.Upsert(userID, weekStart, weekday, planMeals, recommendations); err != nil {
			c.Logger().Errorf("manual weekly menu upsert failed (day %d): %v", weekday, err)
			return response.InternalError(c, "failed to save weekly menu")
		}
		if weekday == startDay {
			respPlan = planMeals
			respRecs = recommendations
		}
	}

	return response.Success(c, map[string]interface{}{
		"week_start":      weekStart.Format("2006-01-02"),
		"weekday":         startDay,
		"plan_meals":      respPlan,
		"recommendations": respRecs,
	})
}

// SaveWeeklyMenus 保存本周菜单（用于客户端替换后同步）
// POST /api/v1/discover/weekly/save
func (h *DiscoverHandler) SaveWeeklyMenus(c echo.Context) error {
	userID, ok := c.Get("user_id").(int64)
	if !ok {
		return response.Unauthorized(c, "invalid user context")
	}
	if h.weeklyMenu == nil || !h.weeklyMenu.IsEnabled() {
		return response.InternalError(c, "weekly menu store unavailable")
	}

	var req map[string]interface{}
	if err := c.Bind(&req); err != nil {
		return response.BadRequest(c, "invalid request body")
	}

	clientTime := time.Now()
	if raw, ok := req["client_time"]; ok {
		clientTime = parseClientTime(fmt.Sprint(raw))
	}
	weekday := readInt(req["weekday"], 0)
	if weekday <= 0 || weekday > 7 {
		weekday = weekdayFromDate(clientTime)
	}
	rawMeals := req["plan_meals"]
	list := []map[string]interface{}{}
	switch v := rawMeals.(type) {
	case string:
		trimmed := strings.TrimSpace(v)
		if trimmed != "" {
			if err := json.Unmarshal([]byte(trimmed), &list); err != nil {
				return response.BadRequest(c, "invalid plan meals payload")
			}
		}
	default:
		if rawMeals != nil {
			payload, _ := json.Marshal(rawMeals)
			if err := json.Unmarshal(payload, &list); err != nil {
				return response.BadRequest(c, "invalid plan meals payload")
			}
		}
	}

	recommendations := []map[string]interface{}{}
	weekStart := weekStartForDate(clientTime)
	if existing, err := h.weeklyMenu.Get(userID, weekStart, weekday); err == nil && existing != nil {
		if len(existing.Recommendations) > 0 {
			_ = json.Unmarshal(existing.Recommendations, &recommendations)
		}
	}

	if err := h.weeklyMenu.Upsert(userID, weekStart, weekday, list, recommendations); err != nil {
		c.Logger().Errorf("weekly menu save failed: %v", err)
		return response.InternalError(c, "failed to save weekly menu")
	}

	if h.dishService != nil {
		for _, meal := range list {
			meal["name"] = readStringOr(meal["name"], readString(meal["title"]))
			_ = h.dishService.UpsertFromMap(meal)
		}
	}

	return response.Success(c, map[string]interface{}{
		"weekday": weekday,
	})
}

func (h *DiscoverHandler) generateDiscoverMenus(
	ctx context.Context,
	userID int64,
	mode string,
	weekday int,
	targetDate time.Time,
	clientTime time.Time,
) ([]map[string]interface{}, []map[string]interface{}, error) {
	if h.aiService == nil || !h.aiService.IsEnabled() {
		return nil, nil, errors.New("ai service is not configured")
	}

	recentMealSummary := ""
	if h.mealService != nil {
		if records, err := h.mealService.ListByUser(userID, 20); err == nil {
			recentMealSummary = service.SummarizeMealRecords(records, 3)
		}
	}
	if strings.TrimSpace(recentMealSummary) == "" {
		recentMealSummary = "暂无"
	}

	systemPrompt := h.buildDiscoverSystemPrompt(userID, targetDate, clientTime, recentMealSummary)

	prompt := fmt.Sprintf(`你正在为“元气食光”的发现页生成真实可执行的健康餐食推荐。
要求输出 JSON（不要输出额外文本）：
{
  "plan_meals": [
    {
      "title": "菜品名",
      "meal_type": "早餐/午餐/晚餐",
      "calories": 450,
      "protein": 35,
      "fat": 12,
      "carbs": 42,
      "ingredients": ["食材1", "食材2"],
      "instructions": "简短做法",
      "benefits": "一句健康益处",
      "time_minutes": 10
    }
  ],
  "recommendations": [
    {
      "title": "菜品名",
      "meal_type": "推荐",
      "calories": 380,
      "protein": 28,
      "fat": 10,
      "carbs": 40,
      "ingredients": ["食材1", "食材2"],
      "instructions": "简短做法",
      "benefits": "一句健康益处",
      "time_minutes": 12
    }
  ]
}
要求：
- 输出 3 道 plan_meals（早餐/午餐/晚餐各 1 道），以及 4 道 recommendations。
- 每一道必须包含完整的 title、ingredients、instructions、benefits，不允许为空或缺失。
- 如果用户设置中没有明确限制，也需要“合理生成”可执行的菜品名与食材组合，给出简洁做法。
- 输出必须是严格 JSON，不要输出解释文字或代码块。
计划模式：%s。今天是周%d。请根据用户设置、训练/放纵日状态调整营养结构。`, mode, weekday)

	reply, err := h.aiService.Chat(ctx, systemPrompt, "", nil, prompt, nil)
	if err != nil {
		return nil, nil, err
	}

	planMeals, recommendations := parseDiscoverPayload(reply)
	return planMeals, recommendations, nil
}

func (h *DiscoverHandler) buildDiscoverSystemPrompt(
	userID int64,
	targetDate time.Time,
	clientTime time.Time,
	recentMealSummary string,
) string {
	if h.settingsService == nil {
		return ""
	}
	raw, err := h.settingsService.Get(userID)
	if err != nil || len(raw) == 0 {
		return ""
	}
	var settings map[string]interface{}
	if err := json.Unmarshal(raw, &settings); err != nil {
		return ""
	}
	template, err := service.LoadDiscoverPlanPromptTemplate()
	if err != nil {
		return ""
	}
	isTraining, isCheat := computeDayFlagsForDate(settings, targetDate)
	dayType := dayTypeLabel(isTraining, isCheat)
	timeOfDay := timeOfDayLabel(clientTime)
	intake := buildIntakeContext(h.dailyService, userID, clientTime, settings)
	return service.BuildSystemPrompt(template, settings, map[string]string{
		"menu_scanned":        "false",
		"food_photo_taken":    "false",
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
	})
}

func parseDiscoverPayload(raw string) ([]map[string]interface{}, []map[string]interface{}) {
	payload := extractJSONPayload(raw)
	if payload == "" {
		return nil, nil
	}
	var decoded map[string]interface{}
	if err := json.Unmarshal([]byte(payload), &decoded); err == nil {
		planMeals := parseDiscoverList(decoded["plan_meals"])
		recommendations := parseDiscoverList(decoded["recommendations"])
		if len(recommendations) == 0 {
			recommendations = parseDiscoverList(decoded["meals"])
		}
		return planMeals, recommendations
	}
	var list []interface{}
	if err := json.Unmarshal([]byte(payload), &list); err == nil {
		return nil, parseDiscoverList(list)
	}
	return nil, nil
}

func parseDiscoverMeals(raw string) []map[string]interface{} {
	payload := extractJSONPayload(raw)
	if payload == "" {
		return nil
	}
	var decoded map[string]interface{}
	if err := json.Unmarshal([]byte(payload), &decoded); err == nil {
		if meals := parseDiscoverList(decoded["meals"]); len(meals) > 0 {
			return meals
		}
		if meals := parseDiscoverList(decoded["recommendations"]); len(meals) > 0 {
			return meals
		}
		return parseDiscoverList(decoded["plan_meals"])
	}
	var list []interface{}
	if err := json.Unmarshal([]byte(payload), &list); err == nil {
		return parseDiscoverList(list)
	}
	return nil
}

func parseDiscoverList(raw interface{}) []map[string]interface{} {
	items, ok := raw.([]interface{})
	if !ok || len(items) == 0 {
		return nil
	}
	results := make([]map[string]interface{}, 0, len(items))
	for idx, item := range items {
		row, ok := item.(map[string]interface{})
		if !ok {
			continue
		}
		readIntFromKeys := func(keys ...string) int {
			for _, key := range keys {
				if value, ok := row[key]; ok {
					if parsed := readInt(value, -1); parsed >= 0 {
						return parsed
					}
				}
			}
			return 0
		}
		title := readString(row["title"])
		if title == "" {
			title = readString(row["name"])
		}
		if title == "" {
			title = readString(row["dish_name"])
		}
		if title == "" {
			title = readString(row["meal_name"])
		}
		if title == "" {
			title = readString(row["dish"])
		}
		if title == "" {
			title = fmt.Sprintf("推荐餐食%d", idx+1)
		}
		mealType := readString(row["meal_type"])
		if mealType == "" {
			mealType = readString(row["type"])
		}
		if mealType == "" {
			mealType = "推荐"
		}
		ingredients := readStringList(row["ingredients"], row["components"])
		if len(ingredients) == 0 {
			ingredients = defaultIngredients(mealType)
		}
		instructions := readStringOr(row["instructions"], readString(row["steps"]))
		if strings.TrimSpace(instructions) == "" {
			instructions = defaultInstructions(mealType, title)
		}
		benefits := readStringOr(row["benefits"], readString(row["reason"]))
		if strings.TrimSpace(benefits) == "" {
			benefits = defaultBenefits(mealType)
		}
		results = append(results, map[string]interface{}{
			"id":           readStringOr(row["id"], fmt.Sprintf("discover_%d", idx)),
			"title":        title,
			"meal_type":    mealType,
			"calories":     clampInt(readIntFromKeys("calories", "kcal", "energy"), 0, 4000),
			"protein":      clampInt(readIntFromKeys("protein", "protein_g", "protein_grams"), 0, 400),
			"fat":          clampInt(readIntFromKeys("fat", "fat_g", "fat_grams"), 0, 200),
			"carbs":        clampInt(readIntFromKeys("carbs", "carb", "carbohydrates", "carbs_g"), 0, 600),
			"ingredients":  ingredients,
			"instructions": instructions,
			"benefits":     benefits,
			"time_minutes": clampInt(readInt(row["time_minutes"], readInt(row["time"], 10)), 1, 120),
		})
	}
	return results
}

func classifyMealType(mealType string) string {
	value := strings.TrimSpace(mealType)
	switch {
	case strings.Contains(value, "早餐") || strings.HasPrefix(value, "早"):
		return "breakfast"
	case strings.Contains(value, "午餐") || strings.HasPrefix(value, "午"):
		return "lunch"
	case strings.Contains(value, "晚餐") || strings.HasPrefix(value, "晚"):
		return "dinner"
	case strings.Contains(value, "加餐") || strings.Contains(value, "推荐") || strings.Contains(value, "零食") || strings.Contains(value, "小食"):
		return "snack"
	default:
		return "general"
	}
}

func defaultIngredients(mealType string) []string {
	switch classifyMealType(mealType) {
	case "breakfast":
		return []string{
			"燕麦片 50g",
			"脱脂牛奶 200ml",
			"鸡蛋 1 个",
			"蓝莓 50g",
			"混合坚果 10g",
		}
	case "lunch":
		return []string{
			"鸡胸肉 120g",
			"糙米饭 120g",
			"西兰花 100g",
			"胡萝卜 60g",
			"橄榄油 5ml",
		}
	case "dinner":
		return []string{
			"三文鱼 120g",
			"藜麦 80g",
			"菠菜 80g",
			"番茄 60g",
			"柠檬汁 少许",
		}
	case "snack":
		return []string{
			"希腊酸奶 150g",
			"香蕉 1/2 根",
			"奇亚籽 5g",
			"蜂蜜 1 茶匙",
		}
	default:
		return []string{
			"优质蛋白 120g",
			"时蔬 150g",
			"全谷物 80-120g",
			"橄榄油 5ml",
		}
	}
}

func defaultInstructions(mealType, title string) string {
	switch classifyMealType(mealType) {
	case "breakfast":
		return fmt.Sprintf("燕麦加牛奶小火煮 3-5 分钟，加入%s相关水果与坚果，搭配水煮蛋即可。", title)
	case "lunch":
		return fmt.Sprintf("%s中的蛋白食材煎至熟，糙米饭蒸热，西兰花胡萝卜焯水后拌少量橄榄油。", title)
	case "dinner":
		return fmt.Sprintf("%s的主蛋白煎/烤 6-8 分钟，藜麦煮熟，菠菜番茄轻炒或凉拌，挤少许柠檬汁。", title)
	case "snack":
		return "酸奶打底，加入水果切块与奇亚籽，冷藏 10 分钟口感更佳。"
	default:
		return fmt.Sprintf("按%s的食材组合清淡烹饪，优先蒸煮或少油翻炒，控制盐油用量。", title)
	}
}

func defaultBenefits(mealType string) string {
	switch classifyMealType(mealType) {
	case "breakfast":
		return "高纤维 + 优质蛋白，稳定血糖并提升饱腹。"
	case "lunch":
		return "蛋白充足，兼顾能量与训练恢复。"
	case "dinner":
		return "清淡易消化，降低晚间热量负担。"
	case "snack":
		return "高蛋白低负担，缓解饥饿并保护肌肉。"
	default:
		return "营养均衡，适合日常训练与恢复。"
	}
}

func currentWeekday() int {
	weekday := int(time.Now().Weekday())
	if weekday == 0 {
		weekday = 7
	}
	return weekday
}

func defaultWeeklyMenus(weekday int) ([]map[string]interface{}, []map[string]interface{}) {
	dayNames := []string{"周一", "周二", "周三", "周四", "周五", "周六", "周日"}
	dayLabel := dayNames[(weekday-1+7)%7]
	planMeals := []map[string]interface{}{
		{
			"id":           fmt.Sprintf("default_%d_breakfast", weekday),
			"title":        fmt.Sprintf("%s活力燕麦碗", dayLabel),
			"meal_type":    "早餐",
			"calories":     380,
			"protein":      20,
			"fat":          10,
			"carbs":        52,
			"ingredients":  defaultIngredients("早餐"),
			"instructions": defaultInstructions("早餐", "活力燕麦碗"),
			"benefits":     defaultBenefits("早餐"),
			"time_minutes": 10,
		},
		{
			"id":           fmt.Sprintf("default_%d_lunch", weekday),
			"title":        fmt.Sprintf("%s高蛋白轻食碗", dayLabel),
			"meal_type":    "午餐",
			"calories":     520,
			"protein":      42,
			"fat":          14,
			"carbs":        55,
			"ingredients":  defaultIngredients("午餐"),
			"instructions": defaultInstructions("午餐", "高蛋白轻食碗"),
			"benefits":     defaultBenefits("午餐"),
			"time_minutes": 18,
		},
		{
			"id":           fmt.Sprintf("default_%d_dinner", weekday),
			"title":        fmt.Sprintf("%s清爽低负担晚餐", dayLabel),
			"meal_type":    "晚餐",
			"calories":     430,
			"protein":      32,
			"fat":          12,
			"carbs":        45,
			"ingredients":  defaultIngredients("晚餐"),
			"instructions": defaultInstructions("晚餐", "清爽低负担晚餐"),
			"benefits":     defaultBenefits("晚餐"),
			"time_minutes": 16,
		},
	}
	recommendations := []map[string]interface{}{
		{
			"id":           fmt.Sprintf("default_%d_snack_1", weekday),
			"title":        "能量补给酸奶杯",
			"meal_type":    "加餐",
			"calories":     210,
			"protein":      16,
			"fat":          6,
			"carbs":        24,
			"ingredients":  defaultIngredients("加餐"),
			"instructions": defaultInstructions("加餐", "能量补给酸奶杯"),
			"benefits":     defaultBenefits("加餐"),
			"time_minutes": 6,
		},
		{
			"id":        fmt.Sprintf("default_%d_snack_2", weekday),
			"title":     "高纤维水果坚果盘",
			"meal_type": "加餐",
			"calories":  260,
			"protein":   8,
			"fat":       12,
			"carbs":     32,
			"ingredients": []string{
				"苹果 1/2 个",
				"香蕉 1/2 根",
				"杏仁 12g",
				"核桃 8g",
				"无糖酸奶 80g",
			},
			"instructions": "水果切块，搭配坚果与酸奶即可。",
			"benefits":     "补充膳食纤维与健康脂肪，提升饱腹。",
			"time_minutes": 5,
		},
	}
	return planMeals, recommendations
}

func weekdayFromDate(value time.Time) int {
	weekday := int(value.Weekday())
	if weekday == 0 {
		weekday = 7
	}
	return weekday
}

func weekStartForDate(value time.Time) time.Time {
	weekday := weekdayFromDate(value)
	start := value.AddDate(0, 0, -(weekday - 1))
	year, month, day := start.Date()
	return time.Date(year, month, day, 0, 0, 0, 0, start.Location())
}

func decodeDiscoverMeals(raw json.RawMessage) []map[string]interface{} {
	if len(raw) == 0 {
		return nil
	}
	var payload interface{}
	if err := json.Unmarshal(raw, &payload); err != nil {
		return nil
	}
	return parseDiscoverList(payload)
}

func computeDayFlagsForDate(settings map[string]interface{}, targetDate time.Time) (bool, bool) {
	weekday := weekdayFromDate(targetDate)
	dayOfMonth := targetDate.Day()

	trainingDays := readIntSlice(settings["monthly_training_days"])
	cheatDays := readIntSlice(settings["monthly_cheat_days"])
	if len(trainingDays) > 0 || len(cheatDays) > 0 {
		isTraining := containsInt(trainingDays, dayOfMonth)
		isCheat := containsInt(cheatDays, dayOfMonth)
		if isCheat {
			isTraining = false
		}
		return isTraining, isCheat
	}

	weeklyTrainingList := readIntSlice(settings["weekly_training_days_list"])
	weeklyCheatList := readIntSlice(settings["weekly_cheat_days_list"])
	if len(weeklyTrainingList) > 0 || len(weeklyCheatList) > 0 {
		isTraining := containsInt(weeklyTrainingList, weekday)
		isCheat := containsInt(weeklyCheatList, weekday)
		if isCheat {
			isTraining = false
		}
		return isTraining, isCheat
	}

	weeklyTraining := clampInt(readInt(settings["weekly_training_days"], 0), 0, 7)
	cheatFrequency := clampInt(readInt(settings["cheat_frequency"], 0), 0, 7)
	isTraining := weeklyTraining > 0 && weekday <= weeklyTraining
	isCheat := cheatFrequency > 0 && weekday > 7-cheatFrequency
	if isCheat {
		isTraining = false
	}
	return isTraining, isCheat
}

func formatYesNo(value bool) string {
	if value {
		return "是"
	}
	return "否"
}

func readIntSlice(value interface{}) []int {
	switch v := value.(type) {
	case []int:
		return append([]int(nil), v...)
	case []interface{}:
		out := make([]int, 0, len(v))
		for _, item := range v {
			out = append(out, readInt(item, 0))
		}
		return out
	case []string:
		out := make([]int, 0, len(v))
		for _, item := range v {
			if parsed, err := strconv.Atoi(strings.TrimSpace(item)); err == nil {
				out = append(out, parsed)
			}
		}
		return out
	case string:
		trimmed := strings.TrimSpace(v)
		if trimmed == "" {
			return nil
		}
		if strings.HasPrefix(trimmed, "[") {
			var decoded []interface{}
			if err := json.Unmarshal([]byte(trimmed), &decoded); err == nil {
				return readIntSlice(decoded)
			}
		}
		parts := strings.Split(trimmed, ",")
		out := make([]int, 0, len(parts))
		for _, part := range parts {
			if parsed, err := strconv.Atoi(strings.TrimSpace(part)); err == nil {
				out = append(out, parsed)
			}
		}
		return out
	}
	return nil
}

func containsInt(list []int, value int) bool {
	for _, item := range list {
		if item == value {
			return true
		}
	}
	return false
}
