package service

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"

	"eatclean/internal/config"
)

type VisionService struct {
	apiKey  string
	baseURL string
	model   string
	client  *http.Client
}

func NewVisionService(cfg *config.QwenConfig) *VisionService {
	if cfg == nil {
		return &VisionService{}
	}
	return &VisionService{
		apiKey:  cfg.APIKey,
		baseURL: strings.TrimRight(cfg.BaseURL, "/"),
		model:   cfg.Model,
		client: &http.Client{
			Timeout: 45 * time.Second,
		},
	}
}

func (s *VisionService) IsEnabled() bool {
	return s.apiKey != "" && s.baseURL != "" && s.model != ""
}

func (s *VisionService) ExtractMenuText(ctx context.Context, images [][]byte) (string, error) {
	if !s.IsEnabled() {
		return "", errors.New("vision service not configured")
	}
	prompt := "请识别菜单图片中的菜品名称，只输出菜名列表，每行一个，不要添加多余说明。"
	return s.callVision(ctx, images, prompt, "")
}

func (s *VisionService) IdentifyFoodItems(ctx context.Context, images [][]byte) (string, error) {
	if !s.IsEnabled() {
		return "", errors.New("vision service not configured")
	}
	prompt := "请识别照片中的食物名称，只输出食物名称列表，每行一个，不要添加多余说明。"
	return s.callVision(ctx, images, prompt, "")
}

func (s *VisionService) ExtractMenuTextFromURLs(ctx context.Context, urls []string) (string, error) {
	if !s.IsEnabled() {
		return "", errors.New("vision service not configured")
	}
	prompt := "请识别菜单图片中的菜品名称，只输出菜名列表，每行一个，不要添加多余说明。"
	return s.callVisionWithURLs(ctx, urls, prompt, "")
}

func (s *VisionService) IdentifyFoodItemsFromURLs(ctx context.Context, urls []string) (string, error) {
	if !s.IsEnabled() {
		return "", errors.New("vision service not configured")
	}
	prompt := "请识别照片中的食物名称，只输出食物名称列表，每行一个，不要添加多余说明。"
	return s.callVisionWithURLs(ctx, urls, prompt, "")
}

func (s *VisionService) AnalyzeMenuFromURLs(ctx context.Context, urls []string, systemPrompt string) (string, error) {
	if !s.IsEnabled() {
		return "", errors.New("vision service not configured")
	}
	prompt := strings.TrimSpace(`
你将收到一到多张菜单照片。请结合系统模板中的用户画像、目标与约束，输出详尽建议，并生成可直接用于“菜单卡片”的数据。
如果系统模板中包含用户对菜单的补充说明，请优先参考。

输出要求：
- 只输出 JSON 对象，不要输出 Markdown 或多余解释。
- 字段格式如下：
{
  "recognized_text": "菜单文本，每行一个菜名",
  "summary": "给用户的详尽建议",
  "dishes": [
    {
      "id": "string",
      "name": "菜品名称",
      "restaurant": "商家/来源，未知可写 菜单识别",
      "score": 0-100,
      "scoreLabel": "优秀/良好/谨慎/避免",
      "scoreColor": "ff13ec5b",
      "kcal": 0,
      "protein": 0,
      "carbs": 0,
      "fat": 0,
      "tag": "推荐/高蛋白/低脂/谨慎等标签",
      "recommended": true,
      "components": ["主要食材1", "主要食材2"],
      "reason": "推荐或注意事项"
    }
  ],
  "actions": ["action=record_meal"]
}

规则：
- kcal/protein/carbs/fat 必须为整数。
- scoreColor 使用 8 位 ARGB 十六进制字符串（不带 #），推荐可用 ff13ec5b，谨慎可用 fffd166。
- 如果菜名不确定请合理估算，但不要留空。
- 已经是菜单扫描场景，不要再建议 action=xiangji；优先建议 action=discover / action=record_meal / action=ai_replace。
`)
	return s.callVisionWithURLs(ctx, urls, prompt, systemPrompt)
}

func (s *VisionService) AnalyzeFoodFromURLs(ctx context.Context, urls []string, systemPrompt string) (string, error) {
	if !s.IsEnabled() {
		return "", errors.New("vision service not configured")
	}
	prompt := strings.TrimSpace(`
你将收到一到多张食物照片。请结合系统模板中的用户画像、目标与约束，输出详尽建议，并生成餐品卡片数据。
如果系统模板中包含用户对食物的补充说明，请优先参考。

输出要求：
- 只输出 JSON 对象，不要输出 Markdown 或多余解释。
- 字段格式如下：
{
  "summary": "给用户的详尽建议",
  "dishes": [
    {
      "id": "string",
      "name": "菜品名称",
      "restaurant": "商家/来源，未知可写 照片识别",
      "score": 0-100,
      "scoreLabel": "优秀/良好/谨慎/避免",
      "scoreColor": "ff13ec5b",
      "kcal": 0,
      "protein": 0,
      "carbs": 0,
      "fat": 0,
      "tag": "识别结果",
      "recommended": true,
      "components": ["主要食材1", "主要食材2"],
      "reason": "推荐或注意事项"
    }
  ],
  "actions": ["action=record_meal"]
}

规则：
- kcal/protein/carbs/fat 必须为整数。
- scoreColor 使用 8 位 ARGB 十六进制字符串（不带 #），推荐可用 ff13ec5b，谨慎可用 fffd166。
- 如果不确定请合理估算，但不要留空。
`)
	return s.callVisionWithURLs(ctx, urls, prompt, systemPrompt)
}

