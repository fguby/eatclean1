package service

import "eatclean/internal/repository"

type SettingsService struct {
	repo *repository.SettingsRepository
}

func NewSettingsService(repo *repository.SettingsRepository) *SettingsService {
	return &SettingsService{repo: repo}
}

func (s *SettingsService) Upsert(userID int64, settingsJSON []byte) error {
	return s.repo.Upsert(userID, settingsJSON)
}

func (s *SettingsService) Get(userID int64) ([]byte, error) {
	return s.repo.Get(userID)
}
