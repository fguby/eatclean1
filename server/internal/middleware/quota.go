package middleware

import (
	"fmt"
	"net/http"
	"strings"
	"time"

	"eatclean/internal/service"
	"eatclean/pkg/response"

	"github.com/labstack/echo/v4"
)

// UsageQuotaGuard 按积分校验每日额度，统一返回 429。
// cost 估算：扫描/图片类 8 分，AI 对话 5 分，普通写入 2 分。
func UsageQuotaGuard(
	menuScans *service.MenuScanService,
	mealRecords *service.MealRecordService,
	chatMessages *service.ChatMessageService,
	subscriptions *service.SubscriptionService,
) echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			userID, ok := c.Get("user_id").(int64)
			if !ok {
				return response.Unauthorized(c, "invalid user context")
			}

			path := strings.ToLower(c.Path())
			cost := costForPath(path)
			if cost == 0 {
				return next(c)
			}

			planLimit := dailyLimitForUser(userID, subscriptions)
			if planLimit <= 0 {
				return response.Error(
					c,
					http.StatusTooManyRequests,
					"额度已用完，请订阅后继续使用",
				)
			}

			start := startOfDay(time.Now())
			end := start.Add(24 * time.Hour)

			used := 0
			if menuScans != nil {
				if n, err := menuScans.CountByUserBetween(userID, start, end); err == nil {
					used += n * 8
				}
			}
			if mealRecords != nil {
				if n, err := mealRecords.CountByUserSourceBetween(userID, "food", start, end); err == nil {
					used += n * 3
				}
			}
			if chatMessages != nil {
				if n, err := chatMessages.CountByUserRoleBetween(userID, "user", start, end); err == nil {
					used += n * 5
				}
			}

			if used+cost > planLimit {
				return response.Error(
					c,
					http.StatusTooManyRequests,
					"额度已用完，请订阅后继续使用",
				)
			}

			remaining := planLimit - (used + cost)
			c.Response().Header().Set("X-Quota-Remaining", fmt.Sprintf("%d", remaining))

			return next(c)
		}
	}
}

func costForPath(path string) int {
	switch {
	case strings.Contains(path, "/menu/parse"),
		strings.Contains(path, "/menu/scan"),
		strings.Contains(path, "/meals/photo"),
		strings.Contains(path, "/meals/analyze"),
		strings.Contains(path, "/ingredients/scan"),
		strings.Contains(path, "/discover/recommendations"),
		strings.Contains(path, "/discover/replace"),
		strings.Contains(path, "/discover/weekly/generate"),
		strings.Contains(path, "/oss/sts"),
		strings.Contains(path, "/oss/sign"):
		return 8 // 视觉/大模型图片类
	case strings.Contains(path, "/chat/messages"),
		strings.Contains(path, "/chat/complete"):
		return 5 // 纯对话
	default:
		return 0
	}
}

func dailyLimitForUser(userID int64, subscriptions *service.SubscriptionService) int {
	// 免费：30 分/天 (~30k tokens)
	// 月订阅：600 分/天
	// 年订阅：2000 分/天，鼓励选择年付
	base := 30
	if subscriptions == nil {
		return base
	}
	active, _ := subscriptions.IsUserActive(userID)
	if !active {
		return base
	}
	record, _ := subscriptions.Latest(userID)
	if record == nil {
		return 600
	}
	if strings.Contains(strings.ToLower(record.SKU), "year") {
		return 2000
	}
	return 600
}

func startOfDay(value time.Time) time.Time {
	year, month, day := value.Date()
	return time.Date(year, month, day, 0, 0, 0, 0, value.Location())
}
