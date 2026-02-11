package model

import (
	"encoding/json"
	"time"
)

type MealRecord struct {
	ID         int64           `json:"id" db:"id"`
	UserID     int64           `json:"user_id" db:"user_id"`
	Source     string          `json:"source" db:"source"`
	Items      json.RawMessage `json:"items" db:"items"`
	ImageUrls  json.RawMessage `json:"image_urls,omitempty" db:"image_urls"`
	Ratings    json.RawMessage `json:"ratings,omitempty" db:"ratings"`
	Meta       json.RawMessage `json:"meta,omitempty" db:"meta"`
	RecordedAt time.Time       `json:"recorded_at" db:"recorded_at"`
	CreatedAt  time.Time       `json:"created_at" db:"created_at"`
}

type MealRecordCreateRequest struct {
	Source     string          `json:"source"`
	Items      json.RawMessage `json:"items"`
	ImageUrls  []string        `json:"image_urls,omitempty"`
	Ratings    json.RawMessage `json:"ratings,omitempty"`
	Meta       json.RawMessage `json:"meta,omitempty"`
	RecordedAt *time.Time      `json:"recorded_at,omitempty"`
}
