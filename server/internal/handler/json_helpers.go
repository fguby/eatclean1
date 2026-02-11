package handler

import "encoding/json"

func mustMarshalJSON(value interface{}) json.RawMessage {
	data, err := json.Marshal(value)
	if err != nil {
		return json.RawMessage("[]")
	}
	return data
}
