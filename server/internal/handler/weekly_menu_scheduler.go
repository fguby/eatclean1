package handler

import (
	"context"
	"eatclean/internal/service"
	"log"
	"time"
)

type WeeklyMenuScheduler struct {
	discover      *DiscoverHandler
	subscriptions *service.SubscriptionService
}

func NewWeeklyMenuScheduler(
	discover *DiscoverHandler,
	subscriptions *service.SubscriptionService,
) *WeeklyMenuScheduler {
	return &WeeklyMenuScheduler{
		discover:      discover,
		subscriptions: subscriptions,
	}
}

func (s *WeeklyMenuScheduler) Start(ctx context.Context) {
	if s == nil || s.discover == nil || s.subscriptions == nil {
		return
	}
	go func() {
		for {
			next := nextNightlyRun(time.Now(), 23, 30)
			timer := time.NewTimer(time.Until(next))
			select {
			case <-ctx.Done():
				timer.Stop()
				return
			case <-timer.C:
				s.runOnce(next)
			}
		}
	}()
}

func (s *WeeklyMenuScheduler) runOnce(now time.Time) {
	if s.discover == nil || s.subscriptions == nil || !s.subscriptions.IsEnabled() {
		return
	}
	if s.discover.aiService == nil || !s.discover.aiService.IsEnabled() {
		log.Printf("weekly menu scheduler skipped: ai service not configured")
		return
	}
	if s.discover.weeklyMenu == nil || !s.discover.weeklyMenu.IsEnabled() {
		log.Printf("weekly menu scheduler skipped: weekly menu store unavailable")
		return
	}

	userIDs, err := s.subscriptions.ListActiveUserIDs()
	if err != nil {
		log.Printf("weekly menu scheduler failed to load subscriptions: %v", err)
		return
	}
	if len(userIDs) == 0 {
		return
	}

	startDate := now.AddDate(0, 0, 1)
	for _, userID := range userIDs {
		for i := 0; i < 7; i++ {
			targetDate := startDate.AddDate(0, 0, i)
			weekStart := weekStartForDate(targetDate)
			weekday := weekdayFromDate(targetDate)
			if cached, err := s.discover.weeklyMenu.Get(userID, weekStart, weekday); err == nil && cached != nil {
				continue
			}
			planMeals, recommendations, err := s.discover.generateDiscoverMenus(
				context.Background(),
				userID,
				"weekly",
				weekday,
				targetDate,
				targetDate,
			)
			if err != nil {
				log.Printf("weekly menu generate failed (user %d, day %d): %v", userID, weekday, err)
				continue
			}
			if err := s.discover.weeklyMenu.Upsert(
				userID,
				weekStart,
				weekday,
				planMeals,
				recommendations,
			); err != nil {
				log.Printf("weekly menu upsert failed (user %d): %v", userID, err)
			}
			if s.discover.dishService != nil {
				for _, meal := range append(append([]map[string]interface{}{}, planMeals...), recommendations...) {
					meal["name"] = readStringOr(meal["name"], readString(meal["title"]))
					_ = s.discover.dishService.UpsertFromMap(meal)
				}
			}
		}
	}
}

func nextNightlyRun(now time.Time, hour int, minute int) time.Time {
	if hour < 0 || hour > 23 {
		hour = 23
	}
	if minute < 0 || minute > 59 {
		minute = 0
	}
	target := time.Date(
		now.Year(),
		now.Month(),
		now.Day(),
		hour,
		minute,
		0,
		0,
		now.Location(),
	)
	if !target.After(now) {
		target = target.Add(24 * time.Hour)
	}
	return target
}
