package repository

import (
	"database/sql"
	"eatclean/internal/model"
	"time"
)

type MealRecordRepository struct {
	db *sql.DB
}

func NewMealRecordRepository(db *sql.DB) *MealRecordRepository {
	return &MealRecordRepository{db: db}
}

func (r *MealRecordRepository) Create(record *model.MealRecord) error {
	query := `
		INSERT INTO meal_record (user_id, source, items, image_urls, ratings, meta, recorded_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING id, created_at
	`
	itemsJSON := normalizeJSON(record.Items, "[]")
	imageUrlsJSON := normalizeJSON(record.ImageUrls, "[]")
	ratingsJSON := normalizeJSON(record.Ratings, "null")
	metaJSON := normalizeJSON(record.Meta, "null")
	return r.db.QueryRow(
		query,
		record.UserID,
		record.Source,
		itemsJSON,
		imageUrlsJSON,
		ratingsJSON,
		metaJSON,
		record.RecordedAt,
	).Scan(&record.ID, &record.CreatedAt)
}

func (r *MealRecordRepository) ListByUser(userID int64, limit int) ([]model.MealRecord, error) {
	query := `
		SELECT id, user_id, source, items, image_urls, ratings, meta, recorded_at, created_at
		FROM meal_record
		WHERE user_id = $1
		ORDER BY recorded_at DESC, id DESC
		LIMIT $2
	`
	rows, err := r.db.Query(query, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var records []model.MealRecord
	for rows.Next() {
		var record model.MealRecord
		if err := rows.Scan(
			&record.ID,
			&record.UserID,
			&record.Source,
			&record.Items,
			&record.ImageUrls,
			&record.Ratings,
			&record.Meta,
			&record.RecordedAt,
			&record.CreatedAt,
		); err != nil {
			return nil, err
		}
		records = append(records, record)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return records, nil
}

func (r *MealRecordRepository) CountByUserSourceBetween(
	userID int64,
	source string,
	start time.Time,
	end time.Time,
) (int, error) {
	var count int
	query := `
		SELECT COUNT(1)
		FROM meal_record
		WHERE user_id = $1
		  AND source = $2
		  AND recorded_at >= $3
		  AND recorded_at < $4
	`
	err := r.db.QueryRow(query, userID, source, start, end).Scan(&count)
	return count, err
}
