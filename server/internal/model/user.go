package model

import (
	"encoding/json"
	"time"
)

type User struct {
	ID           int64      `json:"id" db:"id"`
	Platform     string     `json:"platform" db:"platform"`
	AppleUserID  *string    `json:"apple_user_id,omitempty" db:"apple_user_id"`
	WechatOpenID *string    `json:"wechat_openid,omitempty" db:"wechat_openid"`
	UnionID      *string    `json:"unionid,omitempty" db:"unionid"`
	AvatarURL    *string    `json:"avatar_url,omitempty" db:"avatar_url"`
	CreatedAt    time.Time  `json:"created_at" db:"created_at"`
	LastLoginAt  *time.Time `json:"last_login_at,omitempty" db:"last_login_at"`
}

type LoginRequest struct {
	Platform           string  `json:"platform" validate:"required,oneof=ios android account"`
	AppleUserID        *string `json:"apple_user_id,omitempty"`
	AppleIdentityToken *string `json:"apple_identity_token,omitempty"`
	Account            *string `json:"account,omitempty"`
	Password           *string `json:"password,omitempty"`
	WechatCode         *string `json:"wechat_code,omitempty"`
	WechatOpenID       *string `json:"wechat_openid,omitempty"`
	UnionID            *string `json:"unionid,omitempty"`
}

type RegisterRequest = LoginRequest

type LoginResponse struct {
	Token        string          `json:"token"`
	User         *User           `json:"user"`
	IsNewUser    bool            `json:"is_new_user"`
	Settings     json.RawMessage `json:"settings,omitempty"`
	IsSubscriber bool            `json:"is_subscriber"`
}
