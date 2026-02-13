package handler

import (
	"eatclean/internal/config"
	"eatclean/internal/service"
	"eatclean/pkg/response"
	"strings"
	"time"

	"github.com/labstack/echo/v4"
)

type OssHandler struct {
	service *service.OssService
	cfg     *config.OSSConfig
}

func NewOssHandler(service *service.OssService, cfg *config.OSSConfig) *OssHandler {
	return &OssHandler{service: service, cfg: cfg}
}

// GetSTS 获取 OSS 临时凭证
// GET /api/v1/oss/sts
func (h *OssHandler) GetSTS(c echo.Context) error {
	userID, ok := c.Get("user_id").(int64)
	if !ok {
		return response.Unauthorized(c, "invalid user context")
	}
	c.Logger().Infof("oss sts request received: user_id=%d path=%s", userID, c.Path())
	if h.service == nil || h.cfg == nil {
		return response.InternalError(c, "oss service not configured")
	}
	if h.cfg.Endpoint == "" || h.cfg.Bucket == "" {
		return response.InternalError(c, "oss endpoint or bucket missing")
	}
	if h.cfg.AccessKeyID == "" || h.cfg.AccessKeySecret == "" || h.cfg.RoleArn == "" {
		return response.InternalError(c, "oss credentials missing")
	}
	token, err := h.service.GetStsToken()
	if err != nil {
		c.Logger().Errorf("oss sts error: %v", err)
		return response.InternalError(c, "failed to get oss sts token")
	}
	if token.AccessKeyID == "" || token.AccessKeySecret == "" || token.SecurityToken == "" {
		c.Logger().Errorf("oss sts invalid token: access_key_id_len=%d access_key_secret_len=%d security_token_len=%d",
			len(token.AccessKeyID), len(token.AccessKeySecret), len(token.SecurityToken))
		return response.InternalError(c, "invalid oss sts token")
	}
	akPrefix := token.AccessKeyID
	if len(akPrefix) > 12 {
		akPrefix = akPrefix[:12]
	}
	c.Logger().Infof("oss sts issued: ak_prefix=%s***, ak_len=%d, endpoint=%s, bucket=%s",
		akPrefix, len(token.AccessKeyID), h.cfg.Endpoint, h.cfg.Bucket)

	endpoint := strings.TrimSpace(h.cfg.Endpoint)
	endpoint = strings.TrimPrefix(endpoint, "https://")
	endpoint = strings.TrimPrefix(endpoint, "http://")

	return response.Success(c, map[string]interface{}{
		"access_key_id":     token.AccessKeyID,
		"access_key_secret": token.AccessKeySecret,
		"security_token":    token.SecurityToken,
		"expiration":        token.Expiration,
		"endpoint":          endpoint,
		"bucket":            h.cfg.Bucket,
		"region":            h.cfg.Region,
	})
}

// SignURLs 为图片生成签名 URL
// POST /api/v1/oss/sign
func (h *OssHandler) SignURLs(c echo.Context) error {
	_, ok := c.Get("user_id").(int64)
	if !ok {
		return response.Unauthorized(c, "invalid user context")
	}
	if h.service == nil {
		return response.InternalError(c, "oss service not configured")
	}
	var req struct {
		Urls       []string `json:"urls"`
		TTLSeconds int      `json:"ttl_seconds"`
	}
	if err := c.Bind(&req); err != nil {
		return response.BadRequest(c, "invalid request body")
	}
	if len(req.Urls) == 0 {
		return response.BadRequest(c, "urls are required")
	}
	ttl := time.Duration(req.TTLSeconds) * time.Second
	if ttl <= 0 {
		ttl = 15 * time.Minute
	}
	signed, err := h.service.SignURLs(req.Urls, ttl)
	if err != nil {
		c.Logger().Errorf("oss sign url error: %v", err)
		return response.InternalError(c, "failed to sign urls")
	}
	return response.Success(c, map[string]interface{}{
		"signed_urls": signed,
	})
}
