package handler

import (
	"eatclean/internal/model"
	"eatclean/internal/service"
	"eatclean/pkg/response"
	"encoding/json"
	"fmt"
	"math"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/labstack/echo/v4"
)

type MealRecordHandler struct {
	service         *service.MealRecordService
	visionService   *service.VisionService
	ossService      *service.OssService
	settingsService *service.SettingsService
	dishService     *service.DishService
	dailyService    *service.DailyIntakeService
	subscriptions   *service.SubscriptionService
}

func NewMealRecordHandler(service *service.MealRecordService, visionService *service.VisionService, ossService *service.OssService, settingsService *service.SettingsService, dishService *service.DishService, dailyService *service.DailyIntakeService, subscriptions *service.SubscriptionService) *MealRecordHandler {
	return &MealRecordHandler{
		service:         service,
		visionService:   visionService,
		ossService:      ossService,
		settingsService: settingsService,
		dishService:     dishService,
		dailyService:    dailyService,
		subscriptions:   subscriptions,
	}
}

// Create 记录用餐
// POST /api/v1/meals
func (h *MealRecordHandler) Create(c echo.Context) error {
	userID, ok := c.Get("user_id").(int64)
	if !ok {
		return response.Unauthorized(c, "invalid user context")
	}

	req := new(model.MealRecordCreateRequest)
	if err := c.Bind(req); err != nil {
		return response.BadRequest(c, "invalid request body")
	}
	req.Source = strings.TrimSpace(req.Source)
	if req.Source == "" {
		return response.BadRequest(c, "source is required")
	}

	items := req.Items
	if len(items) == 0 {
		items = json.RawMessage("[]")
	}
	imageUrls := mustMarshalJSON(req.ImageUrls)
	recordedAt := time.Now()
	if req.RecordedAt != nil {
		recordedAt = *req.RecordedAt
	}

	record := &model.MealRecord{
		UserID:     userID,
		Source:     req.Source,
		Items:      items,
		ImageUrls:  imageUrls,
		Ratings:    req.Ratings,
		Meta:       req.Meta,
		RecordedAt: recordedAt,
	}
	if err := h.service.Create(record); err != nil {
		if isForeignKeyViolation(err) {
			return response.Unauthorized(c, "user not found, please re-login")
		}
		c.Logger().Errorf("meal record create failed: %v", err)
		return response.InternalError(c, "failed to create meal record")
	}

	return response.Success(c, record)
}

