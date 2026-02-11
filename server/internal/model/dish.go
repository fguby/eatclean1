package model

import (
	"encoding/json"
	"time"
)

type Dish struct {
	ID                int64           `json:"id"`
	Name              string          `json:"name"`
	NormalizedName    string          `json:"normalized_name"`
	Category          *string         `json:"category,omitempty"`
	NutritionEstimate json.RawMessage `json:"nutrition_estimate,omitempty"`
	ImageUrls         []string        `json:"image_urls,omitempty"`
	CreatedAt         time.Time       `json:"created_at"`
}
