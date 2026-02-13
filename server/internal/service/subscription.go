package service

import (
	"eatclean/internal/repository"
	"time"
)

type SubscriptionService struct {
	repo *repository.SubscriptionRepository
}

func NewSubscriptionService(repo *repository.SubscriptionRepository) *SubscriptionService {
	return &SubscriptionService{repo: repo}
}

func (s *SubscriptionService) IsEnabled() bool {
	return s != nil && s.repo != nil
}

func (s *SubscriptionService) ListActiveUserIDs() ([]int64, error) {
	if !s.IsEnabled() {
		return nil, nil
	}
	return s.repo.ListActiveUserIDs()
}

func (s *SubscriptionService) Save(
	userID int64,
	platform string,
	sku string,
	status string,
	expireAt *time.Time,
	transactionID string,
	originalTransactionID string,
) error {
	if !s.IsEnabled() {
		return nil
	}
	return s.repo.Upsert(userID, platform, sku, status, expireAt, transactionID, originalTransactionID)
}

func (s *SubscriptionService) IsUserActive(userID int64) (bool, error) {
	if !s.IsEnabled() {
		return false, nil
	}
	return s.repo.IsUserActive(userID)
}

func (s *SubscriptionService) Latest(userID int64) (*repository.SubscriptionRecord, error) {
	if !s.IsEnabled() {
		return nil, nil
	}
	return s.repo.LatestByUser(userID)
}

func (s *SubscriptionService) CountDistinctSubscribers() (int, error) {
	if !s.IsEnabled() {
		return 0, nil
	}
	return s.repo.CountDistinctSubscribers()
}
