package handler

import (
	"eatclean/internal/service"
	"eatclean/pkg/response"
	"encoding/json"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/labstack/echo/v4"
)

type ChatCompleteHandler struct {
	aiService       *service.ChatAIService
	settingsService *service.SettingsService
	chatService     *service.ChatMessageService
	ossService      *service.OssService
	mealService     *service.MealRecordService
	dailyService    *service.DailyIntakeService
	subscriptions   *service.SubscriptionService
}

func NewChatCompleteHandler(
	aiService *service.ChatAIService,
	settingsService *service.SettingsService,
	chatService *service.ChatMessageService,
	ossService *service.OssService,
	mealService *service.MealRecordService,
	dailyService *service.DailyIntakeService,
	subscriptions *service.SubscriptionService,
) *ChatCompleteHandler {
	return &ChatCompleteHandler{
		aiService:       aiService,
		settingsService: settingsService,
		chatService:     chatService,
		ossService:      ossService,
		mealService:     mealService,
		dailyService:    dailyService,
		subscriptions:   subscriptions,
	}
}

// Complete 生成 AI 回复
// POST /api/v1/chat/complete
func (h *ChatCompleteHandler) Complete(c echo.Context) error {
	userID, ok := c.Get("user_id").(int64)
	if !ok {
		return response.Unauthorized(c, "invalid user context")
	}
	var req struct {
		Text         string   `json:"text"`
		ImageUrls    []string `json:"image_urls"`
		HistoryLimit int      `json:"history_limit"`
		ClientTime   string   `json:"client_time"`
		Mode         string   `json:"mode"` // 可选：menu_scan / food_scan / chat
	}
	if err := c.Bind(&req); err != nil {
		return response.BadRequest(c, "invalid request body")
	}
	if strings.TrimSpace(req.Text) == "" && len(req.ImageUrls) == 0 {
		return response.BadRequest(c, "text or image_urls required")
	}
	if h.aiService == nil || !h.aiService.IsEnabled() {
		return response.InternalError(c, "ai service is not configured")
	}
	clientTime := parseClientTime(req.ClientTime)
	if err := h.enforceChatQuota(c, userID, clientTime); err != nil {
		return err
	}

	recentChatSummary := ""
	if h.chatService != nil {
		if messages, err := h.chatService.ListByUser(userID, 20); err == nil {
			recentChatSummary = service.SummarizeChatMessages(messages, 3)
		}
	}
	recentMealSummary := ""
	if h.mealService != nil {
		if records, err := h.mealService.ListByUser(userID, 20); err == nil {
			recentMealSummary = service.SummarizeMealRecords(records, 3)
		}
	}
	if strings.TrimSpace(recentChatSummary) == "" {
		recentChatSummary = "暂无"
	}
	if strings.TrimSpace(recentMealSummary) == "" {
		recentMealSummary = "暂无"
	}

	systemPrompt := ""
	preUserPrompt := `你将收到用户发送的消息。请结合系统模板中的用户画像、目标、约束以及相关数据，对用户进行详尽的回复。
	注意：如果用户在消息中有明确的要求和建议，那么以用户的为准，如果无法采纳，也请说明原因。
输出要求：
- 这里是聊天场景，请使用自然语言回复，严格使用 Markdown格式，多段落/列表。
- 如需操作引导，可嵌入 action=discover/setting/history/record_meal/xiangji/ai_replace。`
	if h.settingsService != nil {
		if raw, err := h.settingsService.Get(userID); err == nil && len(raw) > 0 {
			var settings map[string]interface{}
			if err := json.Unmarshal(raw, &settings); err == nil {
				var template string
				var err error
				switch strings.ToLower(strings.TrimSpace(req.Mode)) {
				case "menu_scan":
					template, err = service.LoadMenuScanPromptTemplate()
				case "food_scan":
					template, err = service.LoadFoodScanPromptTemplate()
				case "chat":
					template, err = service.LoadChatPromptTemplate()
				default:
					template, err = service.LoadChatPromptTemplate()
				}
				if err == nil && template != "" {
					isTraining, isCheat := computeDayFlagsForDate(settings, clientTime)
					dayType := dayTypeLabel(isTraining, isCheat)
					timeOfDay := timeOfDayLabel(clientTime)
					intake := buildIntakeContext(h.dailyService, userID, clientTime, settings)
					systemPrompt = service.BuildPromptParts(template, settings, map[string]string{
						"menu_scanned":        "false",
						"food_photo_taken":    "false",
						"recent_chat_summary": recentChatSummary,
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

	// historyLimit := req.HistoryLimit
	// if historyLimit <= 0 || historyLimit > 20 {
	// 	historyLimit = 8
	// }
	// var history []model.ChatMessage
	// if h.chatService != nil {
	// 	if messages, err := h.chatService.ListByUser(userID, historyLimit); err == nil {
	// 		// repo returns latest first; reverse for chronological
	// 		for i := len(messages) - 1; i >= 0; i-- {
	// 			history = append(history, messages[i])
	// 		}
	// 	}
	// }
	// log.Printf("chat history: %v", history)
	log.Printf("systemPrompt: %v", systemPrompt)
	if systemPrompt == "" {
		return response.InternalError(c, "system prompt is empty")
	}
	imageUrls := req.ImageUrls
	if h.ossService != nil && len(imageUrls) > 0 {
		if signed, err := h.ossService.SignURLs(imageUrls, 15*time.Minute); err == nil {
			imageUrls = signed
		}
	}

	// TODO:暂时不传history查看效果
	reply, err := h.aiService.Chat(c.Request().Context(), systemPrompt, preUserPrompt, nil, req.Text, imageUrls)
	if err != nil {
		c.Logger().Errorf("chat complete failed: %v", err)
		return response.InternalError(c, "failed to generate reply")
	}

	return response.Success(c, map[string]interface{}{
		"reply": reply,
	})
}

func (h *ChatCompleteHandler) enforceChatQuota(
	c echo.Context,
	userID int64,
	clientTime time.Time,
) error {
	if h.chatService == nil {
		return nil
	}
	if h.subscriptions != nil {
		if active, err := h.subscriptions.IsUserActive(userID); err == nil && active {
			return nil
		}
	}
	start := startOfDay(clientTime)
	end := start.Add(24 * time.Hour)
	count, err := h.chatService.CountByUserRoleBetween(userID, "user", start, end)
	if err != nil {
		c.Logger().Errorf("chat quota check failed: %v", err)
		return response.InternalError(c, "usage check failed")
	}
	if count >= 1 {
		return response.Error(c, http.StatusTooManyRequests, "今日提问次数已用完，开通订阅可无限使用")
	}
	return nil
}
