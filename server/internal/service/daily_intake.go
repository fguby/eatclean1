package service

import (
	"eatclean/internal/model"
	"eatclean/internal/repository"
)

type DailyIntakeService struct {
	repo *repository.DailyIntakeRepository
}

func NewDailyIntakeService(repo *repository.DailyIntakeRepository) *DailyIntakeService {
	return &DailyIntakeService{repo: repo}
}

func (s *DailyIntakeService) Upsert(userID int64, day string, calories, protein, carbs, fat int) error {
	if s == nil || s.repo == nil {
		return nil
	}
	return s.repo.Upsert(userID, day, calories, protein, carbs, fat)
}

func (s *DailyIntakeService) GetByDate(userID int64, day string) (*model.DailyIntake, error) {
	if s == nil || s.repo == nil {
		return nil, nil
	}
	return s.repo.GetByDate(userID, day)
}