// CreateFromPhoto 记录食物照片
// POST /api/v1/meals/photo
func (h *MealRecordHandler) CreateFromPhoto(c echo.Context) error {
	userID, ok := c.Get("user_id").(int64)
	if !ok {
		return response.Unauthorized(c, "invalid user context")
	}
	var req struct {
		ImageUrls  []string `json:"image_urls"`
		ClientTime string   `json:"client_time"`
		Note       string   `json:"note"`
	}
	if err := c.Bind(&req); err != nil {
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
	if err := h.enforceMealPhotoQuota(c, userID, clientTime); err != nil {
		return err
	}

	recognizedText := ""
	var dishNames []string
	var aiSummary string
	signedUrls := req.ImageUrls
	if h.ossService != nil {
		if signed, err := h.ossService.SignURLs(req.ImageUrls, 15*time.Minute); err == nil {
			signedUrls = signed
		} else {
			c.Logger().Errorf("oss signing failed: %v", err)
			return response.InternalError(c, "oss signing failed")
		}
	}
	if h.visionService != nil && h.visionService.IsEnabled() {
		recentMealSummary := ""
		if h.service != nil {
			if records, err := h.service.ListByUser(userID, 20); err == nil {
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
					if template, err := service.LoadFoodScanPromptTemplate(); err == nil {
						isTraining, isCheat := computeDayFlagsForDate(settings, clientTime)
						dayType := dayTypeLabel(isTraining, isCheat)
						timeOfDay := timeOfDayLabel(clientTime)
						intake := buildIntakeContext(h.dailyService, userID, clientTime, settings)
						systemPrompt = service.BuildSystemPrompt(template, settings, map[string]string{
							"food_photo_taken":    "true",
							"menu_scanned":        "false",
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
							"food_photo_note":     note,
						})
					}
				}
			}
		}

		text, err := h.visionService.AnalyzeFoodFromURLs(c.Request().Context(), signedUrls, systemPrompt)
		if err != nil {
			c.Logger().Errorf("food recognition failed: %v", err)
			return response.InternalError(c, "food recognition failed")
		}
		recognizedText = strings.TrimSpace(text)
		if dishes, summary, _ := parseAIDishes(recognizedText); len(dishes) > 0 {
			if h.dishService != nil {
				dishes = h.dishService.HydrateDishMapsPreferFresh(dishes)
			}
			aiSummary = summary
			meta, _ := json.Marshal(map[string]interface{}{
				"image_count":     len(req.ImageUrls),
				"image_urls":      req.ImageUrls,
				"source":          "food_photo",
				"recognized_text": recognizedText,
				"ai_summary":      aiSummary,
				"note":            note,
			})
			record := &model.MealRecord{
				UserID:     userID,
				Source:     "food",
				Items:      mustMarshalJSON(dishes),
				ImageUrls:  mustMarshalJSON(req.ImageUrls),
				Meta:       meta,
				RecordedAt: time.Now(),
			}
			if err := h.service.Create(record); err != nil {
				if isForeignKeyViolation(err) {
					return response.Unauthorized(c, "user not found, please re-login")
				}
				c.Logger().Errorf("meal photo record create failed: %v", err)
				return response.InternalError(c, "failed to create meal record")
			}
			return response.Success(c, record)
		}

		for _, line := range strings.Split(recognizedText, "\n") {
			name := strings.TrimSpace(strings.TrimPrefix(line, "-"))
			if name == "" {
				continue
			}
			dishNames = append(dishNames, name)
		}
	} else {
		return response.InternalError(c, "vision service is not configured")
	}

	dishes := make([]map[string]interface{}, 0, len(dishNames))
	for idx, name := range dishNames {
		dishes = append(dishes, map[string]interface{}{
			"id":          fmt.Sprintf("photo_%d_%d", time.Now().Unix(), idx),
			"name":        name,
			"restaurant":  "照片识别",
			"score":       72,
			"scoreLabel":  "待确认",
			"scoreColor":  "ff13ec5b",
			"kcal":        0,
			"protein":     0,
			"carbs":       0,
			"fat":         0,
			"tag":         "识别结果",
			"recommended": true,
		})
	}

	if h.dishService != nil {
		dishes = h.dishService.HydrateDishMapsPreferFresh(dishes)
	}

	meta, _ := json.Marshal(map[string]interface{}{
		"image_count":     len(req.ImageUrls),
		"image_urls":      req.ImageUrls,
		"source":          "food_photo",
		"recognized_text": recognizedText,
		"ai_summary":      aiSummary,
		"note":            note,
	})

	record := &model.MealRecord{
		UserID:     userID,
		Source:     "food",
		Items:      mustMarshalJSON(dishes),
		ImageUrls:  mustMarshalJSON(req.ImageUrls),
		Meta:       meta,
		RecordedAt: time.Now(),
	}
	if err := h.service.Create(record); err != nil {
		if isForeignKeyViolation(err) {
			return response.Unauthorized(c, "user not found, please re-login")
		}
		c.Logger().Errorf("meal photo record create failed: %v", err)
		return response.InternalError(c, "failed to create meal record")
	}
	return response.Success(c, record)
}

