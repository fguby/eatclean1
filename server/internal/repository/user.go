package repository

import (
	"database/sql"
	"eatclean/internal/model"
	"errors"
	"strings"
	"time"
)

type UserRepository struct {
	db *sql.DB
}

func NewUserRepository(db *sql.DB) *UserRepository {
	return &UserRepository{db: db}
}

func (r *UserRepository) FindByAppleUserID(appleUserID string) (*model.User, error) {
	user := &model.User{}
	query := `SELECT id, platform, apple_user_id, wechat_openid, unionid, avatar_url, created_at, last_login_at 
	          FROM app_user WHERE apple_user_id = $1`

	err := r.db.QueryRow(query, appleUserID).Scan(
		&user.ID, &user.Platform, &user.AppleUserID, &user.WechatOpenID,
		&user.UnionID, &user.AvatarURL, &user.CreatedAt, &user.LastLoginAt,
	)

	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return user, nil
}

func (r *UserRepository) FindByWechatOpenID(openID string) (*model.User, error) {
	user := &model.User{}
	query := `SELECT id, platform, apple_user_id, wechat_openid, unionid, avatar_url, created_at, last_login_at 
	          FROM app_user WHERE wechat_openid = $1`

	err := r.db.QueryRow(query, openID).Scan(
		&user.ID, &user.Platform, &user.AppleUserID, &user.WechatOpenID,
		&user.UnionID, &user.AvatarURL, &user.CreatedAt, &user.LastLoginAt,
	)

	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return user, nil
}

func (r *UserRepository) FindByUnionID(unionID string) (*model.User, error) {
	key := strings.TrimSpace(unionID)
	if key == "" {
		return nil, nil
	}

	user := &model.User{}
	query := `SELECT id, platform, apple_user_id, wechat_openid, unionid, avatar_url, created_at, last_login_at
	          FROM app_user WHERE unionid = $1`

	err := r.db.QueryRow(query, key).Scan(
		&user.ID, &user.Platform, &user.AppleUserID, &user.WechatOpenID,
		&user.UnionID, &user.AvatarURL, &user.CreatedAt, &user.LastLoginAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return user, nil
}

func (r *UserRepository) FindByAccount(account string) (*model.User, string, error) {
	user := &model.User{}
	var passwordHash string
	query := `SELECT u.id, u.platform, u.apple_user_id, u.wechat_openid, u.unionid, u.avatar_url, u.created_at, u.last_login_at, a.password_hash
	          FROM app_user u
	          JOIN user_account a ON a.user_id = u.id
	          WHERE LOWER(a.account) = LOWER($1)`

	err := r.db.QueryRow(query, account).Scan(
		&user.ID, &user.Platform, &user.AppleUserID, &user.WechatOpenID,
		&user.UnionID, &user.AvatarURL, &user.CreatedAt, &user.LastLoginAt, &passwordHash,
	)

	if err == sql.ErrNoRows {
		return nil, "", nil
	}
	if err != nil {
		return nil, "", err
	}
	return user, passwordHash, nil
}

func (r *UserRepository) Create(user *model.User) error {
	query := `INSERT INTO app_user (platform, apple_user_id, wechat_openid, unionid, avatar_url, last_login_at) 
	          VALUES ($1, $2, $3, $4, $5, $6) RETURNING id, created_at`

	return r.db.QueryRow(query, user.Platform, user.AppleUserID, user.WechatOpenID,
		user.UnionID, user.AvatarURL, user.LastLoginAt).Scan(&user.ID, &user.CreatedAt)
}

func (r *UserRepository) CreateWithAccount(user *model.User, account string, passwordHash string) error {
	if account == "" || passwordHash == "" {
		return errors.New("account and password hash are required")
	}

	tx, err := r.db.Begin()
	if err != nil {
		return err
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
		}
	}()

	query := `INSERT INTO app_user (platform, apple_user_id, wechat_openid, unionid, avatar_url, last_login_at) 
	          VALUES ($1, $2, $3, $4, $5, $6) RETURNING id, created_at`
	err = tx.QueryRow(query, user.Platform, user.AppleUserID, user.WechatOpenID,
		user.UnionID, user.AvatarURL, user.LastLoginAt).Scan(&user.ID, &user.CreatedAt)
	if err != nil {
		return err
	}

	_, err = tx.Exec(
		`INSERT INTO user_account (user_id, account, password_hash) VALUES ($1, $2, $3)`,
		user.ID, account, passwordHash,
	)
	if err != nil {
		return err
	}

	return tx.Commit()
}

func (r *UserRepository) UpdateLastLogin(userID int64) error {
	query := `UPDATE app_user SET last_login_at = $1 WHERE id = $2`
	_, err := r.db.Exec(query, time.Now(), userID)
	return err
}

func (r *UserRepository) UpdateUnionID(userID int64, unionID string) error {
	key := strings.TrimSpace(unionID)
	if key == "" {
		return errors.New("unionid is required")
	}
	_, err := r.db.Exec(
		`UPDATE app_user SET unionid = $1 WHERE id = $2`,
		key,
		userID,
	)
	return err
}

func (r *UserRepository) FindByID(userID int64) (*model.User, error) {
	user := &model.User{}
	query := `SELECT id, platform, apple_user_id, wechat_openid, unionid, avatar_url, created_at, last_login_at 
	          FROM app_user WHERE id = $1`

	err := r.db.QueryRow(query, userID).Scan(
		&user.ID, &user.Platform, &user.AppleUserID, &user.WechatOpenID,
		&user.UnionID, &user.AvatarURL, &user.CreatedAt, &user.LastLoginAt,
	)

	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return user, nil
}

func (r *UserRepository) EnsureAvatarColumn() {
	_, _ = r.db.Exec(`ALTER TABLE app_user ADD COLUMN IF NOT EXISTS avatar_url TEXT`)
}

func (r *UserRepository) UpdateAvatar(userID int64, url string) error {
	_, err := r.db.Exec(
		`UPDATE app_user SET avatar_url = $1 WHERE id = $2`,
		url,
		userID,
	)
	return err
}
