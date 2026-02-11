package model

import (
	"encoding/json"
	"time"
)

type MenuScan struct {
	ID             int64           `json:"id" db:"id"`
	UserID         int64           `json:"user_id" db:"user_id"`
	RawImageURL    *string         `json:"raw_image_url,omitempty" db:"raw_image_url"`
	RawImageURLs   json.RawMessage `json:"raw_image_urls,omitempty" db:"raw_image_urls"`
	OCRText        string          `json:"ocr_text" db:"ocr_text"`
	ParsedMenu     json.RawMessage `json:"parsed_menu" db:"parsed_menu"`
	RestaurantHint *string         `json:"restaurant_hint,omitempty" db:"restaurant_hint"`
	CreatedAt      time.Time       `json:"created_at" db:"created_at"`
}
