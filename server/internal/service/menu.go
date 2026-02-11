package service

import (
	"eatclean/internal/model"
	"regexp"
	"strings"
)

type MenuService struct{}

func NewMenuService() *MenuService {
	return &MenuService{}
}

var (
	pricePattern = regexp.MustCompile(`(?i)(￥|¥|rmb|\$)?\s*\d+([.,]\d{1,2})?\s*(元|块|rmb|usd|\$)?`)
	multiSplit   = regexp.MustCompile(`[，,、/|]`)
	spaceClean   = regexp.MustCompile(`\s+`)
)

func (s *MenuService) ParseMenuText(text string) *model.MenuParseResponse {
	lines := splitLines(text)
	unique := make(map[string]struct{})
	var items []model.MenuItem

	for _, line := range lines {
		line = normalizeLine(line)
		if line == "" {
			continue
		}
		parts := multiSplit.Split(line, -1)
		for _, part := range parts {
			name := normalizeLine(part)
			if name == "" || len([]rune(name)) < 2 {
				continue
			}
			if _, exists := unique[name]; exists {
				continue
			}
			unique[name] = struct{}{}
			items = append(items, model.MenuItem{Name: name})
		}
	}

	return &model.MenuParseResponse{
		Items:     items,
		ItemCount: len(items),
		RawText:   strings.TrimSpace(text),
	}
}

func splitLines(text string) []string {
	text = strings.ReplaceAll(text, "\r\n", "\n")
	text = strings.ReplaceAll(text, "\r", "\n")
	return strings.Split(text, "\n")
}

func normalizeLine(line string) string {
	line = strings.TrimSpace(line)
	if line == "" {
		return ""
	}
	line = pricePattern.ReplaceAllString(line, "")
	line = strings.Trim(line, "-—•·•*()（）[]【】|：:;；")
	line = spaceClean.ReplaceAllString(line, " ")
	return strings.TrimSpace(line)
}
