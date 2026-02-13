package service

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"eatclean/internal/config"
	"eatclean/internal/model"
	"eatclean/internal/repository"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
)

type AuthService struct {
	userRepo  *repository.UserRepository
	jwtCfg    *config.JWTConfig
	appleCfg  *config.AppleConfig
	appleKeys *appleKeyCache
}

var (
	ErrUserExists         = errors.New("user already exists")
	ErrInvalidCredentials = errors.New("invalid credentials")
	ErrAppleConfigMissing = errors.New("apple client id is not configured")
	ErrAppleTokenInvalid  = errors.New("invalid apple identity token")
	ErrAppleKeyFetch      = errors.New("apple public key fetch failed")
)

func NewAuthService(userRepo *repository.UserRepository, jwtCfg *config.JWTConfig, appleCfg *config.AppleConfig) *AuthService {
	return &AuthService{
		userRepo:  userRepo,
		jwtCfg:    jwtCfg,
		appleCfg:  appleCfg,
		appleKeys: newAppleKeyCache(),
	}
}

type JWTClaims struct {
	UserID   int64   `json:"user_id"`
	Platform string  `json:"platform"`
	Avatar   *string `json:"avatar_url,omitempty"`
	jwt.RegisteredClaims
}

func (s *AuthService) Login(ctx context.Context, req *model.LoginRequest) (*model.LoginResponse, error) {
	var user *model.User
	var err error
	isNewUser := false

	// 根据平台和登录方式查找或创建用户
	if req.Platform == "ios" {
		if req.AppleIdentityToken == nil {
			return nil, ErrAppleTokenInvalid
		}
		expectedSub := ""
		if req.AppleUserID != nil {
			expectedSub = *req.AppleUserID
		}
		sub, err := s.verifyAppleIdentityToken(ctx, *req.AppleIdentityToken, expectedSub)
		if err != nil {
			return nil, err
		}
		if req.AppleUserID == nil || *req.AppleUserID == "" {
			req.AppleUserID = &sub
		}
		user, err = s.userRepo.FindByAppleUserID(*req.AppleUserID)
		if err != nil {
			return nil, err
		}
		if user == nil {
			// 创建新用户
			unionID := s.newUnionID()
			user = &model.User{
				Platform:    req.Platform,
				AppleUserID: req.AppleUserID,
				UnionID:     &unionID,
				LastLoginAt: timePtr(time.Now()),
			}
			if err := s.userRepo.Create(user); err != nil {
				return nil, err
			}
			isNewUser = true
		}
	} else if req.Platform == "android" && req.WechatOpenID != nil {
		user, err = s.userRepo.FindByWechatOpenID(*req.WechatOpenID)
		if err != nil {
			return nil, err
		}
		if user == nil {
			// 创建新用户
			unionID := strings.TrimSpace(derefString(req.UnionID))
			if unionID == "" {
				unionID = s.newUnionID()
			}
			user = &model.User{
				Platform:     req.Platform,
				WechatOpenID: req.WechatOpenID,
				UnionID:      &unionID,
				LastLoginAt:  timePtr(time.Now()),
			}
			if err := s.userRepo.Create(user); err != nil {
				return nil, err
			}
			isNewUser = true
		}
	} else if req.Platform == "account" {
		if req.Account == nil || req.Password == nil {
			return nil, ErrInvalidCredentials
		}
		user, passwordHash, err := s.userRepo.FindByAccount(*req.Account)
		if err != nil {
			return nil, err
		}
		if user == nil {
			return nil, ErrInvalidCredentials
		}
		if err := bcrypt.CompareHashAndPassword([]byte(passwordHash), []byte(*req.Password)); err != nil {
			return nil, ErrInvalidCredentials
		}
	} else {
		return nil, ErrInvalidCredentials
	}

	// 更新最后登录时间
	if !isNewUser {
		if err := s.userRepo.UpdateLastLogin(user.ID); err != nil {
			return nil, err
		}
		user.LastLoginAt = timePtr(time.Now())
	}
	if err := s.ensureUnionID(user); err != nil {
		return nil, err
	}

	// 生成 JWT token
	token, err := s.generateToken(user)
	if err != nil {
		return nil, err
	}

	return &model.LoginResponse{
		Token:     token,
		User:      user,
		IsNewUser: isNewUser,
	}, nil
}

