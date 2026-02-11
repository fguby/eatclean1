package handler

import (
	"eatclean/internal/service"
	"eatclean/pkg/response"
	"strings"
	"time"

	"github.com/labstack/echo/v4"
)

type DailyIntakeHandler struct {
	service *service.DailyIntakeService
}

func NewDailyIntakeHandler(service *service.DailyIntakeService) *DailyIntakeHandler {
	return &DailyIntakeHandler{service: service}
}

// UpsertDailyIntake 同步每日能量摄入
// POST /api/v1/intake/daily
func (h *DailyIntakeHandler) UpsertDailyIntake(c echo.Context) error {
	userID, ok := c.Get("user_id").(int64)
	if !ok {
		return response.Unauthorized(c, "invalid user context")
	}
	var req struct {
		Date     string `json:"date"`
		Calories int    `json:"calories"`
		Protein  int    `json:"protein"`
		Carbs    int    `json:"carbs"`
		Fat      int    `json:"fat"`
	}
	if err := c.Bind(&req); err != nil {
		return response.BadRequest(c, "invalid request body")
	}
	date := strings.TrimSpace(req.Date)
	if date == "" {
		date = time.Now().Format("2006-01-02")
	}
	if _, err := time.Parse("2006-01-02", date); err != nil {
		return response.BadRequest(c, "invalid date format")
	}
	if h.service == nil {
		return response.InternalError(c, "daily intake service not configured")
	}
	if err := h.service.Upsert(userID, date, req.Calories, req.Protein, req.Carbs, req.Fat); err != nil {
		if isForeignKeyViolation(err) {
			return response.Unauthorized(c, "user not found, please re-login")
		}
		c.Logger().Errorf("daily intake upsert failed: %v", err)
		return response.InternalError(c, "failed to save daily intake")
	}
	return response.Success(c, map[string]interface{}{
		"user_id":  userID,
		"date":     date,
		"synced":   true,
		"calories": req.Calories,
	})
}
