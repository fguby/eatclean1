package model

import (
	"encoding/json"
	"time"
)

type ChatMessage struct {
	ID        int64           `json:"id" db:"id"`
	UserID    int64           `json:"user_id" db:"user_id"`
	Role      string          `json:"role" db:"role"`
	Text      string          `json:"text" db:"text"`
	ImageUrls json.RawMessage `json:"image_urls,omitempty" db:"image_urls"`
	CreatedAt time.Time       `json:"created_at" db:"created_at"`
}

type ChatMessageCreateRequest struct {
	Role      string   `json:"role"`
	Text      string   `json:"text"`
	ImageUrls []string `json:"image_urls"`
}
