package service

import (
	"eatclean/internal/model"
	"encoding/json"
	"fmt"
	"sort"
	"strconv"
	"strings"
	"time"
)

func SummarizeChatMessages(messages []model.ChatMessage, days int) string {
	if len(messages) == 0 || days <= 0 {
		return ""
	}
	cutoff := time.Now().AddDate(0, 0, -days)
	filtered := make([]model.ChatMessage, 0, len(messages))
	for _, msg := range messages {
		if strings.TrimSpace(msg.Text) == "" {
			continue
		}
		if !msg.CreatedAt.IsZero() && msg.CreatedAt.Before(cutoff) {
			continue
		}
		filtered = append(filtered, msg)
	}
	if len(filtered) == 0 {
		return ""
	}
	sort.Slice(filtered, func(i, j int) bool {
		return filtered[i].CreatedAt.Before(filtered[j].CreatedAt)
	})
	if len(filtered) > 12 {
		filtered = filtered[len(filtered)-12:]
	}
	lines := make([]string, 0, len(filtered))
	for _, msg := range filtered {
		role := "用户"
		if msg.Role == "assistant" {
			role = "大胡子"
		}
		lines = append(lines, fmt.Sprintf("%s: %s", role, truncateText(msg.Text, 40)))
	}
	return strings.Join(lines, " | ")
}

func SummarizeMealRecords(records []model.MealRecord, days int) string {
	if len(records) == 0 || days <= 0 {
		return ""
	}
	cutoff := time.Now().AddDate(0, 0, -days)
	filtered := make([]model.MealRecord, 0, len(records))
	for _, rec := range records {
		timestamp := rec.RecordedAt
		if timestamp.IsZero() {
			timestamp = rec.CreatedAt
		}
		if !timestamp.IsZero() && timestamp.Before(cutoff) {
			continue
		}
		filtered = append(filtered, rec)
	}
	if len(filtered) == 0 {
		return ""
	}
	sort.Slice(filtered, func(i, j int) bool {
		return filtered[i].RecordedAt.Before(filtered[j].RecordedAt)
	})
	if len(filtered) > 10 {
		filtered = filtered[len(filtered)-10:]
	}
	lines := make([]string, 0, len(filtered))
	for _, rec := range filtered {
		date := rec.RecordedAt
		if date.IsZero() {
			date = rec.CreatedAt
		}
		dateLabel := date.Format("2006-01-02")
		names, total := summarizeMealItems(rec.Items)
		if len(names) == 0 {
			names = []string{"未命名菜品"}
		}
		if total > 0 {
			lines = append(lines, fmt.Sprintf("%s: %s (约%d kcal)", dateLabel, strings.Join(names, "、"), total))
		} else {
			lines = append(lines, fmt.Sprintf("%s: %s", dateLabel, strings.Join(names, "、")))
		}
	}
	return strings.Join(lines, "\n")
}

func summarizeMealItems(raw json.RawMessage) ([]string, int) {
	if len(raw) == 0 {
		return nil, 0
	}
	var items []map[string]interface{}
	if err := json.Unmarshal(raw, &items); err != nil {
		return nil, 0
	}
	names := make([]string, 0, 4)
	total := 0
	for _, item := range items {
		name := readSummaryString(item["name"])
		if name == "" {
			name = readSummaryString(item["title"])
		}
		if name != "" && len(names) < 4 {
			names = append(names, name)
		}
		total += readSummaryInt(item["kcal"])
	}
	return names, total
}

func truncateText(text string, limit int) string {
	trimmed := strings.TrimSpace(text)
	if limit <= 0 || len([]rune(trimmed)) <= limit {
		return trimmed
	}
	runes := []rune(trimmed)
	return string(runes[:limit]) + "…"
}

func readSummaryString(value interface{}) string {
	switch v := value.(type) {
	case string:
		return strings.TrimSpace(v)
	case json.Number:
		return v.String()
	case float64:
		return strings.TrimSpace(fmt.Sprintf("%.0f", v))
	case float32:
		return strings.TrimSpace(fmt.Sprintf("%.0f", v))
	case int:
		return fmt.Sprintf("%d", v)
	case int64:
		return fmt.Sprintf("%d", v)
	case bool:
		if v {
			return "true"
		}
		return "false"
	}
	return ""
}

func readSummaryInt(value interface{}) int {
	switch v := value.(type) {
	case json.Number:
		if parsed, err := v.Int64(); err == nil {
			return int(parsed)
		}
	case float64:
		return int(v)
	case float32:
		return int(v)
	case int:
		return v
	case int64:
		return int(v)
	case string:
		if parsed, err := strconv.Atoi(strings.TrimSpace(v)); err == nil {
			return parsed
		}
	}
	return 0
}
