package handler

import (
	"bytes"
	"crypto/ecdsa"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"eatclean/internal/config"
	"eatclean/internal/service"
	"eatclean/pkg/response"

	"github.com/golang-jwt/jwt/v5"
	"github.com/labstack/echo/v4"
)

type SubscriptionHandler struct {
	subscriptions *service.SubscriptionService
	appleCfg      *config.AppleConfig
	appleKeyOnce  sync.Once
	appleKey      *ecdsa.PrivateKey
	appleKeyErr   error
}

func NewSubscriptionHandler(
	subscriptions *service.SubscriptionService,
	appleCfg *config.AppleConfig,
) *SubscriptionHandler {
	return &SubscriptionHandler{subscriptions: subscriptions, appleCfg: appleCfg}
}

type subscriptionVerifyRequest struct {
	Platform           string `json:"platform"`
	ProductID          string `json:"product_id"`
	TransactionID      string `json:"transaction_id"`
	VerificationData   string `json:"verification_data"`
	VerificationSource string `json:"verification_source"`
	TransactionDate    string `json:"transaction_date"`
}

type appleVerifyResponse struct {
	Status            int                `json:"status"`
	LatestReceiptInfo []appleReceiptInfo `json:"latest_receipt_info"`
	Receipt           appleReceipt       `json:"receipt"`
}

type appleReceipt struct {
	InApp []appleReceiptInfo `json:"in_app"`
}

type appleReceiptInfo struct {
	ProductID             string `json:"product_id"`
	ExpiresDateMs         string `json:"expires_date_ms"`
	TransactionID         string `json:"transaction_id"`
	OriginalTransactionID string `json:"original_transaction_id"`
}

func (h *SubscriptionHandler) Verify(c echo.Context) error {
	userID, ok := c.Get("user_id").(int64)
	if !ok {
		return response.Unauthorized(c, "invalid user context")
	}
	var req subscriptionVerifyRequest
	if err := c.Bind(&req); err != nil {
		return response.BadRequest(c, "invalid request body")
	}
	if req.VerificationData == "" {
		return response.BadRequest(c, "verification_data is required")
	}
	receiptPrefix := req.VerificationData
	if len(receiptPrefix) > 16 {
		receiptPrefix = receiptPrefix[:16]
	}
	receiptPrefix = strings.NewReplacer("\n", "", "\r", "", "\t", "").Replace(receiptPrefix)
	isJWS := strings.Contains(req.VerificationData, ".")
	c.Logger().Debugf(
		"subscription verify payload: platform=%s product_id=%s transaction_id=%s source=%s receipt_len=%d receipt_prefix=%q is_jws=%t",
		req.Platform,
		req.ProductID,
		req.TransactionID,
		req.VerificationSource,
		len(req.VerificationData),
		receiptPrefix,
		isJWS,
	)
	if isJWS {
		if h.appleCfg == nil ||
			h.appleCfg.IssuerID == "" ||
			h.appleCfg.KeyID == "" ||
			h.appleCfg.BundleID == "" ||
			h.appleCfg.PrivateKeyPath == "" {
			return response.InternalError(c, "app store server api credentials missing")
		}
	} else {
		if h.appleCfg == nil || h.appleCfg.SharedSecret == "" {
			return response.InternalError(c, "apple shared secret is not configured")
		}
	}

	info, err := h.verifyAppleReceipt(req.VerificationData, req.ProductID)
	if err != nil {
		c.Logger().Errorf("apple receipt verification failed: %v", err)
		return response.InternalError(c, err.Error())
	}

	active := false
	status := "inactive"
	var expireAt *time.Time
	var transactionID string
	var originalTransactionID string
	if info != nil && info.ExpiresDateMs != "" {
		if ms, err := strconv.ParseInt(info.ExpiresDateMs, 10, 64); err == nil {
			tm := time.Unix(0, ms*int64(time.Millisecond))
			expireAt = &tm
			if tm.After(time.Now()) {
				active = true
				status = "active"
			} else {
				status = "expired"
			}
		}
	}

	if info != nil {
		transactionID = info.TransactionID
		originalTransactionID = info.OriginalTransactionID
	}
	if transactionID == "" {
		transactionID = req.TransactionID
	}
	if originalTransactionID == "" {
		originalTransactionID = transactionID
	}

	if h.subscriptions != nil {
		if err := h.subscriptions.Save(
			userID,
			"ios",
			pickValue(req.ProductID, info),
			status,
			expireAt,
			transactionID,
			originalTransactionID,
		); err != nil {
			c.Logger().Errorf("save subscription failed: %v", err)
		}
	}
	subscriberRank := 0
	if h.subscriptions != nil {
		if count, err := h.subscriptions.CountDistinctSubscribers(); err == nil {
			subscriberRank = count
		}
	}

	return response.Success(c, map[string]interface{}{
		"active":     active,
		"status":     status,
		"expire_at":  expireAt,
		"product_id": pickValue(req.ProductID, info),
		"subscriber_rank": subscriberRank,
	})
}

