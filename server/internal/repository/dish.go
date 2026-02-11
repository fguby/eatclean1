package repository

import (
	"database/sql"
	"eatclean/internal/model"
	"encoding/json"

	"github.com/lib/pq"
)

type DishRepository struct {
	db *sql.DB
}

func NewDishRepository(db *sql.DB) *DishRepository {
	return &DishRepository{db: db}
}

func (r *DishRepository) EnsureTable() error {
	query := `
		CREATE TABLE IF NOT EXISTS dish (
			id BIGSERIAL PRIMARY KEY,
			name TEXT NOT NULL,
			normalized_name TEXT NOT NULL UNIQUE,
			category VARCHAR(50),
			nutrition_estimate JSONB,
			image_urls TEXT[],
			created_at TIMESTAMP DEFAULT NOW()
		)
	`
	_, err := r.db.Exec(query)
	return err
}

func (r *DishRepository) FindByNormalizedNames(names []string) (map[string]model.Dish, error) {
	result := make(map[string]model.Dish)
	if len(names) == 0 {
		return result, nil
	}
	query := `
		SELECT id, name, normalized_name, category, nutrition_estimate, image_urls, created_at
		FROM dish
		WHERE normalized_name = ANY($1)
	`
	rows, err := r.db.Query(query, pq.Array(names))
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	for rows.Next() {
		var dish model.Dish
		var category sql.NullString
		var nutrition json.RawMessage
		var imageUrls []string
		if err := rows.Scan(
			&dish.ID,
			&dish.Name,
			&dish.NormalizedName,
			&category,
			&nutrition,
			pq.Array(&imageUrls),
			&dish.CreatedAt,
		); err != nil {
			return nil, err
		}
		if category.Valid {
			value := category.String
			dish.Category = &value
		}
		if len(nutrition) > 0 {
			dish.NutritionEstimate = nutrition
		}
		dish.ImageUrls = imageUrls
		result[dish.NormalizedName] = dish
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return result, nil
}

func (r *DishRepository) FindOne(normalized string) (*model.Dish, error) {
	m, err := r.FindByNormalizedNames([]string{normalized})
	if err != nil {
		return nil, err
	}
	if dish, ok := m[normalized]; ok {
		return &dish, nil
	}
	return nil, nil
}

func (r *DishRepository) Upsert(dish *model.Dish) error {
	query := `
		INSERT INTO dish (name, normalized_name, category, nutrition_estimate, image_urls)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (normalized_name) DO UPDATE SET
			name = EXCLUDED.name,
			category = COALESCE(EXCLUDED.category, dish.category),
			nutrition_estimate = COALESCE(EXCLUDED.nutrition_estimate, dish.nutrition_estimate),
			image_urls = COALESCE(EXCLUDED.image_urls, dish.image_urls)
		RETURNING id, created_at
	`
	var category interface{}
	if dish.Category != nil {
		category = *dish.Category
	}
	var nutrition interface{}
	if len(dish.NutritionEstimate) > 0 {
		nutrition = json.RawMessage(dish.NutritionEstimate)
	}
	imageUrls := pq.Array(dish.ImageUrls)
	return r.db.QueryRow(
		query,
		dish.Name,
		dish.NormalizedName,
		category,
		nutrition,
		imageUrls,
	).Scan(&dish.ID, &dish.CreatedAt)
}