// AnalyzeFromPhoto 仅分析食物照片，不直接入库
// POST /api/v1/meals/analyze
func (h *MealRecordHandler) AnalyzeFromPhoto(c echo.Context) error {
	userID, ok := c.Get("user_id").(int64)
	if !ok {
		return response.Unauthorized(c, "invalid user context")
	}
	var req struct {
		ImageUrls  []string `json:"image_urls"`
		ClientTime string   `json:"client_time"`
		Note       string   `json:"note"`
	}
	if err := c.Bind(&req); err != nil {
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

	signedUrls := req.ImageUrls
	if h.ossService != nil {
		if signed, err := h.ossService.SignURLs(req.ImageUrls, 15*time.Minute); err == nil {
			signedUrls = signed
		} else {
			c.Logger().Errorf("oss signing failed: %v", err)
			return response.InternalError(c, "oss signing failed")
		}
	}
	if h.visionService == nil || !h.visionService.IsEnabled() {
		return response.InternalError(c, "vision service is not configured")
	}

	systemPrompt := ""
	if h.settingsService != nil {
		if raw, err := h.settingsService.Get(userID); err == nil && len(raw) > 0 {
			var settings map[string]interface{}
			if err := json.Unmarshal(raw, &settings); err == nil {
				recentMealSummary := "暂无"
				if h.service != nil {
					if records, err := h.service.ListByUser(userID, 20); err == nil {
						if summary := service.SummarizeMealRecords(records, 5); strings.TrimSpace(summary) != "" {
							recentMealSummary = summary
						}
					}
				}
				if template, err := service.LoadFoodScanPromptTemplate(); err == nil {
					isTraining, isCheat := computeDayFlagsForDate(settings, clientTime)
					dayType := dayTypeLabel(isTraining, isCheat)
					timeOfDay := timeOfDayLabel(clientTime)
					intake := buildIntakeContext(h.dailyService, userID, clientTime, settings)
					systemPrompt = service.BuildSystemPrompt(template, settings, map[string]string{
						"food_photo_taken":    "true",
						"menu_scanned":        "false",
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
						"food_photo_note":     note,
					})
				}
			}
		}
	}

	rawText, err := h.visionService.AnalyzeFoodFromURLs(c.Request().Context(), signedUrls, systemPrompt)
	if err != nil {
		c.Logger().Errorf("food analyze failed: %v", err)
		return response.InternalError(c, "food analyze failed")
	}
	dishes, summary, actions := parseAIDishes(rawText)
	if h.dishService != nil {
		dishes = h.dishService.HydrateDishMapsPreferFresh(dishes)
	}
	ingredientList, riskAlerts, nutritionHighlights, recommendation := parseAIScanDetails(rawText)
	if len(actions) == 0 {
		actions = []string{"action=record_meal", "action=discover"}
	}

	return response.Success(c, map[string]interface{}{
		"mode":                 "food",
		"summary":              summary,
		"actions":              actions,
		"items":                dishes,
		"ingredient_list":      ingredientList,
		"risk_alerts":          riskAlerts,
		"nutrition_highlights": nutritionHighlights,
		"recommendation":       recommendation,
		"raw":                  strings.TrimSpace(rawText),
	})
}

// ScanIngredients 配料表分析，不直接入库
// POST /api/v1/ingredients/scan
func (h *MealRecordHandler) ScanIngredients(c echo.Context) error {
	userID, ok := c.Get("user_id").(int64)
	if !ok {
		return response.Unauthorized(c, "invalid user context")
	}
	var req struct {
		ImageUrls  []string `json:"image_urls"`
		ClientTime string   `json:"client_time"`
		Note       string   `json:"note"`
	}
	if err := c.Bind(&req); err != nil {
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
	if h.visionService == nil || !h.visionService.IsEnabled() {
		return response.InternalError(c, "vision service is not configured")
	}

	signedUrls := req.ImageUrls
	if h.ossService != nil {
		if signed, err := h.ossService.SignURLs(req.ImageUrls, 15*time.Minute); err == nil {
			signedUrls = signed
		} else {
			c.Logger().Errorf("oss signing failed: %v", err)
			return response.InternalError(c, "oss signing failed")
		}
	}

	systemPrompt := ""
	if h.settingsService != nil {
		if raw, err := h.settingsService.Get(userID); err == nil && len(raw) > 0 {
			var settings map[string]interface{}
			if err := json.Unmarshal(raw, &settings); err == nil {
				recentMealSummary := "暂无"
				if h.service != nil {
					if records, err := h.service.ListByUser(userID, 20); err == nil {
						if summary := service.SummarizeMealRecords(records, 5); strings.TrimSpace(summary) != "" {
							recentMealSummary = summary
						}
					}
				}
				if template, err := service.LoadIngredientScanPromptTemplate(); err == nil {
					isTraining, isCheat := computeDayFlagsForDate(settings, clientTime)
					dayType := dayTypeLabel(isTraining, isCheat)
					timeOfDay := timeOfDayLabel(clientTime)
					intake := buildIntakeContext(h.dailyService, userID, clientTime, settings)
					systemPrompt = service.BuildSystemPrompt(template, settings, map[string]string{
						"food_photo_taken":      "false",
						"menu_scanned":          "false",
						"recent_chat_summary":   "暂无",
						"recent_meal_summary":   recentMealSummary,
						"current_time":          formatPromptTime(clientTime),
						"time_of_day":           timeOfDay,
						"day_type":              dayType,
						"is_training_day":       formatYesNo(isTraining),
						"is_cheat_day":          formatYesNo(isCheat),
						"calories_consumed":     intake.CaloriesConsumed,
						"macro_consumed":        intake.MacroConsumed,
						"calorie_remaining":     intake.CalorieRemaining,
						"ingredient_photo_note": note,
					})
				}
			}
		}
	}

	rawText, err := h.visionService.AnalyzeIngredientFromURLs(c.Request().Context(), signedUrls, systemPrompt)
	if err != nil {
		c.Logger().Errorf("ingredient analyze failed: %v", err)
		return response.InternalError(c, "ingredient analyze failed")
	}
	dishes, summary, actions := parseAIDishes(rawText)
	if h.dishService != nil {
		dishes = h.dishService.HydrateDishMapsPreferFresh(dishes)
	}
	ingredientList, riskAlerts, nutritionHighlights, recommendation := parseAIScanDetails(rawText)
	if len(actions) == 0 {
		actions = []string{"action=record_meal", "action=setting"}
	}

	return response.Success(c, map[string]interface{}{
		"mode":                 "ingredient",
		"summary":              summary,
		"actions":              actions,
		"items":                dishes,
		"ingredient_list":      ingredientList,
		"risk_alerts":          riskAlerts,
		"nutrition_highlights": nutritionHighlights,
		"recommendation":       recommendation,
		"raw":                  strings.TrimSpace(rawText),
	})
}

func (h *MealRecordHandler) enforceMealPhotoQuota(
	c echo.Context,
	userID int64,
	clientTime time.Time,
) error {
	if h.service == nil {
		return nil
	}
	if h.subscriptions != nil {
		if active, err := h.subscriptions.IsUserActive(userID); err == nil && active {
			return nil
		}
	}
	start := startOfDay(clientTime)
	end := start.Add(24 * time.Hour)
	count, err := h.service.CountByUserSourceBetween(userID, "food", start, end)
	if err != nil {
		c.Logger().Errorf("meal photo quota check failed: %v", err)
		return response.InternalError(c, "usage check failed")
	}
	if count >= 1 {
		return response.Error(c, http.StatusTooManyRequests, "今日餐食记录次数已用完，开通订阅可无限使用")
	}
	return nil
}

// List 获取用餐记录
// GET /api/v1/meals?limit=30
func (h *MealRecordHandler) List(c echo.Context) error {
	userID, ok := c.Get("user_id").(int64)
	if !ok {
		return response.Unauthorized(c, "invalid user context")
	}
	limit := 30
	if raw := c.QueryParam("limit"); raw != "" {
		if parsed, err := strconv.Atoi(raw); err == nil {
			if parsed > 0 && parsed <= 100 {
				limit = parsed
			}
		}
	}

	records, err := h.service.ListByUser(userID, limit)
	if err != nil {
		return response.InternalError(c, "failed to load meal records")
	}
	if records == nil {
		records = make([]model.MealRecord, 0)
	}
	return response.Success(c, records)
}

func parseAIDishes(raw string) ([]map[string]interface{}, string, []string) {
	payload := extractJSONPayload(raw)
	if payload == "" {
		return nil, "", nil
	}

	trimmed := strings.TrimSpace(payload)
	if strings.HasPrefix(trimmed, "[") {
		var dishes []map[string]interface{}
		dec := json.NewDecoder(strings.NewReader(trimmed))
		dec.UseNumber()
		if err := dec.Decode(&dishes); err != nil {
			return nil, "", nil
		}
		return normalizeAIDishes(dishes), "", nil
	}

	var decoded struct {
		Summary string                   `json:"summary"`
		Advice  string                   `json:"advice"`
		Dishes  []map[string]interface{} `json:"dishes"`
		Actions []interface{}            `json:"actions"`
	}
	dec := json.NewDecoder(strings.NewReader(trimmed))
	dec.UseNumber()
	if err := dec.Decode(&decoded); err != nil {
		return nil, "", nil
	}
	summary := strings.TrimSpace(decoded.Summary)
	if summary == "" {
		summary = strings.TrimSpace(decoded.Advice)
	}
	actions := toStringSlice(decoded.Actions)
	return normalizeAIDishes(decoded.Dishes), summary, actions
}

func parseAIScanDetails(raw string) ([]string, []string, []map[string]interface{}, string) {
	payload := extractJSONPayload(raw)
	if payload == "" {
		return nil, nil, nil, ""
	}

	trimmed := strings.TrimSpace(payload)
	if !strings.HasPrefix(trimmed, "{") {
		return nil, nil, nil, ""
	}

	var decoded map[string]interface{}
	dec := json.NewDecoder(strings.NewReader(trimmed))
	dec.UseNumber()
	if err := dec.Decode(&decoded); err != nil {
		return nil, nil, nil, ""
	}

	ingredientList := toStringSlice(decoded["ingredient_list"])
	riskAlerts := toStringSlice(decoded["risk_alerts"])
	recommendation := readString(decoded["recommendation"])

	highlights := make([]map[string]interface{}, 0)
	if rawHighlights, ok := decoded["nutrition_highlights"].([]interface{}); ok {
		for _, item := range rawHighlights {
			m, ok := item.(map[string]interface{})
			if !ok {
				continue
			}
			name := strings.TrimSpace(readString(m["name"]))
			value := strings.TrimSpace(readString(m["value"]))
			unit := strings.TrimSpace(readString(m["unit"]))
			if name == "" {
				continue
			}
			highlights = append(highlights, map[string]interface{}{
				"name":  name,
				"value": value,
				"unit":  unit,
			})
		}
	}
	return ingredientList, riskAlerts, highlights, recommendation
}

func normalizeAIDishes(raw []map[string]interface{}) []map[string]interface{} {
	if len(raw) == 0 {
		return nil
	}
	normalized := make([]map[string]interface{}, 0, len(raw))
	now := time.Now().Unix()
	for idx, dish := range raw {
		name := readString(dish["name"])
		if strings.TrimSpace(name) == "" {
			continue
		}
		score := clampInt(readInt(dish["score"], 72), 0, 100)
		recommended := readBool(dish["recommended"], score >= 60)
		scoreLabel := readString(dish["scoreLabel"])
		if scoreLabel == "" {
			scoreLabel = scoreLabelFor(score)
		}
		scoreColor := readString(dish["scoreColor"])
		if scoreColor == "" {
			scoreColor = scoreColorFor(score, recommended)
		}
		normalized = append(normalized, map[string]interface{}{
			"id":          readStringOr(dish["id"], fmt.Sprintf("photo_%d_%d", now, idx)),
			"name":        name,
			"restaurant":  readStringOr(dish["restaurant"], "照片识别"),
			"score":       score,
			"scoreLabel":  scoreLabel,
			"scoreColor":  scoreColor,
			"kcal":        clampInt(readInt(dish["kcal"], 0), 0, 4000),
			"protein":     clampInt(readInt(dish["protein"], 0), 0, 400),
			"carbs":       clampInt(readInt(dish["carbs"], 0), 0, 600),
			"fat":         clampInt(readInt(dish["fat"], 0), 0, 200),
			"tag":         readStringOr(dish["tag"], "识别结果"),
			"recommended": recommended,
			"components":  readStringList(dish["components"], dish["ingredients"]),
			"reason":      readString(dish["reason"]),
		})
	}
	return normalized
}

func extractJSONPayload(raw string) string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return ""
	}
	if strings.HasPrefix(raw, "{") || strings.HasPrefix(raw, "[") {
		return raw
	}
	start := strings.Index(raw, "{")
	end := strings.LastIndex(raw, "}")
	if start >= 0 && end > start {
		return raw[start : end+1]
	}
	start = strings.Index(raw, "[")
	end = strings.LastIndex(raw, "]")
	if start >= 0 && end > start {
		return raw[start : end+1]
	}
	return raw
}

