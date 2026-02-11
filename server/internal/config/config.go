package config

import (
	"fmt"
	"os"
	"strconv"
)

type Config struct {
	Server   ServerConfig
	Database DatabaseConfig
	JWT      JWTConfig
	Apple    AppleConfig
	Qwen     QwenConfig
	OSS      OSSConfig
}

type ServerConfig struct {
	Port string
}

type DatabaseConfig struct {
	Host     string
	Port     string
	User     string
	Password string
	DBName   string
	SSLMode  string
}

type JWTConfig struct {
	Secret      string
	ExpireHours int
}

type AppleConfig struct {
	ClientID       string
	SharedSecret   string
	IssuerID       string
	KeyID          string
	BundleID       string
	PrivateKeyPath string
}

type QwenConfig struct {
	APIKey  string
	BaseURL string
	Model   string
}

type OSSConfig struct {
	Endpoint        string
	Bucket          string
	Region          string
	AccessKeyID     string
	AccessKeySecret string
	RoleArn         string
	StsDuration     int
	StsEndpoint     string
}

func Load() (*Config, error) {
	expireHours, err := strconv.Atoi(getEnv("JWT_EXPIRE_HOURS", "720"))
	if err != nil {
		expireHours = 720
	}

	return &Config{
		Server: ServerConfig{
			Port: getEnv("SERVER_PORT", "8080"),
		},
		Database: DatabaseConfig{
			Host:     getEnv("DB_HOST", "localhost"),
			Port:     getEnv("DB_PORT", "5432"),
			User:     getEnv("DB_USER", "postgres"),
			Password: getEnv("DB_PASSWORD", ""),
			DBName:   getEnv("DB_NAME", "eatclean"),
			SSLMode:  getEnv("DB_SSLMODE", "disable"),
		},
		JWT: JWTConfig{
			Secret:      getEnv("JWT_SECRET", "default-secret-key"),
			ExpireHours: expireHours,
		},
		Apple: AppleConfig{
			ClientID:       getEnv("APPLE_CLIENT_ID", ""),
			SharedSecret:   getEnv("APPLE_SHARED_SECRET", ""),
			IssuerID:       getEnv("APPLE_ISSUER_ID", "4bb68e2f-dd6a-4842-adcb-0bbe691d32a9"),
			KeyID:          getEnv("APPLE_KEY_ID", "979F55DL33"),
			BundleID:       getEnv("APPLE_BUNDLE_ID", "com.midoriya.eatclean"),
			PrivateKeyPath: getEnv("APPLE_PRIVATE_KEY_PATH", "p8/AuthKey_979F55DL33.p8"),
		},
		Qwen: QwenConfig{
			APIKey:  getEnv("DASHSCOPE_API_KEY", ""),
			BaseURL: getEnv("QWEN_BASE_URL", "https://dashscope.aliyuncs.com/compatible-mode/v1"),
			Model:   getEnv("QWEN_VL_MODEL", "qwen-vl-plus"),
		},
		OSS: OSSConfig{
			Endpoint:        getEnv("OSS_ENDPOINT", ""),
			Bucket:          getEnv("OSS_BUCKET", ""),
			Region:          getEnv("OSS_REGION", "cn-beijing"),
			AccessKeyID:     getEnv("OSS_ACCESS_KEY_ID", ""),
			AccessKeySecret: getEnv("OSS_ACCESS_KEY_SECRET", ""),
			RoleArn:         getEnv("OSS_ROLE_ARN", ""),
			StsDuration:     parseInt(getEnv("OSS_STS_DURATION", "3600"), 3600),
			StsEndpoint:     getEnv("OSS_STS_ENDPOINT", "https://sts.aliyuncs.com"),
		},
	}, nil
}

func (c *DatabaseConfig) DSN() string {
	return fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		c.Host, c.Port, c.User, c.Password, c.DBName, c.SSLMode)
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func parseInt(value string, fallback int) int {
	parsed, err := strconv.Atoi(value)
	if err != nil {
		return fallback
	}
	return parsed
}
