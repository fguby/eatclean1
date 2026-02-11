package repository

import (
	"database/sql"
	"eatclean/internal/model"
	"time"
)

type MenuScanRepository struct {
	db *sql.DB
}

func NewMenuScanRepository(db *sql.DB) *MenuScanRepository {
	return &MenuScanRepository{db: db}
}

func (r *MenuScanRepository) Create(scan *model.MenuScan) error {
	query := `
		INSERT INTO menu_scan (user_id, raw_image_url, raw_image_urls, ocr_text, parsed_menu, restaurant_hint)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id, created_at
	`
	rawImageURLs := normalizeJSON(scan.RawImageURLs, "[]")
	parsedMenu := normalizeJSON(scan.ParsedMenu, "{}")
	return r.db.QueryRow(
		query,
		scan.UserID,
		scan.RawImageURL,
		rawImageURLs,
		scan.OCRText,
		parsedMenu,
		scan.RestaurantHint,
	).Scan(&scan.ID, &scan.CreatedAt)
}

func (r *MenuScanRepository) CountByUserBetween(
	userID int64,
	start time.Time,
	end time.Time,
) (int, error) {
	var count int
	query := `
		SELECT COUNT(1)
		FROM menu_scan
		WHERE user_id = $1
		  AND created_at >= $2
		  AND created_at < $3
	`
	err := r.db.QueryRow(query, userID, start, end).Scan(&count)
	return count, err
}
