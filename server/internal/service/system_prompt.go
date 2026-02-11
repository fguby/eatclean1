package service

import (
	"bytes"
	"encoding/json"
	"fmt"
	"html/template"
	"math"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/labstack/gommon/log"
)

var (
	systemPromptOnce     sync.Once
	systemPromptTemplate string
	systemPromptErr      error

	menuPromptOnce     sync.Once
	menuPromptTemplate string
	menuPromptErr      error

	foodPromptOnce     sync.Once
	foodPromptTemplate string
	foodPromptErr      error

	discoverPlanOnce     sync.Once
	discoverPlanTemplate string
	discoverPlanErr      error

	discoverReplaceOnce     sync.Once
	discoverReplaceTemplate string
	discoverReplaceErr      error

	chatPromptOnce     sync.Once
	chatPromptTemplate string
	chatPromptErr      error
)

func LoadMenuScanPromptTemplate() (string, error) {
	menuPromptOnce.Do(func() {
		path := strings.TrimSpace(os.Getenv("MENU_PROMPT_PATH"))
		if path == "" {
			path = "prompt/menu_scan.txt"
		}
		data, err := os.ReadFile(path)
		if err != nil {
			menuPromptErr = err
			return
		}
		menuPromptTemplate = string(data)
	})
	return menuPromptTemplate, menuPromptErr
}

func LoadFoodScanPromptTemplate() (string, error) {
	foodPromptOnce.Do(func() {
		path := strings.TrimSpace(os.Getenv("FOOD_PROMPT_PATH"))
		if path == "" {
			path = "prompt/food_scan.txt"
		}
		data, err := os.ReadFile(path)
		if err != nil {
			foodPromptErr = err
			return
		}
		foodPromptTemplate = string(data)
	})
	return foodPromptTemplate, foodPromptErr
}

func LoadDiscoverPlanPromptTemplate() (string, error) {
	discoverPlanOnce.Do(func() {
		path := strings.TrimSpace(os.Getenv("DISCOVER_PLAN_PROMPT_PATH"))
		if path == "" {
			path = "prompt/discover_plan.txt"
		}
		data, err := os.ReadFile(path)
		if err != nil {
			discoverPlanErr = err
			return
		}
		discoverPlanTemplate = string(data)
	})
	return discoverPlanTemplate, discoverPlanErr
}

func LoadDiscoverReplacePromptTemplate() (string, error) {
	discoverReplaceOnce.Do(func() {
		path := strings.TrimSpace(os.Getenv("DISCOVER_REPLACE_PROMPT_PATH"))
		if path == "" {
			path = "prompt/discover_replace.txt"
		}
		data, err := os.ReadFile(path)
		if err != nil {
			discoverReplaceErr = err
			return
		}
		discoverReplaceTemplate = string(data)
	})
	return discoverReplaceTemplate, discoverReplaceErr
}

func LoadChatPromptTemplate() (string, error) {
	chatPromptOnce.Do(func() {
		path := strings.TrimSpace(os.Getenv("CHAT_PROMPT_PATH"))
		if path == "" {
			path = "prompt/chat_prompt.txt"
		}
		data, err := os.ReadFile(path)
		if err != nil {
			chatPromptErr = err
			return
		}
		chatPromptTemplate = string(data)
	})
	return chatPromptTemplate, chatPromptErr
}

func BuildSystemPrompt(template string, settings map[string]interface{}, overrides map[string]string) string {
	return BuildPromptParts(template, settings, overrides)
}

// BuildPromptParts returns system/user parts by splitting template with "#####"
// If no delimiter, systemPart = rendered template, userPart = "".
func BuildPromptParts(myTemplate string, settings map[string]interface{}, overrides map[string]string) string {
	values := make(map[string]string, len(settings)+8)
	for key, value := range settings {
		values[key] = stringifyValue(value)
	}

	if raw, ok := settings["macro_targets"].(map[string]interface{}); ok {
		values["macro_protein"] = stringifyValue(raw["protein"])
		values["macro_carbs"] = stringifyValue(raw["carbs"])
		values["macro_fat"] = stringifyValue(raw["fat"])
	}

	if height, ok := toFloat(settings["height"]); ok && height > 0 {
		if weight, ok := toFloat(settings["weight"]); ok && weight > 0 {
			bmi := weight / math.Pow(height/100, 2)
			values["bmi"] = fmt.Sprintf("%.1f", bmi)
		}
	}

	values["current_time"] = time.Now().Format("2006-01-02 15:04:05")

	if _, ok := values["is_training_day"]; !ok {
		isTraining, isCheat := computeDayFlags(settings)
		values["is_training_day"] = formatYesNo(isTraining)
		values["is_cheat_day"] = formatYesNo(isCheat)
	}

	for key, value := range overrides {
		values[key] = value
	}

	t, err := template.New("prompt").Parse(myTemplate)
	if err != nil {
		log.Errorf("Failed to parse template: %v", err)
		return ""
	}

	var buf bytes.Buffer
	if err := t.Execute(&buf, values); err != nil {
		log.Errorf("Failed to execute template: %v", err)
		return ""
	}
	log.Printf("System Prompt: %s", buf.String())
	return strings.TrimSpace(buf.String())
}

