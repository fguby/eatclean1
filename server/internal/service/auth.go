package service

import (
	"context"
	"eatclean/internal/config"
	"eatclean/internal/model"
	"eatclean/internal/repository"
	"errors"
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
			user = &model.User{
				Platform:    req.Platform,
				AppleUserID: req.AppleUserID,
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
			user = &model.User{
				Platform:     req.Platform,
				WechatOpenID: req.WechatOpenID,
				UnionID:      req.UnionID,
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
			UnionID:      req.UnionID,
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
		user = &model.User{
			Platform:    "account",
			LastLoginAt: timePtr(time.Now()),
		}
		if err := s.userRepo.CreateWithAccount(user, *req.Account, string(hash)); err != nil {
			return nil, err
		}
	} else {
		return nil, ErrInvalidCredentials
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