func (s *AuthService) Register(ctx context.Context, req *model.RegisterRequest) (*model.LoginResponse, error) {
	var user *model.User
	var err error

	if req.Platform == "ios" {
		if req.AppleIdentityToken == nil {
			return nil, ErrAppleTokenInvalid
		}
		expectedSub := ""
		if req.AppleUserID != nil {
			expectedSub = *req.AppleUserID
		}
		sub, err := s.verifyAppleIdentityToken(ctx, *req.AppleIdentityToken, expectedSub)
		if err != nil {
			return nil, err
		}
		if req.AppleUserID == nil || *req.AppleUserID == "" {
			req.AppleUserID = &sub
		}
		user, err = s.userRepo.FindByAppleUserID(*req.AppleUserID)
		if err != nil {
			return nil, err
		}
		if user != nil {
			return nil, ErrUserExists
		}
		user = &model.User{
			Platform:    req.Platform,
			AppleUserID: req.AppleUserID,
			UnionID:     stringPtr(s.newUnionID()),
			LastLoginAt: timePtr(time.Now()),
		}
		if err := s.userRepo.Create(user); err != nil {
			return nil, err
		}
	} else if req.Platform == "android" && req.WechatOpenID != nil {
		user, err = s.userRepo.FindByWechatOpenID(*req.WechatOpenID)
		if err != nil {
			return nil, err
		}
		if user != nil {
			return nil, ErrUserExists
		}
		user = &model.User{
			Platform:     req.Platform,
			WechatOpenID: req.WechatOpenID,
			UnionID:      stringPtr(firstNonEmpty(derefString(req.UnionID), s.newUnionID())),
			LastLoginAt:  timePtr(time.Now()),
		}
		if err := s.userRepo.Create(user); err != nil {
			return nil, err
		}
	} else if req.Platform == "account" {
		if req.Account == nil || req.Password == nil {
			return nil, ErrInvalidCredentials
		}
		existing, _, err := s.userRepo.FindByAccount(*req.Account)
		if err != nil {
			return nil, err
		}
		if existing != nil {
			return nil, ErrUserExists
		}
		hash, err := bcrypt.GenerateFromPassword([]byte(*req.Password), bcrypt.DefaultCost)
		if err != nil {
			return nil, err
		}
		unionID := s.newUnionID()
		user = &model.User{
			Platform:    "account",
			UnionID:     &unionID,
			LastLoginAt: timePtr(time.Now()),
		}
		if err := s.userRepo.CreateWithAccount(user, *req.Account, string(hash)); err != nil {
			return nil, err
		}
	} else {
		return nil, ErrInvalidCredentials
	}

	if err := s.ensureUnionID(user); err != nil {
		return nil, err
	}

	token, err := s.generateToken(user)
	if err != nil {
		return nil, err
	}

	return &model.LoginResponse{
		Token:     token,
		User:      user,
		IsNewUser: true,
	}, nil
}

func (s *AuthService) generateToken(user *model.User) (string, error) {
	claims := &JWTClaims{
		UserID:   user.ID,
		Platform: user.Platform,
		Avatar:   user.AvatarURL,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Hour * time.Duration(s.jwtCfg.ExpireHours))),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(s.jwtCfg.Secret))
}

func (s *AuthService) ValidateToken(tokenString string) (*JWTClaims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &JWTClaims{}, func(token *jwt.Token) (interface{}, error) {
		return []byte(s.jwtCfg.Secret), nil
	})

	if err != nil {
		return nil, err
	}

	if claims, ok := token.Claims.(*JWTClaims); ok && token.Valid {
		return claims, nil
	}

	return nil, errors.New("invalid token")
}

func timePtr(t time.Time) *time.Time {
	return &t
}

func (s *AuthService) UpdateAvatar(userID int64, url string) error {
	if s.userRepo == nil {
		return errors.New("user repo not available")
	}
	return s.userRepo.UpdateAvatar(userID, url)
}

func (s *AuthService) ensureUnionID(user *model.User) error {
	if s.userRepo == nil || user == nil {
		return errors.New("user repo not available")
	}
	if strings.TrimSpace(derefString(user.UnionID)) != "" {
		return nil
	}
	for i := 0; i < 8; i++ {
		candidate := s.newUnionID()
		exists, err := s.userRepo.FindByUnionID(candidate)
		if err != nil {
			return err
		}
		if exists != nil {
			continue
		}
		if err := s.userRepo.UpdateUnionID(user.ID, candidate); err != nil {
			return err
		}
		user.UnionID = stringPtr(candidate)
		return nil
	}
	return fmt.Errorf("failed to allocate unionid for user %d", user.ID)
}

func (s *AuthService) newUnionID() string {
	var raw [10]byte
	if _, err := rand.Read(raw[:]); err != nil {
		return fmt.Sprintf("u%d", time.Now().UnixNano())
	}
	return "u" + hex.EncodeToString(raw[:])
}

func derefString(value *string) string {
	if value == nil {
		return ""
	}
	return *value
}

func stringPtr(value string) *string {
	v := strings.TrimSpace(value)
	if v == "" {
		return nil
	}
	return &v
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if strings.TrimSpace(v) != "" {
			return strings.TrimSpace(v)
		}
	}
	return ""
}
