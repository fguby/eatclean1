package handler

import (
	"encoding/json"
	"eatclean/internal/service"
	"eatclean/pkg/response"

	"github.com/labstack/echo/v4"
)

type SettingsHandler struct {
	settingsService *service.SettingsService
}

func NewSettingsHandler(settingsService *service.SettingsService) *SettingsHandler {
	return &SettingsHandler{settingsService: settingsService}
}

// POST /api/v1/user/settings
func (h *SettingsHandler) Upsert(c echo.Context) error {
	userID, ok := c.Get("user_id").(int64)
	if !ok {
		return response.Unauthorized(c, "invalid user context")
	}

	var payload map[string]interface{}
	if err := c.Bind(&payload); err != nil {
		return response.BadRequest(c, "invalid request body")
	}
	if len(payload) == 0 {
		return response.BadRequest(c, "settings payload is empty")
	}

	raw, err := json.Marshal(payload)
	if err != nil {
		return response.BadRequest(c, "settings payload is invalid")
	}

	if err := h.settingsService.Upsert(userID, raw); err != nil {
		if isForeignKeyViolation(err) {
			return response.Unauthorized(c, "user not found, please re-login")
		}
		c.Logger().Errorf("settings upsert failed: %v", err)
		return response.InternalError(c, "failed to save settings")
	}

	return response.Success(c, map[string]interface{}{
		"user_id": userID,
		"saved":   true,
	})
}

// GET /api/v1/user/settings
func (h *SettingsHandler) Get(c echo.Context) error {
	userID, ok := c.Get("user_id").(int64)
	if !ok {
		return response.Unauthorized(c, "invalid user context")
	}
	settings, err := h.settingsService.Get(userID)
	if err != nil {
		c.Logger().Errorf("settings load failed: %v", err)
		return response.InternalError(c, "failed to load settings")
	}
	if settings == nil {
		return response.Success(c, map[string]interface{}{
			"user_id":  userID,
			"settings": map[string]interface{}{},
		})
	}

	var decoded map[string]interface{}
	if err := json.Unmarshal(settings, &decoded); err != nil {
		c.Logger().Errorf("settings decode failed: %v", err)
		return response.InternalError(c, "failed to decode settings")
	}

	return response.Success(c, map[string]interface{}{
		"user_id":  userID,
		"settings": decoded,
	})
}
