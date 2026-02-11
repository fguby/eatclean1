package repository

import (
	"database/sql"
	"eatclean/internal/model"
	"time"
)

type WeeklyMenuRepository struct {
	db *sql.DB
}

func NewWeeklyMenuRepository(db *sql.DB) *WeeklyMenuRepository {
	return &WeeklyMenuRepository{db: db}
}

func (r *WeeklyMenuRepository) EnsureTable() error {
	if r.db == nil {
		return sql.ErrConnDone
	}
	_, err := r.db.Exec(`
		CREATE TABLE IF NOT EXISTS weekly_menu (
			id BIGSERIAL PRIMARY KEY,
			user_id BIGINT REFERENCES app_user(id) ON DELETE CASCADE,
			week_start DATE NOT NULL,
			weekday SMALLINT NOT NULL,
			plan_meals JSONB NOT NULL DEFAULT '[]',
			recommendations JSONB NOT NULL DEFAULT '[]',
			created_at TIMESTAMP DEFAULT NOW(),
			updated_at TIMESTAMP DEFAULT NOW(),
			UNIQUE (user_id, week_start, weekday)
		)
	`)
	if err != nil {
		return err
	}
	_, err = r.db.Exec(`CREATE INDEX IF NOT EXISTS idx_weekly_menu_user_week ON weekly_menu(user_id, week_start)`)
	return err
}

func (r *WeeklyMenuRepository) Get(userID int64, weekStart time.Time, weekday int) (*model.WeeklyMenu, error) {
	if r.db == nil {
		return nil, sql.ErrConnDone
	}
	normalized := normalizeDate(weekStart)
	menu := &model.WeeklyMenu{}
	err := r.db.QueryRow(
		`SELECT id, user_id, week_start, weekday, plan_meals, recommendations, created_at, updated_at
		 FROM weekly_menu WHERE user_id = $1 AND week_start = $2 AND weekday = $3`,
		userID,
		normalized,
		weekday,
	).Scan(
		&menu.ID,
		&menu.UserID,
		&menu.WeekStart,
		&menu.Weekday,
		&menu.PlanMeals,
		&menu.Recommendations,
		&menu.CreatedAt,
		&menu.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return menu, nil
}

func (r *WeeklyMenuRepository) Upsert(userID int64, weekStart time.Time, weekday int, planMeals []byte, recommendations []byte) error {
	if r.db == nil {
		return sql.ErrConnDone
	}
	normalized := normalizeDate(weekStart)
	_, err := r.db.Exec(`
		INSERT INTO weekly_menu (user_id, week_start, weekday, plan_meals, recommendations)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (user_id, week_start, weekday)
		DO UPDATE SET plan_meals = EXCLUDED.plan_meals,
			recommendations = EXCLUDED.recommendations,
			updated_at = NOW()
	`, userID, normalized, weekday, planMeals, recommendations)
	return err
}

func normalizeDate(value time.Time) time.Time {
	year, month, day := value.Date()
	return time.Date(year, month, day, 0, 0, 0, 0, value.Location())
}
