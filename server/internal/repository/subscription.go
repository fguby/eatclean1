package repository

import (
	"database/sql"
	"fmt"
	"time"
)

type SubscriptionRepository struct {
	db *sql.DB
}

type SubscriptionRecord struct {
	SKU       string
	Status    string
	ExpireAt  *time.Time
	UpdatedAt time.Time
}

func NewSubscriptionRepository(db *sql.DB) *SubscriptionRepository {
	return &SubscriptionRepository{db: db}
}

func (r *SubscriptionRepository) EnsureTable() error {
	if r.db == nil {
		return sql.ErrConnDone
	}
	_, err := r.db.Exec(`
		CREATE TABLE IF NOT EXISTS subscription (
			id BIGSERIAL PRIMARY KEY,
			user_id BIGINT REFERENCES app_user(id) ON DELETE CASCADE,
			platform VARCHAR(20),
			sku VARCHAR(50),
			status VARCHAR(20),
			expire_at TIMESTAMP,
			transaction_id VARCHAR(100),
			original_transaction_id VARCHAR(100),
			created_at TIMESTAMP DEFAULT NOW(),
			updated_at TIMESTAMP DEFAULT NOW()
		)
	`)
	if err != nil {
		return err
	}
	_, err = r.db.Exec(`CREATE INDEX IF NOT EXISTS idx_subscription_user ON subscription(user_id)`)
	if err != nil {
		return err
	}
	// best-effort schema upgrades for existing tables
	_, _ = r.db.Exec(`ALTER TABLE subscription ADD COLUMN IF NOT EXISTS transaction_id VARCHAR(100)`)
	_, _ = r.db.Exec(`ALTER TABLE subscription ADD COLUMN IF NOT EXISTS original_transaction_id VARCHAR(100)`)
	_, _ = r.db.Exec(`ALTER TABLE subscription ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT NOW()`)
	_, _ = r.db.Exec(`CREATE UNIQUE INDEX IF NOT EXISTS idx_subscription_user_txn ON subscription(user_id, transaction_id)`)
	return nil
}

func (r *SubscriptionRepository) ListActiveUserIDs() ([]int64, error) {
	if r.db == nil {
		return nil, sql.ErrConnDone
	}
	rows, err := r.db.Query(`
		SELECT DISTINCT user_id
		FROM subscription
		WHERE status = 'active'
		  AND (expire_at IS NULL OR expire_at > NOW())
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var results []int64
	for rows.Next() {
		var userID int64
		if err := rows.Scan(&userID); err != nil {
			return nil, err
		}
		results = append(results, userID)
	}
	return results, rows.Err()
}

func (r *SubscriptionRepository) Upsert(
	userID int64,
	platform string,
	sku string,
	status string,
	expireAt *time.Time,
	transactionID string,
	originalTransactionID string,
) error {
	if r.db == nil {
		return sql.ErrConnDone
	}
	if transactionID == "" {
		transactionID = originalTransactionID
	}
	if transactionID == "" {
		// fallback to sku to avoid conflicts, still keeps last status
		transactionID = fmt.Sprintf("%s-%d", sku, userID)
	}
	_, err := r.db.Exec(
		`INSERT INTO subscription (
			user_id, platform, sku, status, expire_at, transaction_id, original_transaction_id, updated_at
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
		ON CONFLICT (user_id, transaction_id)
		DO UPDATE SET
			sku = EXCLUDED.sku,
			status = EXCLUDED.status,
			expire_at = EXCLUDED.expire_at,
			original_transaction_id = COALESCE(EXCLUDED.original_transaction_id, subscription.original_transaction_id),
			updated_at = NOW()`,
		userID,
		platform,
		sku,
		status,
		expireAt,
		transactionID,
		originalTransactionID,
	)
	return err
}

func (r *SubscriptionRepository) IsUserActive(userID int64) (bool, error) {
	if r.db == nil {
		return false, sql.ErrConnDone
	}
	var exists int
	err := r.db.QueryRow(
		`SELECT 1
		 FROM subscription
		 WHERE user_id = $1
		   AND status = 'active'
		   AND (expire_at IS NULL OR expire_at > NOW())
		 LIMIT 1`,
		userID,
	).Scan(&exists)
	if err == sql.ErrNoRows {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	return true, nil
}

func (r *SubscriptionRepository) LatestByUser(userID int64) (*SubscriptionRecord, error) {
	if r.db == nil {
		return nil, sql.ErrConnDone
	}
	row := r.db.QueryRow(`
		SELECT sku, status, expire_at, updated_at
		FROM subscription
		WHERE user_id = $1
		ORDER BY updated_at DESC
		LIMIT 1
	`, userID)
	var sku, status string
	var expire sql.NullTime
	var updated time.Time
	if err := row.Scan(&sku, &status, &expire, &updated); err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	var expirePtr *time.Time
	if expire.Valid {
		expirePtr = &expire.Time
	}
	return &SubscriptionRecord{
		SKU:       sku,
		Status:    status,
		ExpireAt:  expirePtr,
		UpdatedAt: updated,
	}, nil
}
