package model

type MenuParseRequest struct {
	Text string `json:"text"`
}

type MenuScanRequest struct {
	ImageUrls      []string `json:"image_urls"`
	RestaurantHint string   `json:"restaurant_hint,omitempty"`
	ClientTime     string   `json:"client_time,omitempty"`
	Note           string   `json:"note,omitempty"`
}

type MenuItem struct {
	Name string `json:"name"`
}

type MenuParseResponse struct {
	Items     []MenuItem `json:"items"`
	ItemCount int        `json:"item_count"`
	RawText   string     `json:"raw_text"`
}
