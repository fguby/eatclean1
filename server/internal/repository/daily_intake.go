package repository

import (
	"database/sql"
	"eatclean/internal/model"
)

type DailyIntakeRepository struct {
	db *sql.DB
}

func NewDailyIntakeRepository(db *sql.DB) *DailyIntakeRepository {
	return &DailyIntakeRepository{db: db}
}

func (r *DailyIntakeRepository) EnsureTable() error {
	if r.db == nil {
		return sql.ErrConnDone
	}
	_, err := r.db.Exec(`
		CREATE TABLE IF NOT EXISTS daily_intake (
			user_id    BIGINT REFERENCES app_user(id) ON DELETE CASCADE,
			day        DATE NOT NULL,
			calories   INT NOT NULL DEFAULT 0,
			protein    INT NOT NULL DEFAULT 0,
			carbs      INT NOT NULL DEFAULT 0,
			fat        INT NOT NULL DEFAULT 0,
			updated_at TIMESTAMP DEFAULT NOW(),
			PRIMARY KEY (user_id, day)
		)
	`)
	if err != nil {
		return err
	}
	_, err = r.db.Exec(`CREATE INDEX IF NOT EXISTS idx_daily_intake_user_day ON daily_intake(user_id, day)`)
	return err
}

func (r *DailyIntakeRepository) Upsert(userID int64, day string, calories, protein, carbs, fat int) error {
	query := `
		INSERT INTO daily_intake (user_id, day, calories, protein, carbs, fat)
		VALUES ($1, $2, $3, $4, $5, $6)
		ON CONFLICT (user_id, day)
		DO UPDATE SET calories = EXCLUDED.calories,
			protein = EXCLUDED.protein,
			carbs = EXCLUDED.carbs,
			fat = EXCLUDED.fat,
			updated_at = NOW()
	`
	_, err := r.db.Exec(query, userID, day, calories, protein, carbs, fat)
	return err
}

func (r *DailyIntakeRepository) GetByDate(userID int64, day string) (*model.DailyIntake, error) {
	if r.db == nil {
		return nil, sql.ErrConnDone
	}
	record := &model.DailyIntake{}
	err := r.db.QueryRow(`
		SELECT user_id, day, calories, protein, carbs, fat, updated_at
		FROM daily_intake
		WHERE user_id = $1 AND day = $2
	`, userID, day).Scan(
		&record.UserID,
		&record.Day,
		&record.Calories,
		&record.Protein,
		&record.Carbs,
		&record.Fat,
		&record.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return record, nil
}
