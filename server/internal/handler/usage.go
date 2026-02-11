package handler

import (
	"eatclean/internal/service"
	"eatclean/pkg/response"
	"net/http"
	"strings"
	"time"

	"github.com/labstack/echo/v4"
)

type UsageHandler struct {
	menuScans     *service.MenuScanService
	mealRecords   *service.MealRecordService
	chatMessages  *service.ChatMessageService
	subscriptions *service.SubscriptionService
}

func NewUsageHandler(
	menuScans *service.MenuScanService,
	mealRecords *service.MealRecordService,
	chatMessages *service.ChatMessageService,
	subscriptions *service.SubscriptionService,
) *UsageHandler {
	return &UsageHandler{
		menuScans:     menuScans,
		mealRecords:   mealRecords,
		chatMessages:  chatMessages,
		subscriptions: subscriptions,
	}
}

type usageCheckRequest struct {
	Type       string `json:"type"`
	ClientTime string `json:"client_time"`
}

func (h *UsageHandler) Check(c echo.Context) error {
	userID, ok := c.Get("user_id").(int64)
	if !ok {
		return response.Unauthorized(c, "invalid user context")
	}
	var req usageCheckRequest
	_ = c.Bind(&req)
	clientTime := parseClientTime(req.ClientTime)
	usageType := strings.TrimSpace(strings.ToLower(req.Type))
	if usageType == "" {
		usageType = "all"
	}

	isSubscriber := false
	if h.subscriptions != nil {
		if active, err := h.subscriptions.IsUserActive(userID); err == nil && active {
			isSubscriber = true
		}
	}

	start := startOfDay(clientTime)
	end := start.Add(24 * time.Hour)

	buildSummary := func(used int) map[string]interface{} {
		limit := 1
		remaining := limit - used
		if remaining < 0 {
			remaining = 0
		}
		return map[string]interface{}{
			"used":      used,
			"limit":     limit,
			"remaining": remaining,
			"unlimited": isSubscriber,
		}
	}

	if isSubscriber {
		// still return used numbers for analytics, but mark unlimited for UI.
	}

	switch usageType {
	case "menu_scan":
		if h.menuScans == nil {
			return response.InternalError(c, "menu scan service unavailable")
		}
		used, err := h.menuScans.CountByUserBetween(userID, start, end)
		if err != nil {
			c.Logger().Errorf("usage check menu scan failed: %v", err)
			return response.InternalError(c, "usage check failed")
		}
		return response.Success(c, map[string]interface{}{
			"type":          usageType,
			"is_subscriber": isSubscriber,
			"usage":         buildSummary(used),
		})
	case "meal_record":
		if h.mealRecords == nil {
			return response.InternalError(c, "meal record service unavailable")
		}
		used, err := h.mealRecords.CountByUserSourceBetween(
			userID,
			"food",
			start,
			end,
		)
		if err != nil {
			c.Logger().Errorf("usage check meal record failed: %v", err)
			return response.InternalError(c, "usage check failed")
		}
		return response.Success(c, map[string]interface{}{
			"type":          usageType,
			"is_subscriber": isSubscriber,
			"usage":         buildSummary(used),
		})
	case "question":
		if h.chatMessages == nil {
			return response.InternalError(c, "chat service unavailable")
		}
		used, err := h.chatMessages.CountByUserRoleBetween(
			userID,
			"user",
			start,
			end,
		)
		if err != nil {
			c.Logger().Errorf("usage check question failed: %v", err)
			return response.InternalError(c, "usage check failed")
		}
		return response.Success(c, map[string]interface{}{
			"type":          usageType,
			"is_subscriber": isSubscriber,
			"usage":         buildSummary(used),
		})
	case "all":
		if h.menuScans == nil || h.mealRecords == nil || h.chatMessages == nil {
			return response.InternalError(c, "usage service unavailable")
		}
		menuUsed, err := h.menuScans.CountByUserBetween(userID, start, end)
		if err != nil {
			c.Logger().Errorf("usage check menu scan failed: %v", err)
			return response.InternalError(c, "usage check failed")
		}
		mealUsed, err := h.mealRecords.CountByUserSourceBetween(
			userID,
			"food",
			start,
			end,
		)
		if err != nil {
			c.Logger().Errorf("usage check meal record failed: %v", err)
			return response.InternalError(c, "usage check failed")
		}
		questionUsed, err := h.chatMessages.CountByUserRoleBetween(
			userID,
			"user",
			start,
			end,
		)
		if err != nil {
			c.Logger().Errorf("usage check question failed: %v", err)
			return response.InternalError(c, "usage check failed")
		}
		return response.Success(c, map[string]interface{}{
			"is_subscriber": isSubscriber,
			"usage": map[string]interface{}{
				"menu_scan":   buildSummary(menuUsed),
				"meal_record": buildSummary(mealUsed),
				"question":    buildSummary(questionUsed),
			},
		})
	default:
		return response.Error(c, http.StatusBadRequest, "invalid type")
	}
}
