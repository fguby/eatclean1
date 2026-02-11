package handler

import (
	"context"
	"encoding/json"
	"errors"
	"strconv"
	"strings"

	"eatclean/internal/model"
	"eatclean/internal/repository"
	"eatclean/internal/service"
	"eatclean/pkg/response"

	"github.com/labstack/echo/v4"
)

type FoodHandler struct {
	dishes *repository.DishRepository
	ai     *service.ChatAIService
}

func NewFoodHandler(dishes *repository.DishRepository, ai *service.ChatAIService) *FoodHandler {
	return &FoodHandler{dishes: dishes, ai: ai}
}

type foodSearchRequest struct {
	Query string `json:"query"`
}

type foodSearchResult struct {
	Name     string  `json:"name"`
	Calories float64 `json:"calories_kcal_per100g"`
	Protein  float64 `json:"protein_g_per100g"`
	Fat      float64 `json:"fat_g_per100g"`
	Carbs    float64 `json:"carbs_g_per100g"`
	Advice   string  `json:"advice"`
}

func (h *FoodHandler) Search(c echo.Context) error {
	userID, ok := c.Get("user_id").(int64)
	if !ok || userID == 0 {
		return response.Unauthorized(c, "invalid user context")
	}
	var req foodSearchRequest
	if err := c.Bind(&req); err != nil || strings.TrimSpace(req.Query) == "" {
		return response.BadRequest(c, "query is required")
	}
	raw := strings.TrimSpace(req.Query)
	norm := normalizeFoodName(raw)

	// 1) 缓存命中直接返回
	if h.dishes != nil {
		if cached, err := h.dishes.FindOne(norm); err == nil && cached != nil {
			return response.Success(c, toFoodResult(*cached))
		}
	}

	if h.ai == nil || !h.ai.IsEnabled() {
		return response.InternalError(c, "ai service not available")
	}

	// 2) 调用模型
	info, err := h.generateFoodInfo(c.Request().Context(), raw)
	if err != nil {
		c.Logger().Errorf("food search ai failed: %v", err)
		return response.InternalError(c, "获取食物信息失败，请稍后再试")
	}

	// 3) 存入缓存
	if h.dishes != nil {
		_ = h.dishes.Upsert(&model.Dish{
			Name:           info.Name,
			NormalizedName: norm,
			NutritionEstimate: mustJSON(map[string]interface{}{
				"calories_kcal_per100g": info.Calories,
				"protein_g_per100g":     info.Protein,
				"fat_g_per100g":         info.Fat,
				"carbs_g_per100g":       info.Carbs,
				"advice":                info.Advice,
			}),
		})
	}

	return response.Success(c, info)
}

func toFoodResult(d model.Dish) *foodSearchResult {
	var parsed map[string]interface{}
	calories := 0.0
	protein := 0.0
	fat := 0.0
	carbs := 0.0
	advice := ""
	if len(d.NutritionEstimate) > 0 {
		_ = json.Unmarshal(d.NutritionEstimate, &parsed)
		if parsed != nil {
			calories = toFloat(parsed["calories_kcal_per100g"])
			protein = toFloat(parsed["protein_g_per100g"])
			fat = toFloat(parsed["fat_g_per100g"])
			carbs = toFloat(parsed["carbs_g_per100g"])
			if v, ok := parsed["advice"].(string); ok {
				advice = v
			}
		}
	}
	return &foodSearchResult{
		Name:     d.Name,
		Calories: calories,
		Protein:  protein,
		Fat:      fat,
		Carbs:    carbs,
		Advice:   advice,
	}
}

func toFloat(v interface{}) float64 {
	switch val := v.(type) {
	case float64:
		return val
	case float32:
		return float64(val)
	case int:
		return float64(val)
	case int64:
		return float64(val)
	case string:
		f, _ := strconv.ParseFloat(val, 64)
		return f
	default:
		return 0
	}
}

func (h *FoodHandler) generateFoodInfo(ctx context.Context, name string) (*foodSearchResult, error) {
	prompt := `
你是一名专业的营养师，请分析该食物并输出 JSON（不含多余文字），字段：
name: 食物名称
calories_kcal_per100g: 每100g热量(数字)
protein_g_per100g: 每100g蛋白质(数字)
fat_g_per100g: 每100g脂肪(数字)
carbs_g_per100g: 每100g碳水(数字)
other: 其他营养成分(数字)
desc: 食物的详细介绍，包括不限于种类、来源地等
advice: 1-2 句饮食建议
`
	reply, err := h.ai.Chat(
		ctx,
		prompt,
		"",
		nil,
		"食物："+name,
		nil,
	)
	if err != nil {
		return nil, err
	}
	var parsed foodSearchResult
	if err := json.Unmarshal([]byte(reply), &parsed); err != nil {
		return nil, err
	}
	parsed.Name = strings.TrimSpace(firstNonEmpty(parsed.Name, name))
	if parsed.Name == "" {
		return nil, errors.New("empty name from ai")
	}
	return &parsed, nil
}

func normalizeFoodName(name string) string {
	return strings.ToLower(strings.TrimSpace(name))
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if strings.TrimSpace(v) != "" {
			return v
		}
	}
	return ""
}

func mustJSON(v interface{}) []byte {
	data, _ := json.Marshal(v)
	return data
}
