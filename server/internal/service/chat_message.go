package service

import (
	"eatclean/internal/model"
	"eatclean/internal/repository"
	"time"
)

type ChatMessageService struct {
	repo *repository.ChatMessageRepository
}

func NewChatMessageService(repo *repository.ChatMessageRepository) *ChatMessageService {
	return &ChatMessageService{repo: repo}
}

func (s *ChatMessageService) Create(message *model.ChatMessage) error {
	return s.repo.Create(message)
}

func (s *ChatMessageService) ListByUser(userID int64, limit int) ([]model.ChatMessage, error) {
	return s.repo.ListByUser(userID, limit)
}

func (s *ChatMessageService) CountByUserRoleBetween(
	userID int64,
	role string,
	start time.Time,
	end time.Time,
) (int, error) {
	return s.repo.CountByUserRoleBetween(userID, role, start, end)
}
