package config

import (
	"fmt"
	"os"
	"path/filepath"
	"sync"

	"gopkg.in/yaml.v3"
)

type Config struct {
	Server   ServerConfig   `yaml:"server"`
	Database DatabaseConfig `yaml:"database"`
	JWT      JWTConfig      `yaml:"jwt"`
	Apple    AppleConfig    `yaml:"apple"`
	Qwen     QwenConfig     `yaml:"qwen"`
	OSS      OSSConfig      `yaml:"oss"`
	Prompts  PromptConfig   `yaml:"prompts"`
}

type ServerConfig struct {
	Port string `yaml:"port"`
}

type DatabaseConfig struct {
	Host     string `yaml:"host"`
	Port     string `yaml:"port"`
	User     string `yaml:"user"`
	Password string `yaml:"password"`
	DBName   string `yaml:"dbname"`
	SSLMode  string `yaml:"sslmode"`
}

type JWTConfig struct {
	Secret      string `yaml:"secret"`
	ExpireHours int    `yaml:"expire_hours"`
}

type AppleConfig struct {
	ClientID       string `yaml:"client_id"`
	SharedSecret   string `yaml:"shared_secret"`
	IssuerID       string `yaml:"issuer_id"`
	KeyID          string `yaml:"key_id"`
	BundleID       string `yaml:"bundle_id"`
	PrivateKeyPath string `yaml:"private_key_path"`
}

type QwenConfig struct {
	APIKey  string `yaml:"api_key"`
	BaseURL string `yaml:"base_url"`
	Model   string `yaml:"model"`
}

type OSSConfig struct {
	Endpoint        string `yaml:"endpoint"`
	Bucket          string `yaml:"bucket"`
	Region          string `yaml:"region"`
	AccessKeyID     string `yaml:"access_key_id"`
	AccessKeySecret string `yaml:"access_key_secret"`
	RoleArn         string `yaml:"role_arn"`
	StsDuration     int    `yaml:"sts_duration"`
	StsEndpoint     string `yaml:"sts_endpoint"`
}

type PromptConfig struct {
	MenuScanPath        string `yaml:"menu_scan_path"`
	FoodScanPath        string `yaml:"food_scan_path"`
	IngredientScanPath  string `yaml:"ingredient_scan_path"`
	DiscoverPlanPath    string `yaml:"discover_plan_path"`
	DiscoverReplacePath string `yaml:"discover_replace_path"`
	ChatPromptPath      string `yaml:"chat_prompt_path"`
}

var (
	loadedConfig *Config
	loadErr      error
	loadOnce     sync.Once
)

func Load() (*Config, error) {
	loadOnce.Do(func() {
		path, err := resolveConfigPath()
		if err != nil {
			loadErr = err
			return
		}
		data, err := os.ReadFile(path)
		if err != nil {
			loadErr = err
			return
		}
		var cfg Config
		if err := yaml.Unmarshal(data, &cfg); err != nil {
			loadErr = err
			return
		}
		applyDefaults(&cfg)
		loadedConfig = &cfg
	})
	return loadedConfig, loadErr
}

func (c *DatabaseConfig) DSN() string {
	return fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		c.Host, c.Port, c.User, c.Password, c.DBName, c.SSLMode)
}

func resolveConfigPath() (string, error) {
	paths := []string{
		"config.yaml",
		filepath.Join("eatclean", "config.yaml"),
	}
	for _, p := range paths {
		if _, err := os.Stat(p); err == nil {
			return p, nil
		}
	}
	return "", fmt.Errorf("config.yaml not found (searched: %v)", paths)
}

func applyDefaults(cfg *Config) {
	if cfg.Server.Port == "" {
		cfg.Server.Port = "8080"
	}
	if cfg.Database.Host == "" {
		cfg.Database.Host = "localhost"
	}
	if cfg.Database.Port == "" {
		cfg.Database.Port = "5432"
	}
	if cfg.Database.User == "" {
		cfg.Database.User = "postgres"
	}
	if cfg.Database.DBName == "" {
		cfg.Database.DBName = "eatclean"
	}
	if cfg.Database.SSLMode == "" {
		cfg.Database.SSLMode = "disable"
	}
	if cfg.JWT.Secret == "" {
		cfg.JWT.Secret = "default-secret-key"
	}
	if cfg.JWT.ExpireHours == 0 {
		cfg.JWT.ExpireHours = 720
	}
	if cfg.Apple.IssuerID == "" {
		cfg.Apple.IssuerID = "4bb68e2f-dd6a-4842-adcb-0bbe691d32a9"
	}
	if cfg.Apple.KeyID == "" {
		cfg.Apple.KeyID = "979F55DL33"
	}
	if cfg.Apple.BundleID == "" {
		cfg.Apple.BundleID = "com.midoriya.eatclean"
	}
	if cfg.Apple.PrivateKeyPath == "" {
		cfg.Apple.PrivateKeyPath = "p8/AuthKey_979F55DL33.p8"
	}
	if cfg.Qwen.BaseURL == "" {
		cfg.Qwen.BaseURL = "https://dashscope.aliyuncs.com/compatible-mode/v1"
	}
	if cfg.Qwen.Model == "" {
		cfg.Qwen.Model = "qwen-vl-plus"
	}
	if cfg.OSS.Region == "" {
		cfg.OSS.Region = "cn-beijing"
	}
	if cfg.OSS.StsDuration == 0 {
		cfg.OSS.StsDuration = 3600
	}
	if cfg.OSS.StsEndpoint == "" {
		cfg.OSS.StsEndpoint = "https://sts.aliyuncs.com"
	}
	if cfg.Prompts.MenuScanPath == "" {
		cfg.Prompts.MenuScanPath = "prompt/menu_scan.txt"
	}
	if cfg.Prompts.FoodScanPath == "" {
		cfg.Prompts.FoodScanPath = "prompt/food_scan.txt"
	}
	if cfg.Prompts.IngredientScanPath == "" {
		cfg.Prompts.IngredientScanPath = "prompt/ingredient_scan.txt"
	}
	if cfg.Prompts.DiscoverPlanPath == "" {
		cfg.Prompts.DiscoverPlanPath = "prompt/discover_plan.txt"
	}
	if cfg.Prompts.DiscoverReplacePath == "" {
		cfg.Prompts.DiscoverReplacePath = "prompt/discover_replace.txt"
	}
	if cfg.Prompts.ChatPromptPath == "" {
		cfg.Prompts.ChatPromptPath = "prompt/chat_prompt.txt"
	}
}