func readString(value interface{}) string {
	switch v := value.(type) {
	case string:
		return v
	case json.Number:
		return v.String()
	case float64:
		return strconv.FormatInt(int64(v), 10)
	case float32:
		return strconv.FormatInt(int64(v), 10)
	case int:
		return strconv.Itoa(v)
	case int64:
		return strconv.FormatInt(v, 10)
	case bool:
		if v {
			return "true"
		}
		return "false"
	}
	return ""
}

func readStringOr(value interface{}, fallback string) string {
	if text := strings.TrimSpace(readString(value)); text != "" {
		return text
	}
	return fallback
}

func readInt(value interface{}, fallback int) int {
	switch v := value.(type) {
	case json.Number:
		if parsed, err := v.Int64(); err == nil {
			return int(parsed)
		}
	case float64:
		return int(v)
	case float32:
		return int(v)
	case int:
		return v
	case int64:
		return int(v)
	case string:
		trimmed := strings.TrimSpace(v)
		if parsed, err := strconv.Atoi(trimmed); err == nil {
			return parsed
		}
		if match := numberRegex.FindString(trimmed); match != "" {
			if parsed, err := strconv.ParseFloat(match, 64); err == nil {
				return int(math.Round(parsed))
			}
		}
	}
	return fallback
}

var numberRegex = regexp.MustCompile(`-?\d+(?:\.\d+)?`)