func (s *VisionService) AnalyzeIngredientFromURLs(ctx context.Context, urls []string, systemPrompt string) (string, error) {
	if !s.IsEnabled() {
		return "", errors.New("vision service not configured")
	}
	prompt := strings.TrimSpace(`
你将收到一到多张配料表照片（可能包含营养成分表、配料列表、致敏物提示）。请结合系统模板中的用户画像、目标与限制，输出详尽分析并给出是否推荐食用结论。
如果系统模板中包含用户补充说明，请优先参考。

输出要求：
- 只输出 JSON 对象，不要输出 Markdown 或多余解释。
- 字段格式如下：
{
  "summary": "总体分析与建议",
  "ingredient_list": ["标准化后的主要配料1", "主要配料2"],
  "risk_alerts": ["风险点1", "风险点2"],
  "nutrition_highlights": [
    {"name":"能量", "value":"420", "unit":"kcal/100g"},
    {"name":"蛋白质", "value":"8.2", "unit":"g/100g"},
    {"name":"脂肪", "value":"20", "unit":"g/100g"},
    {"name":"碳水化合物", "value":"52", "unit":"g/100g"},
    {"name":"钠", "value":"650", "unit":"mg/100g"},
    {"name":"糖", "value":"18", "unit":"g/100g"},
    {"name":"膳食纤维", "value":"4.1", "unit":"g/100g"}
  ],
  "recommendation": "建议购买/谨慎食用/不建议",
  "dishes": [
    {
      "id": "string",
      "name": "食品名称（未知可写 包装食品）",
      "restaurant": "配料表识别",
      "score": 0-100,
      "scoreLabel": "优秀/良好/谨慎/避免",
      "scoreColor": "ff13ec5b",
      "kcal": 0,
      "protein": 0,
      "carbs": 0,
      "fat": 0,
      "tag": "配料分析",
      "recommended": true,
      "components": ["主要配料1", "主要配料2"],
      "reason": "给用户的结论"
    }
  ],
  "actions": ["action=record_meal"]
}

规则：
- kcal/protein/carbs/fat 必须为整数；尽量给出每 100g 估算值。
- 严格识别过敏原（如乳制品、坚果、甲壳类、大豆、麸质等）并体现在 risk_alerts。
- 若存在反式脂肪酸、过高钠、高糖浆、代糖争议等，务必指出。
- 输出字段必须完整，不得省略。
`)
	return s.callVisionWithURLs(ctx, urls, prompt, systemPrompt)
}

func (s *VisionService) callVision(ctx context.Context, images [][]byte, prompt string, systemPrompt string) (string, error) {
	if len(images) == 0 {
		return "", errors.New("no images provided")
	}
	content := make([]map[string]interface{}, 0, len(images)+1)
	for _, data := range images {
		if len(data) == 0 {
			continue
		}
		mime := http.DetectContentType(data)
		if !strings.HasPrefix(mime, "image/") {
			mime = "image/jpeg"
		}
		encoded := base64.StdEncoding.EncodeToString(data)
		content = append(content, map[string]interface{}{
			"type": "image_url",
			"image_url": map[string]string{
				"url": fmt.Sprintf("data:%s;base64,%s", mime, encoded),
			},
		})
	}
	content = append(content, map[string]interface{}{
		"type": "text",
		"text": prompt,
	})

	return s.callVisionWithContent(ctx, content, systemPrompt)
}

func (s *VisionService) callVisionWithURLs(ctx context.Context, urls []string, prompt string, systemPrompt string) (string, error) {
	if len(urls) == 0 {
		return "", errors.New("no image urls provided")
	}
	content := make([]map[string]interface{}, 0, len(urls)+1)
	for _, url := range urls {
		if strings.TrimSpace(url) == "" {
			continue
		}
		content = append(content, map[string]interface{}{
			"type": "image_url",
			"image_url": map[string]string{
				"url": url,
			},
		})
	}
	content = append(content, map[string]interface{}{
		"type": "text",
		"text": prompt,
	})
	return s.callVisionWithContent(ctx, content, systemPrompt)
}

func (s *VisionService) callVisionWithContent(ctx context.Context, content []map[string]interface{}, systemPrompt string) (string, error) {
	messages := make([]map[string]interface{}, 0, 2)
	if strings.TrimSpace(systemPrompt) != "" {
		messages = append(messages, map[string]interface{}{
			"role":    "system",
			"content": systemPrompt,
		})
	}
	messages = append(messages, map[string]interface{}{
		"role":    "user",
		"content": content,
	})
	reqBody := map[string]interface{}{
		"model":    s.model,
		"messages": messages,
	}
	payload, err := json.Marshal(reqBody)
	if err != nil {
		return "", err
	}

	req, err := http.NewRequestWithContext(
		ctx,
		http.MethodPost,
		fmt.Sprintf("%s/chat/completions", s.baseURL),
		bytes.NewReader(payload),
	)
	if err != nil {
		return "", err
	}
	req.Header.Set("Authorization", "Bearer "+s.apiKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := s.client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	var decoded struct {
		Choices []struct {
			Message struct {
				Content interface{} `json:"content"`
			} `json:"message"`
		} `json:"choices"`
		Error *struct {
			Message string `json:"message"`
		} `json:"error"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&decoded); err != nil {
		return "", err
	}
	if decoded.Error != nil {
		return "", errors.New(decoded.Error.Message)
	}
	if len(decoded.Choices) == 0 {
		return "", errors.New("empty response")
	}

	contentValue := decoded.Choices[0].Message.Content
	switch value := contentValue.(type) {
	case string:
		return strings.TrimSpace(value), nil
	case []interface{}:
		var parts []string
		for _, item := range value {
			if itemMap, ok := item.(map[string]interface{}); ok {
				if text, ok := itemMap["text"].(string); ok {
					parts = append(parts, text)
				}
			}
		}
		return strings.TrimSpace(strings.Join(parts, "\n")), nil
	default:
		return "", errors.New("unexpected response format")
	}
}