// Restore handles "恢复购买": re-fetch transaction by transaction_id and upsert status.
func (h *SubscriptionHandler) Restore(c echo.Context) error {
	userID, ok := c.Get("user_id").(int64)
	if !ok {
		return response.Unauthorized(c, "invalid user context")
	}
	var body struct {
		TransactionID string `json:"transaction_id"`
		ProductID     string `json:"product_id"`
		Environment   string `json:"environment"`
	}
	if err := c.Bind(&body); err != nil || body.TransactionID == "" {
		return response.BadRequest(c, "transaction_id is required")
	}

	token, err := h.buildAppStoreServerToken()
	if err != nil {
		return response.InternalError(c, err.Error())
	}

	// 默认同时尝试生产与沙箱，避免环境判断不一致导致 401/404
	endpoints := []string{
		"https://api.storekit.itunes.apple.com",
		"https://api.storekit-sandbox.itunes.apple.com",
	}
	if strings.EqualFold(body.Environment, "sandbox") {
		endpoints = []string{
			"https://api.storekit-sandbox.itunes.apple.com",
			"https://api.storekit.itunes.apple.com",
		}
	}

	var info *appleReceiptInfo
	var lastErr error
	for _, base := range endpoints {
		info, lastErr = fetchAppleTransaction(base, token, body.TransactionID)
		if lastErr == nil && info != nil {
			if body.ProductID != "" && info.ProductID != "" && info.ProductID != body.ProductID {
				continue
			}
			break
		}
	}
	if lastErr != nil {
		c.Logger().Errorf("restore failed: %v", lastErr)
		return response.InternalError(c, lastErr.Error())
	}
	if info == nil {
		err := errors.New("no transaction info returned")
		c.Logger().Error(err)
		return response.InternalError(c, err.Error())
	}

	status := "inactive"
	var expireAt *time.Time
	if info.ExpiresDateMs != "" {
		if ms, err := strconv.ParseInt(info.ExpiresDateMs, 10, 64); err == nil {
			tm := time.Unix(0, ms*int64(time.Millisecond))
			expireAt = &tm
			if tm.After(time.Now()) {
				status = "active"
			} else {
				status = "expired"
			}
		}
	}

	if h.subscriptions != nil {
		_ = h.subscriptions.Save(
			userID,
			"ios",
			pickValue(body.ProductID, info),
			status,
			expireAt,
			info.TransactionID,
			info.OriginalTransactionID,
		)
	}
	subscriberRank := 0
	if h.subscriptions != nil {
		if count, err := h.subscriptions.CountDistinctSubscribers(); err == nil {
			subscriberRank = count
		}
	}

	return response.Success(c, map[string]interface{}{
		"active":     status == "active",
		"status":     status,
		"expire_at":  expireAt,
		"product_id": pickValue(body.ProductID, info),
		"subscriber_rank": subscriberRank,
	})
}

