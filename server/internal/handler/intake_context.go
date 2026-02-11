package handler

import (
	"eatclean/internal/service"
	"fmt"
	"time"
)

type IntakeContext struct {
	CaloriesConsumed string
	MacroConsumed    string
	CalorieRemaining string
}

func buildIntakeContext(
	dailyService *service.DailyIntakeService,
	userID int64,
	clientDate time.Time,
	settings map[string]interface{},
) IntakeContext {
	calories := 0
	protein := 0
	carbs := 0
	fat := 0

	if dailyService != nil {
		if record, err := dailyService.GetByDate(userID, clientDate.Format("2006-01-02")); err == nil && record != nil {
			calories = record.Calories
			protein = record.Protein
			carbs = record.Carbs
			fat = record.Fat
		}
	}

	consumed := fmt.Sprintf("%d", calories)
	macro := fmt.Sprintf("蛋白 %dg / 碳水 %dg / 脂肪 %dg", protein, carbs, fat)

	target := readInt(settings["calorie_target"], 0)
	remaining := "未知"
	if target > 0 {
		value := target - calories
		if value < 0 {
			value = 0
		}
		remaining = fmt.Sprintf("%d", value)
	}

	return IntakeContext{
		CaloriesConsumed: consumed,
		MacroConsumed:    macro,
		CalorieRemaining: remaining,
	}
}
