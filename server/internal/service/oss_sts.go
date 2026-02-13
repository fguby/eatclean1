package service

import (
	"context"
	"crypto/hmac"
	"crypto/sha1"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"sort"
	"strconv"
	"strings"
	"time"

	"eatclean/internal/config"

	"github.com/aliyun/aliyun-oss-go-sdk/oss"
)

type OssStsToken struct {
	AccessKeyID     string
	AccessKeySecret string
	SecurityToken   string
	Expiration      string
}

type OssService struct {
	cfg    *config.OSSConfig
	client *oss.Client
}

func NewOssService(cfg *config.OSSConfig) *OssService {
	return &OssService{cfg: cfg}
}

func (s *OssService) GetStsToken() (*OssStsToken, error) {
	if s.cfg == nil {
		return nil, errors.New("oss config is missing")
	}
	if s.cfg.AccessKeyID == "" || s.cfg.AccessKeySecret == "" || s.cfg.RoleArn == "" {
		return nil, errors.New("oss credentials are not configured")
	}
	return s.assumeRoleWithHTTP(context.Background())
}

func (s *OssService) assumeRoleWithHTTP(ctx context.Context) (*OssStsToken, error) {
	params := map[string]string{
		"Format":           "JSON",
		"Version":          "2015-04-01",
		"AccessKeyId":      s.cfg.AccessKeyID,
		"Action":           "AssumeRole",
		"RoleArn":          s.cfg.RoleArn,
		"RoleSessionName":  fmt.Sprintf("eatclean-%d", time.Now().Unix()),
		"DurationSeconds":  strconv.Itoa(s.cfg.StsDuration),
		"SignatureMethod":  "HMAC-SHA1",
		"SignatureVersion": "1.0",
		"SignatureNonce":   fmt.Sprintf("%d", time.Now().UnixNano()),
		"Timestamp":        time.Now().UTC().Format("2006-01-02T15:04:05Z"),
	}

	canonicalized := buildCanonicalQuery(params)
	stringToSign := "GET&%2F&" + percentEncode(canonicalized)
	signature := signString(stringToSign, s.cfg.AccessKeySecret+"&")
	params["Signature"] = signature

	endpoint := strings.TrimSpace(s.cfg.StsEndpoint)
	if endpoint == "" {
		endpoint = "https://sts.aliyuncs.com"
	}
	if !strings.HasPrefix(endpoint, "http") {
		endpoint = "https://" + endpoint
	}

	query := buildCanonicalQuery(params)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint+"/?"+query, nil)
	if err != nil {
		return nil, err
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var decoded struct {
		Credentials *struct {
			AccessKeyID     string `json:"AccessKeyId"`
			AccessKeySecret string `json:"AccessKeySecret"`
			SecurityToken   string `json:"SecurityToken"`
			Expiration      string `json:"Expiration"`
		} `json:"Credentials"`
		Code    string `json:"Code"`
		Message string `json:"Message"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&decoded); err != nil {
		return nil, err
	}
	if decoded.Credentials == nil {
		if decoded.Message != "" {
			return nil, errors.New(decoded.Message)
		}
		return nil, errors.New("empty sts response")
	}
	return &OssStsToken{
		AccessKeyID:     sanitizeSTSField(decoded.Credentials.AccessKeyID),
		AccessKeySecret: sanitizeSTSField(decoded.Credentials.AccessKeySecret),
		SecurityToken:   sanitizeSTSField(decoded.Credentials.SecurityToken),
		Expiration:      sanitizeSTSField(decoded.Credentials.Expiration),
	}, nil
}

func sanitizeSTSField(value string) string {
	value = strings.TrimSpace(value)
	value = strings.TrimPrefix(value, "\uFEFF")
	value = strings.ReplaceAll(value, "\r", "")
	value = strings.ReplaceAll(value, "\n", "")
	value = strings.ReplaceAll(value, "\t", "")
	return value
}

func buildCanonicalQuery(params map[string]string) string {
	keys := make([]string, 0, len(params))
	for key := range params {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	parts := make([]string, 0, len(keys))
	for _, key := range keys {
		parts = append(parts, percentEncode(key)+"="+percentEncode(params[key]))
	}
	return strings.Join(parts, "&")
}

func percentEncode(value string) string {
	escaped := url.QueryEscape(value)
	escaped = strings.ReplaceAll(escaped, "+", "%20")
	escaped = strings.ReplaceAll(escaped, "*", "%2A")
	escaped = strings.ReplaceAll(escaped, "%7E", "~")
	return escaped
}

func signString(source, key string) string {
	h := hmac.New(sha1.New, []byte(key))
	h.Write([]byte(source))
	return base64.StdEncoding.EncodeToString(h.Sum(nil))
}

func (s *OssService) SignURLs(urls []string, ttl time.Duration) ([]string, error) {
	if len(urls) == 0 {
		return []string{}, nil
	}
	result := make([]string, 0, len(urls))
	for _, raw := range urls {
		signed, err := s.SignURL(raw, ttl)
		if err != nil {
			return nil, err
		}
		result = append(result, signed)
	}
	return result, nil
}

func (s *OssService) SignURL(rawURL string, ttl time.Duration) (string, error) {
	if s.cfg == nil {
		return "", errors.New("oss config is missing")
	}
	if s.cfg.AccessKeyID == "" || s.cfg.AccessKeySecret == "" || s.cfg.Bucket == "" || s.cfg.Endpoint == "" {
		return "", errors.New("oss signer not configured")
	}
	objectKey, err := s.extractObjectKey(rawURL)
	if err != nil {
		return "", err
	}
	client, err := s.getClient()
	if err != nil {
		return "", err
	}
	bucket, err := client.Bucket(s.cfg.Bucket)
	if err != nil {
		return "", err
	}
	expireSeconds := int64(ttl.Seconds())
	if expireSeconds <= 0 {
		expireSeconds = int64(time.Hour.Seconds())
	}
	return bucket.SignURL(objectKey, oss.HTTPGet, expireSeconds)
}

func (s *OssService) getClient() (*oss.Client, error) {
	if s.client != nil {
		return s.client, nil
	}
	endpoint := strings.TrimSpace(s.cfg.Endpoint)
	if !strings.HasPrefix(endpoint, "http") {
		endpoint = "https://" + endpoint
	}
	client, err := oss.New(endpoint, s.cfg.AccessKeyID, s.cfg.AccessKeySecret)
	if err != nil {
		return nil, err
	}
	s.client = client
	return client, nil
}

func (s *OssService) extractObjectKey(rawURL string) (string, error) {
	rawURL = strings.TrimSpace(rawURL)
	if rawURL == "" {
		return "", errors.New("empty url")
	}
	if !strings.Contains(rawURL, "://") {
		return strings.TrimPrefix(rawURL, "/"), nil
	}
	parsed, err := url.Parse(rawURL)
	if err != nil {
		return "", err
	}
	path := strings.TrimPrefix(parsed.Path, "/")
	if path == "" {
		return "", errors.New("empty object key")
	}
	bucketPrefix := s.cfg.Bucket + "/"
	if strings.HasPrefix(path, bucketPrefix) {
		path = strings.TrimPrefix(path, bucketPrefix)
	}
	return path, nil
}
