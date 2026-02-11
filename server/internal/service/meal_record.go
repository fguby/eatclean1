package service

import (
	"eatclean/internal/model"
	"eatclean/internal/repository"
	"time"
)

type MealRecordService struct {
	repo *repository.MealRecordRepository
}

func NewMealRecordService(repo *repository.MealRecordRepository) *MealRecordService {
	return &MealRecordService{repo: repo}
}

func (s *MealRecordService) Create(record *model.MealRecord) error {
	return s.repo.Create(record)
}

func (s *MealRecordService) ListByUser(userID int64, limit int) ([]model.MealRecord, error) {
	return s.repo.ListByUser(userID, limit)
}

func (s *MealRecordService) CountByUserSourceBetween(
	userID int64,
	source string,
	start time.Time,
	end time.Time,
) (int, error) {
	return s.repo.CountByUserSourceBetween(userID, source, start, end)
}
