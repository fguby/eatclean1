package model

import "time"

type DailyIntake struct {
	UserID    int64     `json:"user_id" db:"user_id"`
	Day       time.Time `json:"day" db:"day"`
	Calories  int       `json:"calories" db:"calories"`
	Protein   int       `json:"protein" db:"protein"`
	Carbs     int       `json:"carbs" db:"carbs"`
	Fat       int       `json:"fat" db:"fat"`
	UpdatedAt time.Time `json:"updated_at" db:"updated_at"`
}
