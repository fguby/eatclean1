package repository

import (
	"database/sql"
	"eatclean/internal/model"
	"time"
)

type ChatMessageRepository struct {
	db *sql.DB
}

func NewChatMessageRepository(db *sql.DB) *ChatMessageRepository {
	return &ChatMessageRepository{db: db}
}

func (r *ChatMessageRepository) Create(message *model.ChatMessage) error {
	query := `
		INSERT INTO chat_message (user_id, role, text, image_urls)
		VALUES ($1, $2, $3, $4)
		RETURNING id, created_at
	`
	imageUrls := normalizeJSON(message.ImageUrls, "[]")
	return r.db.QueryRow(
		query,
		message.UserID,
		message.Role,
		message.Text,
		imageUrls,
	).Scan(&message.ID, &message.CreatedAt)
}

func (r *ChatMessageRepository) ListByUser(userID int64, limit int) ([]model.ChatMessage, error) {
	query := `
		SELECT id, user_id, role, text, image_urls, created_at
		FROM chat_message
		WHERE user_id = $1
		ORDER BY id DESC
		LIMIT $2
	`
	rows, err := r.db.Query(query, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var messages []model.ChatMessage
	for rows.Next() {
		var msg model.ChatMessage
		if err := rows.Scan(
			&msg.ID,
			&msg.UserID,
			&msg.Role,
			&msg.Text,
			&msg.ImageUrls,
			&msg.CreatedAt,
		); err != nil {
			return nil, err
		}
		messages = append(messages, msg)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return messages, nil
}

func (r *ChatMessageRepository) CountByUserRoleBetween(
	userID int64,
	role string,
	start time.Time,
	end time.Time,
) (int, error) {
	var count int
	query := `
		SELECT COUNT(1)
		FROM chat_message
		WHERE user_id = $1
		  AND role = $2
		  AND created_at >= $3
		  AND created_at < $4
	`
	err := r.db.QueryRow(query, userID, role, start, end).Scan(&count)
	return count, err
}
