package service

import (
	"eatclean/internal/model"
	"eatclean/internal/repository"
	"encoding/json"
	"regexp"
	"strconv"
	"strings"
)

type DishService struct {
	repo *repository.DishRepository
}

func NewDishService(repo *repository.DishRepository) *DishService {
	return &DishService{repo: repo}
}

func (s *DishService) IsEnabled() bool {
	return s != nil && s.repo != nil
}

func (s *DishService) FindByNames(names []string) (map[string]model.Dish, error) {
	if !s.IsEnabled() {
		return map[string]model.Dish{}, nil
	}
	normalized := make([]string, 0, len(names))
	seen := map[string]struct{}{}
	for _, name := range names {
		norm := NormalizeDishName(name)
		if norm == "" {
			continue
		}
		if _, ok := seen[norm]; ok {
			continue
		}
		seen[norm] = struct{}{}
		normalized = append(normalized, norm)
	}
	return s.repo.FindByNormalizedNames(normalized)
}

func (s *DishService) UpsertFromMap(dish map[string]interface{}) error {
	if !s.IsEnabled() || dish == nil {
		return nil
	}
	name := readString(dish["name"])
	if strings.TrimSpace(name) == "" {
		return nil
	}
	normalized := NormalizeDishName(name)
	if normalized == "" {
		return nil
	}
	category := readString(dish["category"])
	if category == "" {
		category = readString(dish["tag"])
	}
	var categoryPtr *string
	if strings.TrimSpace(category) != "" {
		categoryPtr = &category
	}
	payload, _ := json.Marshal(dish)
	item := &model.Dish{
		Name:              name,
		NormalizedName:    normalized,
		Category:          categoryPtr,
		NutritionEstimate: payload,
	}
	return s.repo.Upsert(item)
}

func (s *DishService) HydrateDishMaps(dishes []map[string]interface{}) []map[string]interface{} {
	if !s.IsEnabled() || len(dishes) == 0 {
		return dishes
	}
	names := make([]string, 0, len(dishes))
	nameByIndex := make([]string, len(dishes))
	for i, dish := range dishes {
		name := readString(dish["name"])
		nameByIndex[i] = name
		if strings.TrimSpace(name) != "" {
			names = append(names, name)
		}
	}
	cached, err := s.FindByNames(names)
	if err != nil || len(cached) == 0 {
		for _, dish := range dishes {
			_ = s.UpsertFromMap(dish)
		}
		return dishes
	}

	out := make([]map[string]interface{}, 0, len(dishes))
	missing := make([]map[string]interface{}, 0)
	for idx, dish := range dishes {
		name := strings.TrimSpace(nameByIndex[idx])
		if name == "" {
			out = append(out, dish)
			continue
		}
		norm := NormalizeDishName(name)
		if cachedDish, ok := cached[norm]; ok && len(cachedDish.NutritionEstimate) > 0 {
			var cachedMap map[string]interface{}
			if err := json.Unmarshal(cachedDish.NutritionEstimate, &cachedMap); err == nil && len(cachedMap) > 0 {
				merged := make(map[string]interface{}, len(dish)+len(cachedMap))
				for key, value := range dish {
					merged[key] = value
				}
				for key, value := range cachedMap {
					merged[key] = value
				}
				if _, ok := merged["name"]; !ok && name != "" {
					merged["name"] = name
				}
				out = append(out, merged)
				continue
			}
		}
		out = append(out, dish)
		missing = append(missing, dish)
	}

	for _, dish := range missing {
		_ = s.UpsertFromMap(dish)
	}
	return out
}

func (s *DishService) HydrateDishMapsPreferFresh(dishes []map[string]interface{}) []map[string]interface{} {
	if !s.IsEnabled() || len(dishes) == 0 {
		return dishes
	}
	for _, dish := range dishes {
		_ = s.UpsertFromMap(dish)
	}
	return dishes
}

func NormalizeDishName(name string) string {
	name = strings.ToLower(strings.TrimSpace(name))
	if name == "" {
		return ""
	}
	name = dishNameCleaner.ReplaceAllString(name, "")
	return name
}

var dishNameCleaner = regexp.MustCompile(`[\s\p{P}\p{S}]+`)

func readString(value interface{}) string {
	switch v := value.(type) {
	case string:
		return v
	case json.Number:
		return v.String()
	case float64:
		return strconv.FormatFloat(v, 'f', -1, 64)
	case float32:
		return strconv.FormatFloat(float64(v), 'f', -1, 64)
	case int:
		return strconv.Itoa(v)
	case int64:
		return strconv.FormatInt(v, 10)
	case bool:
		if v {
			return "true"
		}
		return "false"
	}
	return ""
}
