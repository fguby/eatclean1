package service

import (
	"eatclean/internal/model"
	"eatclean/internal/repository"
	"time"
)

type MenuScanService struct {
	repo *repository.MenuScanRepository
}

func NewMenuScanService(repo *repository.MenuScanRepository) *MenuScanService {
	return &MenuScanService{repo: repo}
}

func (s *MenuScanService) Create(scan *model.MenuScan) error {
	return s.repo.Create(scan)
}

func (s *MenuScanService) CountByUserBetween(
	userID int64,
	start time.Time,
	end time.Time,
) (int, error) {
	return s.repo.CountByUserBetween(userID, start, end)
}
