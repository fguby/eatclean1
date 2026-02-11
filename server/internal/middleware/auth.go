package middleware

import (
	"eatclean/internal/service"
	"eatclean/pkg/response"
	"strings"

	"github.com/labstack/echo/v4"
)

func JWTAuth(authService *service.AuthService) echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			authHeader := c.Request().Header.Get("Authorization")
			if authHeader == "" {
				return response.Unauthorized(c, "missing authorization header")
			}

			// 解析 Bearer token
			parts := strings.SplitN(authHeader, " ", 2)
			if len(parts) != 2 || parts[0] != "Bearer" {
				return response.Unauthorized(c, "invalid authorization header format")
			}

			tokenString := parts[1]
			claims, err := authService.ValidateToken(tokenString)
			if err != nil {
				return response.Unauthorized(c, "invalid or expired token")
			}

			// 将用户信息存入 context
			c.Set("user_id", claims.UserID)
			c.Set("platform", claims.Platform)
			if claims.Avatar != nil {
				c.Set("avatar_url", *claims.Avatar)
			}

			return next(c)
		}
	}
}
