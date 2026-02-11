package service

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"

	"eatclean/internal/config"
	"eatclean/internal/model"
)

type ChatAIService struct {
	apiKey  string
	baseURL string
	model   string
	client  *http.Client
}

func NewChatAIService(cfg *config.QwenConfig) *ChatAIService {
	if cfg == nil {
		return &ChatAIService{}
	}
	return &ChatAIService{
		apiKey:  cfg.APIKey,
		baseURL: strings.TrimRight(cfg.BaseURL, "/"),
		model:   cfg.Model,
		client: &http.Client{
			Timeout: 45 * time.Second,
		},
	}
}

func (s *ChatAIService) IsEnabled() bool {
	return s.apiKey != "" && s.baseURL != "" && s.model != ""
}

func (s *ChatAIService) Chat(ctx context.Context, systemPrompt string, preUser string, history []model.ChatMessage, userText string, imageUrls []string) (string, error) {
	if !s.IsEnabled() {
		return "", errors.New("ai service not configured")
	}

	messages := make([]map[string]interface{}, 0, len(history)+2)
	if strings.TrimSpace(systemPrompt) != "" {
		messages = append(messages, map[string]interface{}{
			"role":    "system",
			"content": systemPrompt,
		})
	}
	if strings.TrimSpace(preUser) != "" {
		messages = append(messages, map[string]interface{}{
			"role":    "user",
			"content": preUser,
		})
	}
	// for _, msg := range history {
	// 	if strings.TrimSpace(msg.Text) == "" {
	// 		continue
	// 	}
	// 	messages = append(messages, map[string]interface{}{
	// 		"role":    msg.Role,
	// 		"content": msg.Text,
	// 	})
	// }

	if len(imageUrls) > 0 {
		content := make([]map[string]interface{}, 0, len(imageUrls)+1)
		for _, url := range imageUrls {
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
		if strings.TrimSpace(userText) != "" {
			content = append(content, map[string]interface{}{
				"type": "text",
				"text": userText,
			})
		}
		messages = append(messages, map[string]interface{}{
			"role":    "user",
			"content": content,
		})
	} else {
		messages = append(messages, map[string]interface{}{
			"role":    "user",
			"content": userText,
		})
	}

	reqBody := map[string]interface{}{
		"model":       s.model,
		"messages":    messages,
		"temperature": 0.6,
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

	return parseAIContent(decoded.Choices[0].Message.Content)
}

func parseAIContent(content interface{}) (string, error) {
	switch value := content.(type) {
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