func stringifyValue(value interface{}) string {
	switch v := value.(type) {
	case nil:
		return ""
	case string:
		return v
	case json.Number:
		return v.String()
	case float64:
		if math.Mod(v, 1) == 0 {
			return strconv.FormatInt(int64(v), 10)
		}
		return fmt.Sprintf("%.2f", v)
	case float32:
		if math.Mod(float64(v), 1) == 0 {
			return strconv.FormatInt(int64(v), 10)
		}
		return fmt.Sprintf("%.2f", v)
	case int:
		return strconv.Itoa(v)
	case int64:
		return strconv.FormatInt(v, 10)
	case int32:
		return strconv.FormatInt(int64(v), 10)
	case bool:
		return strconv.FormatBool(v)
	case []string:
		return strings.Join(v, ", ")
	case []interface{}:
		parts := make([]string, 0, len(v))
		for _, item := range v {
			val := stringifyValue(item)
			if strings.TrimSpace(val) != "" {
				parts = append(parts, val)
			}
		}
		return strings.Join(parts, ", ")
	case map[string]interface{}:
		if payload, err := json.Marshal(v); err == nil {
			return string(payload)
		}
	}
	return fmt.Sprintf("%v", value)
}

func toFloat(value interface{}) (float64, bool) {
	switch v := value.(type) {
	case float64:
		return v, true
	case float32:
		return float64(v), true
	case int:
		return float64(v), true
	case int64:
		return float64(v), true
	case json.Number:
		if parsed, err := v.Float64(); err == nil {
			return parsed, true
		}
	case string:
		if parsed, err := strconv.ParseFloat(strings.TrimSpace(v), 64); err == nil {
			return parsed, true
		}
	}
	return 0, false
}

func computeDayFlags(settings map[string]interface{}) (bool, bool) {
	now := time.Now()
	weekday := int(now.Weekday())
	if weekday == 0 {
		weekday = 7
	}
	dayOfMonth := now.Day()

	trainingDays := readIntSlice(settings["monthly_training_days"])
	cheatDays := readIntSlice(settings["monthly_cheat_days"])
	if len(trainingDays) > 0 || len(cheatDays) > 0 {
		isTraining := containsInt(trainingDays, dayOfMonth)
		isCheat := containsInt(cheatDays, dayOfMonth)
		if isCheat {
			isTraining = false
		}
		return isTraining, isCheat
	}

	weeklyTraining := clampInt(readIntValue(settings["weekly_training_days"]), 0, 7)
	cheatFrequency := clampInt(readIntValue(settings["cheat_frequency"]), 0, 7)

	isTraining := weeklyTraining > 0 && weekday <= weeklyTraining
	isCheat := cheatFrequency > 0 && weekday > 7-cheatFrequency
	if isCheat {
		isTraining = false
	}
	return isTraining, isCheat
}

func readIntValue(value interface{}) int {
	if value == nil {
		return 0
	}
	switch v := value.(type) {
	case int:
		return v
	case int64:
		return int(v)
	case float64:
		return int(v)
	case float32:
		return int(v)
	case json.Number:
		if parsed, err := v.Int64(); err == nil {
			return int(parsed)
		}
	case string:
		if parsed, err := strconv.Atoi(strings.TrimSpace(v)); err == nil {
			return parsed
		}
	}
	if f, ok := toFloat(value); ok {
		return int(f)
	}
	return 0
}

func readIntSlice(value interface{}) []int {
	if value == nil {
		return nil
	}
	switch v := value.(type) {
	case []int:
		return append([]int(nil), v...)
	case []interface{}:
		out := make([]int, 0, len(v))
		for _, item := range v {
			if parsed := readIntValue(item); parsed > 0 {
				out = append(out, parsed)
			}
		}
		return out
	}
	return nil
}

func clampInt(value, min, max int) int {
	if value < min {
		return min
	}
	if value > max {
		return max
	}
	return value
}

func containsInt(values []int, target int) bool {
	for _, value := range values {
		if value == target {
			return true
		}
	}
	return false
}

func formatYesNo(value bool) string {
	if value {
		return "是"
	}
	return "否"
}
