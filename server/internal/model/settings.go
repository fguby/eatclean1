package model

import "encoding/json"

type UserSettings struct {
	UserID    int64           `json:"user_id"`
	Settings  json.RawMessage `json:"settings"`
	UpdatedAt string          `json:"updated_at,omitempty"`
}