func readBool(value interface{}, fallback bool) bool {
	switch v := value.(type) {
	case bool:
		return v
	case string:
		if parsed, err := strconv.ParseBool(strings.TrimSpace(v)); err == nil {
			return parsed
		}
	case json.Number:
		if parsed, err := v.Int64(); err == nil {
			return parsed != 0
		}
	case float64:
		return v != 0
	case int:
		return v != 0
	case int64:
		return v != 0
	}
	return fallback
}

func readStringList(primary interface{}, fallback interface{}) []string {
	if list := toStringSlice(primary); len(list) > 0 {
		return list
	}
	return toStringSlice(fallback)
}

func toStringSlice(value interface{}) []string {
	switch v := value.(type) {
	case []string:
		return v
	case []interface{}:
		parts := make([]string, 0, len(v))
		for _, item := range v {
			text := strings.TrimSpace(readString(item))
			if text != "" {
				parts = append(parts, text)
			}
		}
		return parts
	case string:
		raw := strings.TrimSpace(v)
		if raw == "" {
			return nil
		}
		segments := strings.FieldsFunc(raw, func(r rune) bool {
			return r == ',' || r == '，' || r == '、' || r == '/' || r == '|'
		})
		parts := make([]string, 0, len(segments))
		for _, seg := range segments {
			seg = strings.TrimSpace(seg)
			if seg != "" {
				parts = append(parts, seg)
			}
		}
		return parts
	}
	return nil
}

func scoreLabelFor(score int) string {
	switch {
	case score >= 85:
		return "优秀"
	case score >= 70:
		return "良好"
	case score >= 55:
		return "谨慎"
	default:
		return "避免"
	}
}

func scoreColorFor(score int, recommended bool) string {
	switch {
	case score >= 85:
		return "ff13ec5b"
	case score >= 70:
		return "ff37f07a"
	case score >= 55:
		return "ffffd166"
	default:
		if recommended {
			return "ff13ec5b"
		}
		return "fff97316"
	}
}

func clampInt(value int, min int, max int) int {
	if value < min {
		return min
	}
	if value > max {
		return max
	}
	return value
}
