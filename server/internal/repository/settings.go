package repository

import (
	"database/sql"
)

type SettingsRepository struct {
	db *sql.DB
}

func NewSettingsRepository(db *sql.DB) *SettingsRepository {
	return &SettingsRepository{db: db}
}

func (r *SettingsRepository) EnsureTable() error {
	if r.db == nil {
		return sql.ErrConnDone
	}
	_, err := r.db.Exec(`
		CREATE TABLE IF NOT EXISTS user_settings (
			user_id     BIGINT PRIMARY KEY REFERENCES app_user(id) ON DELETE CASCADE,
			settings    JSONB NOT NULL,
			updated_at  TIMESTAMP DEFAULT NOW()
		)
	`)
	if err != nil {
		return err
	}
	_, err = r.db.Exec(`CREATE INDEX IF NOT EXISTS idx_user_settings_json ON user_settings USING GIN(settings)`)
	return err
}

func (r *SettingsRepository) Upsert(userID int64, settingsJSON []byte) error {
	query := `
		INSERT INTO user_settings (user_id, settings)
		VALUES ($1, $2)
		ON CONFLICT (user_id)
		DO UPDATE SET settings = EXCLUDED.settings, updated_at = NOW()
	`
	_, err := r.db.Exec(query, userID, settingsJSON)
	return err
}

func (r *SettingsRepository) Get(userID int64) ([]byte, error) {
	query := `SELECT settings FROM user_settings WHERE user_id = $1`
	var settings []byte
	err := r.db.QueryRow(query, userID).Scan(&settings)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return settings, nil
}