func (h *SubscriptionHandler) verifyAppleReceipt(receiptData string, productID string) (*appleReceiptInfo, error) {
	if looksLikeJWS(receiptData) {
		return h.verifyAppleJWS(receiptData, productID)
	}
	payload := map[string]interface{}{
		"receipt-data":             receiptData,
		"password":                 h.appleCfg.SharedSecret,
		"exclude-old-transactions": true,
	}

	res, err := postAppleVerify("https://buy.itunes.apple.com/verifyReceipt", payload)
	if err != nil {
		return nil, err
	}
	if res.Status == 21007 {
		res, err = postAppleVerify("https://sandbox.itunes.apple.com/verifyReceipt", payload)
		if err != nil {
			return nil, err
		}
	} else if res.Status == 21008 {
		res, err = postAppleVerify("https://buy.itunes.apple.com/verifyReceipt", payload)
		if err != nil {
			return nil, err
		}
	}
	if res.Status != 0 {
		return nil, fmt.Errorf("apple receipt validation failed (status=%d)", res.Status)
	}

	infos := res.LatestReceiptInfo
	if len(infos) == 0 {
		infos = res.Receipt.InApp
	}
	if len(infos) == 0 {
		return nil, errors.New("no receipt info returned")
	}
	return pickLatestReceipt(infos, productID), nil
}

func (h *SubscriptionHandler) verifyAppleJWS(jwsToken string, productID string) (*appleReceiptInfo, error) {
	claims, err := decodeJWSPayload(jwsToken)
	if err != nil {
		return nil, fmt.Errorf("invalid jws payload: %w", err)
	}
	transactionID := readStringValue(claims, "transactionId", "transaction_id")
	environment := readStringValue(claims, "environment")
	if transactionID == "" {
		transactionID = readStringValue(
			claims,
			"originalTransactionId",
			"original_transaction_id",
		)
	}
	if transactionID == "" {
		return nil, errors.New("transaction id missing in jws")
	}

	token, err := h.buildAppStoreServerToken()
	if err != nil {
		return nil, err
	}

	// 同时尝试生产与沙箱，优先使用 JWS 指定的环境，以降低 401/404 的概率。
	endpoints := []string{
		"https://api.storekit.itunes.apple.com",
		"https://api.storekit-sandbox.itunes.apple.com",
	}
	if strings.EqualFold(environment, "Sandbox") {
		endpoints = []string{
			"https://api.storekit-sandbox.itunes.apple.com",
			"https://api.storekit.itunes.apple.com",
		}
	}

	var lastErr error
	for _, base := range endpoints {
		info, err := fetchAppleTransaction(base, token, transactionID)
		if err == nil && info != nil {
			if productID != "" && info.ProductID != "" && info.ProductID != productID {
				continue
			}
			return info, nil
		}
		lastErr = err
	}
	if lastErr != nil {
		return nil, lastErr
	}
	return nil, errors.New("no transaction info returned")
}

func (h *SubscriptionHandler) buildAppStoreServerToken() (string, error) {
	key, err := h.loadAppleKey()
	if err != nil {
		return "", err
	}
	now := time.Now()
	claims := jwt.MapClaims{
		"iss": h.appleCfg.IssuerID,
		"iat": now.Unix(),
		"exp": now.Add(15 * time.Minute).Unix(),
		"aud": "appstoreconnect-v1",
		"bid": h.appleCfg.BundleID,
	}
	token := jwt.NewWithClaims(jwt.SigningMethodES256, claims)
	token.Header["kid"] = h.appleCfg.KeyID
	signed, err := token.SignedString(key)
	if err != nil {
		return "", err
	}
	return signed, nil
}

func (h *SubscriptionHandler) loadAppleKey() (*ecdsa.PrivateKey, error) {
	h.appleKeyOnce.Do(func() {
		var data []byte
		var err error
		paths := resolveKeyPath(h.appleCfg.PrivateKeyPath)
		for _, candidate := range paths {
			data, err = os.ReadFile(candidate)
			if err == nil {
				break
			}
		}
		if err != nil {
			h.appleKeyErr = fmt.Errorf("read private key failed: %w", err)
			return
		}
		block, _ := pem.Decode(data)
		if block == nil {
			h.appleKeyErr = errors.New("invalid private key pem")
			return
		}
		parsed, err := x509.ParsePKCS8PrivateKey(block.Bytes)
		if err != nil {
			h.appleKeyErr = fmt.Errorf("parse private key failed: %w", err)
			return
		}
		key, ok := parsed.(*ecdsa.PrivateKey)
		if !ok {
			h.appleKeyErr = errors.New("private key is not ecdsa")
			return
		}
		h.appleKey = key
	})
	if h.appleKeyErr != nil {
		return nil, h.appleKeyErr
	}
	if h.appleKey == nil {
		return nil, errors.New("private key not loaded")
	}
	return h.appleKey, nil
}

