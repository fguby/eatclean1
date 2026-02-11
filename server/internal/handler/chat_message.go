package handler

import (
	"eatclean/internal/model"
	"eatclean/internal/service"
	"eatclean/pkg/response"
	"strconv"
	"strings"
	"time"

	"github.com/labstack/echo/v4"
)

type ChatMessageHandler struct {
	service    *service.ChatMessageService
	ossService *service.OssService
}

func NewChatMessageHandler(service *service.ChatMessageService, ossService *service.OssService) *ChatMessageHandler {
	return &ChatMessageHandler{service: service, ossService: ossService}
}

// Create 创建聊天消息
// POST /api/v1/chat/messages
func (h *ChatMessageHandler) Create(c echo.Context) error {
	userID, ok := c.Get("user_id").(int64)
	if !ok {
		return response.Unauthorized(c, "invalid user context")
	}

	req := new(model.ChatMessageCreateRequest)
	if err := c.Bind(req); err != nil {
		return response.BadRequest(c, "invalid request body")
	}
	role := strings.TrimSpace(req.Role)
	if role == "" {
		role = "user"
	}
	text := strings.TrimSpace(req.Text)
	if text == "" && len(req.ImageUrls) == 0 {
		return response.BadRequest(c, "message content is empty")
	}

	message := &model.ChatMessage{
		UserID:    userID,
		Role:      role,
		Text:      text,
		ImageUrls: mustMarshalJSON(req.ImageUrls),
		CreatedAt: time.Now(),
	}
	if err := h.service.Create(message); err != nil {
		return response.InternalError(c, "failed to create chat message")
	}

	var signedUrls []string
	if len(req.ImageUrls) > 0 && h.ossService != nil {
		signed, err := h.ossService.SignURLs(req.ImageUrls, 15*time.Minute)
		if err == nil {
			signedUrls = signed
		}
	}

	return response.Success(c, map[string]interface{}{
		"message":           message,
		"signed_image_urls": signedUrls,
	})
}

// List 获取聊天消息
// GET /api/v1/chat/messages?limit=50
func (h *ChatMessageHandler) List(c echo.Context) error {
	userID, ok := c.Get("user_id").(int64)
	if !ok {
		return response.Unauthorized(c, "invalid user context")
	}
	limit := 50
	if raw := c.QueryParam("limit"); raw != "" {
		if parsed, err := strconv.Atoi(raw); err == nil {
			if parsed > 0 && parsed <= 200 {
				limit = parsed
			}
		}
	}
	messages, err := h.service.ListByUser(userID, limit)
	if err != nil {
		return response.InternalError(c, "failed to load chat messages")
	}
	return response.Success(c, messages)
}
