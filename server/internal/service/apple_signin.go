package service

import (
	"context"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"math/big"
	"net/http"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

const (
	appleIssuer  = "https://appleid.apple.com"
	appleKeysURL = "https://appleid.apple.com/auth/keys"
)

type appleKeyCache struct {
	mu        sync.RWMutex
	keys      map[string]*rsa.PublicKey
	expiresAt time.Time
}

func newAppleKeyCache() *appleKeyCache {
	return &appleKeyCache{
		keys: make(map[string]*rsa.PublicKey),
	}
}

func (s *AuthService) verifyAppleIdentityToken(ctx context.Context, identityToken string, expectedSub string) (string, error) {
	if s.appleCfg == nil || s.appleCfg.ClientID == "" {
		return "", ErrAppleConfigMissing
	}
	if identityToken == "" {
		return "", ErrAppleTokenInvalid
	}

	options := []jwt.ParserOption{
		jwt.WithValidMethods([]string{"RS256"}),
		jwt.WithIssuer(appleIssuer),
		jwt.WithAudience(s.appleCfg.ClientID),
	}
	if expectedSub != "" {
		options = append(options, jwt.WithSubject(expectedSub))
	}

	parser := jwt.NewParser(options...)
	claims := jwt.MapClaims{}
	token, err := parser.ParseWithClaims(identityToken, claims, func(token *jwt.Token) (interface{}, error) {
		kid, ok := token.Header["kid"].(string)
		if !ok || kid == "" {
			return nil, ErrAppleTokenInvalid
		}
		return s.appleKeys.getKey(ctx, kid)
	})
	if err != nil {
		if errors.Is(err, ErrAppleKeyFetch) {
			return "", err
		}
		return "", ErrAppleTokenInvalid
	}
	if !token.Valid {
		return "", ErrAppleTokenInvalid
	}

	sub, err := claims.GetSubject()
	if err != nil || sub == "" {
		return "", ErrAppleTokenInvalid
	}
	return sub, nil
}

func (c *appleKeyCache) getKey(ctx context.Context, kid string) (*rsa.PublicKey, error) {
	now := time.Now()
	c.mu.RLock()
	if now.Before(c.expiresAt) {
		if key, ok := c.keys[kid]; ok {
			c.mu.RUnlock()
			return key, nil
		}
	}
	c.mu.RUnlock()

	c.mu.Lock()
	defer c.mu.Unlock()
	now = time.Now()
	if now.Before(c.expiresAt) {
		if key, ok := c.keys[kid]; ok {
			return key, nil
		}
	}

	keys, err := fetchApplePublicKeys(ctx)
	if err != nil {
		if key, ok := c.keys[kid]; ok {
			return key, nil
		}
		return nil, fmt.Errorf("%w: %v", ErrAppleKeyFetch, err)
	}

	c.keys = keys
	c.expiresAt = time.Now().Add(24 * time.Hour)
	key, ok := c.keys[kid]
	if !ok {
		return nil, fmt.Errorf("apple public key %s not found", kid)
	}
	return key, nil
}

type appleJWKS struct {
	Keys []appleJWK `json:"keys"`
}

type appleJWK struct {
	Kid string `json:"kid"`
	Kty string `json:"kty"`
	Alg string `json:"alg"`
	Use string `json:"use"`
	N   string `json:"n"`
	E   string `json:"e"`
}

func fetchApplePublicKeys(ctx context.Context) (map[string]*rsa.PublicKey, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, appleKeysURL, nil)
	if err != nil {
		return nil, err
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("apple keys endpoint returned %d", resp.StatusCode)
	}

	var jwks appleJWKS
	if err := json.NewDecoder(resp.Body).Decode(&jwks); err != nil {
		return nil, err
	}

	keys := make(map[string]*rsa.PublicKey)
	for _, key := range jwks.Keys {
		if key.Kty != "RSA" || key.N == "" || key.E == "" || key.Kid == "" {
			continue
		}
		pub, err := parseAppleRSAPublicKey(key)
		if err != nil {
			continue
		}
		keys[key.Kid] = pub
	}
	if len(keys) == 0 {
		return nil, errors.New("no apple public keys available")
	}
	return keys, nil
}

func parseAppleRSAPublicKey(jwk appleJWK) (*rsa.PublicKey, error) {
	nBytes, err := base64.RawURLEncoding.DecodeString(jwk.N)
	if err != nil {
		return nil, err
	}
	eBytes, err := base64.RawURLEncoding.DecodeString(jwk.E)
	if err != nil {
		return nil, err
	}

	n := new(big.Int).SetBytes(nBytes)
	e := new(big.Int).SetBytes(eBytes)
	if n.Sign() == 0 || e.Sign() == 0 {
		return nil, errors.New("invalid apple public key")
	}

	eInt := int(e.Int64())
	if eInt <= 0 {
		return nil, errors.New("invalid apple public key exponent")
	}
	return &rsa.PublicKey{N: n, E: eInt}, nil
}
