package handler

import (
	"encoding/json"
	"errors"
	"strings"

	"eatclean/internal/model"
	"eatclean/internal/service"
	"eatclean/pkg/response"

	"github.com/labstack/echo/v4"
)

type AuthHandler struct {
	authService     *service.AuthService
	settingsService *service.SettingsService
	subscriptionSvc *service.SubscriptionService
}

func NewAuthHandler(
	authService *service.AuthService,
	settingsService *service.SettingsService,
	subscriptionSvc *service.SubscriptionService,
) *AuthHandler {
	return &AuthHandler{
		authService:     authService,
		settingsService: settingsService,
		subscriptionSvc: subscriptionSvc,
	}
}

// Login 用户登录接口
// POST /api/v1/auth/login
func (h *AuthHandler) Login(c echo.Context) error {
	req := new(model.LoginRequest)
	if err := c.Bind(req); err != nil {
		return response.BadRequest(c, "invalid request body")
	}

	// 验证必填字段
	if req.Platform == "" {
		return response.BadRequest(c, "platform is required")
	}

	if req.Platform != "ios" && req.Platform != "android" && req.Platform != "account" {
		return response.BadRequest(c, "platform must be ios, android, or account")
	}

	if req.Platform == "ios" {
		if req.AppleIdentityToken == nil || *req.AppleIdentityToken == "" {
			return response.BadRequest(c, "apple_identity_token is required for iOS")
		}
		if req.AppleUserID != nil && *req.AppleUserID == "" {
			return response.BadRequest(c, "apple_user_id cannot be empty")
		}
	}

	if req.Platform == "android" && (req.WechatOpenID == nil || *req.WechatOpenID == "") {
		return response.BadRequest(c, "wechat_openid is required for Android")
	}
	if req.Platform == "account" {
		if req.Account == nil || *req.Account == "" {
			return response.BadRequest(c, "account is required")
		}
		if req.Password == nil || *req.Password == "" {
			return response.BadRequest(c, "password is required")
		}
	}

	// 执行登录
	loginResp, err := h.authService.Login(c.Request().Context(), req)
	if err != nil {
		if errors.Is(err, service.ErrInvalidCredentials) {
			return response.BadRequest(c, "invalid credentials")
		}
		if errors.Is(err, service.ErrAppleTokenInvalid) {
			return response.Unauthorized(c, "invalid apple identity token")
		}
		if errors.Is(err, service.ErrAppleKeyFetch) {
			return response.InternalError(c, "apple public key fetch failed")
		}
		if errors.Is(err, service.ErrAppleConfigMissing) {
			return response.InternalError(c, "apple login is not configured")
		}
		return response.InternalError(c, "login failed: "+err.Error())
	}

	if h.settingsService != nil && loginResp != nil && loginResp.User != nil {
		if settings, err := h.settingsService.Get(loginResp.User.ID); err == nil && len(settings) > 0 {
			loginResp.Settings = settings
		}
	}

	if h.subscriptionSvc != nil && loginResp != nil && loginResp.User != nil {
		if active, err := h.subscriptionSvc.IsUserActive(loginResp.User.ID); err == nil {
			loginResp.IsSubscriber = active
		}
	}

	return response.Success(c, loginResp)
}

