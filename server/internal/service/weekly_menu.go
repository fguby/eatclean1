package service

import (
	"eatclean/internal/model"
	"eatclean/internal/repository"
	"encoding/json"
	"time"
)

type WeeklyMenuService struct {
	repo *repository.WeeklyMenuRepository
}

func NewWeeklyMenuService(repo *repository.WeeklyMenuRepository) *WeeklyMenuService {
	return &WeeklyMenuService{repo: repo}
}

func (s *WeeklyMenuService) IsEnabled() bool {
	return s != nil && s.repo != nil
}

func (s *WeeklyMenuService) Get(userID int64, weekStart time.Time, weekday int) (*model.WeeklyMenu, error) {
	if !s.IsEnabled() {
		return nil, nil
	}
	return s.repo.Get(userID, weekStart, weekday)
}

func (s *WeeklyMenuService) Upsert(
	userID int64,
	weekStart time.Time,
	weekday int,
	planMeals []map[string]interface{},
	recommendations []map[string]interface{},
) error {
	if !s.IsEnabled() {
		return nil
	}
	planPayload := []byte("[]")
	if len(planMeals) > 0 {
		if encoded, err := json.Marshal(planMeals); err == nil {
			planPayload = encoded
		}
	}
	recPayload := []byte("[]")
	if len(recommendations) > 0 {
		if encoded, err := json.Marshal(recommendations); err == nil {
			recPayload = encoded
		}
	}
	return s.repo.Upsert(userID, weekStart, weekday, planPayload, recPayload)
}
