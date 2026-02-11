package handler

import (
	"strings"
	"time"
)

type DayTimeContext struct {
	ClientTime time.Time
	TimeOfDay  string
	DayType    string
	IsTraining bool
	IsCheat    bool
}

func parseClientTime(raw string) time.Time {
	value := strings.TrimSpace(raw)
	if value == "" {
		return time.Now()
	}
	if parsed, err := time.Parse(time.RFC3339Nano, value); err == nil {
		return parsed
	}
	if parsed, err := time.Parse(time.RFC3339, value); err == nil {
		return parsed
	}
	if parsed, err := time.Parse("2006-01-02 15:04:05", value); err == nil {
		return parsed
	}
	return time.Now()
}

func formatPromptTime(value time.Time) string {
	return value.Format("2006-01-02 15:04:05")
}

func timeOfDayLabel(value time.Time) string {
	hour := value.Hour()
	switch {
	case hour >= 5 && hour < 11:
		return "早上"
	case hour >= 11 && hour < 14:
		return "中午"
	case hour >= 14 && hour < 18:
		return "下午"
	default:
		return "晚上"
	}
}

func dayTypeLabel(isTraining, isCheat bool) string {
	if isTraining {
		return "训练日"
	}
	if isCheat {
		return "放纵日"
	}
	return "正常日"
}

func startOfDay(value time.Time) time.Time {
	year, month, day := value.Date()
	return time.Date(year, month, day, 0, 0, 0, 0, value.Location())
}
