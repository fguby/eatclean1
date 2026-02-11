package model

import (
	"encoding/json"
	"time"
)

type WeeklyMenu struct {
	ID              int64           `json:"id" db:"id"`
	UserID          int64           `json:"user_id" db:"user_id"`
	WeekStart       time.Time       `json:"week_start" db:"week_start"`
	Weekday         int             `json:"weekday" db:"weekday"`
	PlanMeals       json.RawMessage `json:"plan_meals" db:"plan_meals"`
	Recommendations json.RawMessage `json:"recommendations" db:"recommendations"`
	CreatedAt       time.Time       `json:"created_at" db:"created_at"`
	UpdatedAt       time.Time       `json:"updated_at" db:"updated_at"`
}
