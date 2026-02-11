package repository

import "encoding/json"

func normalizeJSON(raw json.RawMessage, fallback string) string {
	if len(raw) == 0 {
		if fallback == "" {
			return "null"
		}
		return fallback
	}
	return string(raw)
}