func resolveKeyPath(path string) []string {
	if filepath.IsAbs(path) {
		return []string{path}
	}
	return []string{
		path,
		filepath.Join("..", path),
	}
}

func looksLikeJWS(value string) bool {
	return strings.Count(value, ".") >= 2
}

func decodeJWSPayload(token string) (map[string]interface{}, error) {
	parts := strings.Split(token, ".")
	if len(parts) < 2 {
		return nil, errors.New("invalid jws format")
	}
	decoded, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return nil, err
	}
	var payload map[string]interface{}
	if err := json.Unmarshal(decoded, &payload); err != nil {
		return nil, err
	}
	return payload, nil
}

func readStringValue(payload map[string]interface{}, keys ...string) string {
	for _, key := range keys {
		if value, ok := payload[key]; ok {
			switch v := value.(type) {
			case string:
				if v != "" {
					return v
				}
			case fmt.Stringer:
				if v.String() != "" {
					return v.String()
				}
			}
		}
	}
	return ""
}

func readInt64Value(payload map[string]interface{}, keys ...string) int64 {
	for _, key := range keys {
		if value, ok := payload[key]; ok {
			switch v := value.(type) {
			case int64:
				return v
			case int:
				return int64(v)
			case float64:
				return int64(v)
			case string:
				if parsed, err := strconv.ParseInt(v, 10, 64); err == nil {
					return parsed
				}
			}
		}
	}
	return 0
}

func fetchAppleTransaction(baseURL, token, transactionID string) (*appleReceiptInfo, error) {
	req, err := http.NewRequest(
		http.MethodGet,
		fmt.Sprintf("%s/inApps/v1/transactions/%s", baseURL, transactionID),
		nil,
	)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+token)
	client := &http.Client{Timeout: 12 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 400 {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf(
			"app store server api status=%d body=%s",
			resp.StatusCode,
			strings.TrimSpace(string(body)),
		)
	}
	var payload struct {
		SignedTransactionInfo string `json:"signedTransactionInfo"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		return nil, err
	}
	if payload.SignedTransactionInfo == "" {
		return nil, errors.New("signedTransactionInfo missing")
	}
	claims, err := decodeJWSPayload(payload.SignedTransactionInfo)
	if err != nil {
		return nil, err
	}
	info := &appleReceiptInfo{
		ProductID:             readStringValue(claims, "productId"),
		TransactionID:         readStringValue(claims, "transactionId"),
		OriginalTransactionID: readStringValue(claims, "originalTransactionId"),
	}
	expiresMs := readInt64Value(claims, "expiresDate", "expiresDateMs", "expires_date_ms")
	if expiresMs > 0 {
		info.ExpiresDateMs = strconv.FormatInt(expiresMs, 10)
	}
	return info, nil
}

func postAppleVerify(url string, payload map[string]interface{}) (*appleVerifyResponse, error) {
	body, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}
	req, err := http.NewRequest(http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	client := &http.Client{Timeout: 12 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	var parsed appleVerifyResponse
	if err := json.NewDecoder(resp.Body).Decode(&parsed); err != nil {
		return nil, err
	}
	return &parsed, nil
}

func pickLatestReceipt(infos []appleReceiptInfo, productID string) *appleReceiptInfo {
	var latest *appleReceiptInfo
	var latestMs int64
	for _, info := range infos {
		if productID != "" && info.ProductID != productID {
			continue
		}
		ms, err := strconv.ParseInt(info.ExpiresDateMs, 10, 64)
		if err != nil {
			ms = time.Now().Add(24 * time.Hour).UnixMilli()
		}
		if ms >= latestMs {
			copy := info
			latest = &copy
			latestMs = ms
		}
	}
	if latest != nil {
		return latest
	}
	return &infos[0]
}

func pickValue(fallback string, info *appleReceiptInfo) string {
	if info != nil && info.ProductID != "" {
		return info.ProductID
	}
	return fallback
}