// Register 用户注册接口
// POST /api/v1/auth/register
func (h *AuthHandler) Register(c echo.Context) error {
	req := new(model.RegisterRequest)
	if err := c.Bind(req); err != nil {
		return response.BadRequest(c, "invalid request body")
	}

	if req.Platform == "" {
		return response.BadRequest(c, "platform is required")
	}
	if req.Platform != "ios" && req.Platform != "android" && req.Platform != "account" {
		return response.BadRequest(c, "platform must be ios, android, or account")
	}
	if req.Platform == "ios" {
		if req.AppleIdentityToken == nil || *req.AppleIdentityToken == "" {
			return response.BadRequest(c, "apple_identity_token is required for iOS")
		}
		if req.AppleUserID != nil && *req.AppleUserID == "" {
			return response.BadRequest(c, "apple_user_id cannot be empty")
		}
	}
	if req.Platform == "android" && (req.WechatOpenID == nil || *req.WechatOpenID == "") {
		return response.BadRequest(c, "wechat_openid is required for Android")
	}
	if req.Platform == "account" {
		if req.Account == nil || *req.Account == "" {
			return response.BadRequest(c, "account is required")
		}
		if req.Password == nil || *req.Password == "" {
			return response.BadRequest(c, "password is required")
		}
	}

	registerResp, err := h.authService.Register(c.Request().Context(), req)
	if err != nil {
		if errors.Is(err, service.ErrUserExists) {
			return response.Error(c, 409, "user already exists")
		}
		if errors.Is(err, service.ErrInvalidCredentials) {
			return response.BadRequest(c, "invalid credentials")
		}
		if errors.Is(err, service.ErrAppleTokenInvalid) {
			return response.Unauthorized(c, "invalid apple identity token")
		}
		if errors.Is(err, service.ErrAppleKeyFetch) {
			return response.InternalError(c, "apple public key fetch failed")
		}
		if errors.Is(err, service.ErrAppleConfigMissing) {
			return response.InternalError(c, "apple login is not configured")
		}
		return response.InternalError(c, "register failed: "+err.Error())
	}

	if h.settingsService != nil && registerResp != nil && registerResp.User != nil {
		if settings, err := h.settingsService.Get(registerResp.User.ID); err == nil && len(settings) > 0 {
			registerResp.Settings = settings
		}
	}

	if h.subscriptionSvc != nil && registerResp != nil && registerResp.User != nil {
		if active, err := h.subscriptionSvc.IsUserActive(registerResp.User.ID); err == nil {
			registerResp.IsSubscriber = active
		}
	}

	return response.Success(c, registerResp)
}

// GetProfile 获取当前用户信息
// GET /api/v1/auth/profile
func (h *AuthHandler) GetProfile(c echo.Context) error {
	userID := c.Get("user_id").(int64)

	// 这里可以扩展获取更详细的用户信息
	return response.Success(c, map[string]interface{}{
		"user_id":    userID,
		"avatar_url": c.Get("avatar_url"),
	})
}

// UpdateNickname 登录后更新用户昵称（写入 user_settings.user_name）
func (h *AuthHandler) UpdateNickname(c echo.Context) error {
	userID, ok := c.Get("user_id").(int64)
	if !ok {
		return response.Unauthorized(c, "invalid user context")
	}
	if h.settingsService == nil {
		return response.InternalError(c, "settings service unavailable")
	}

	var body struct {
		Nickname string `json:"nickname"`
	}
	if err := c.Bind(&body); err != nil {
		return response.BadRequest(c, "invalid request body")
	}
	nickname := strings.TrimSpace(body.Nickname)
	if nickname == "" {
		return response.BadRequest(c, "nickname is required")
	}
	if len([]rune(nickname)) > 24 {
		return response.BadRequest(c, "nickname is too long")
	}

	merged := map[string]interface{}{}
	if raw, err := h.settingsService.Get(userID); err == nil && len(raw) > 0 {
		_ = json.Unmarshal(raw, &merged)
	}
	merged["user_name"] = nickname

	payload, err := json.Marshal(merged)
	if err != nil {
		return response.InternalError(c, "failed to encode settings")
	}
	if err := h.settingsService.Upsert(userID, payload); err != nil {
		return response.InternalError(c, "failed to update nickname")
	}

	return response.Success(c, map[string]interface{}{
		"user_name": nickname,
	})
}

// UpdateAvatar 仅订阅用户可上传自定义头像
func (h *AuthHandler) UpdateAvatar(c echo.Context) error {
	userID, ok := c.Get("user_id").(int64)
	if !ok {
		return response.Unauthorized(c, "invalid user context")
	}
	var body struct {
		URL string `json:"url"`
	}
	if err := c.Bind(&body); err != nil || strings.TrimSpace(body.URL) == "" {
		return response.BadRequest(c, "url is required")
	}
	if !strings.Contains(body.URL, "/avatar/") {
		return response.BadRequest(c, "avatar url must be stored under /avatar/ path")
	}
	if h.subscriptionSvc != nil {
		active, _ := h.subscriptionSvc.IsUserActive(userID)
		if !active {
			return response.Unauthorized(c, "订阅用户可使用自定义头像")
		}
	}
	if err := h.authService.UpdateAvatar(userID, strings.TrimSpace(body.URL)); err != nil {
		return response.InternalError(c, "update avatar failed")
	}
	return response.Success(c, map[string]interface{}{
		"avatar_url": strings.TrimSpace(body.URL),
	})
}
