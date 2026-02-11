一、基础设置（可选但推荐）
-- 使用 UTF8
SET client_encoding = 'UTF8';

-- 统一时区（推荐 UTC）
SET TIME ZONE 'UTC';

二、用户表
CREATE TABLE app_user (
  id              BIGSERIAL PRIMARY KEY,
  platform        VARCHAR(20) NOT NULL,       -- ios / android / account
  apple_user_id   VARCHAR(128),
  wechat_openid   VARCHAR(128),
  unionid         VARCHAR(128),
  created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
  last_login_at   TIMESTAMP
);

CREATE UNIQUE INDEX idx_user_apple
ON app_user(apple_user_id)
WHERE apple_user_id IS NOT NULL;

CREATE UNIQUE INDEX idx_user_wechat
ON app_user(wechat_openid)
WHERE wechat_openid IS NOT NULL;

-- 用户账号密码（账号登录）
CREATE TABLE user_account (
  user_id        BIGINT PRIMARY KEY REFERENCES app_user(id) ON DELETE CASCADE,
  account        VARCHAR(128) NOT NULL,
  password_hash  VARCHAR(255) NOT NULL,
  created_at     TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_user_account_account
ON user_account(account);

三、用户饮食 & 健身人格
CREATE TABLE user_profile (
  user_id            BIGINT PRIMARY KEY REFERENCES app_user(id) ON DELETE CASCADE,
  goal_type          VARCHAR(20),          -- fat_loss / muscle_gain / maintain
  calorie_budget     INT,
  protein_target     INT,                  -- g/day
  carb_target        INT,
  fat_target         INT,
  training_days      INT,
  eating_style       VARCHAR(30),          -- 外卖党 / 自炊 / 混合
  avoid_foods        TEXT[],
  ai_personality     JSONB,
  updated_at         TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_profile_ai_personality
ON user_profile USING GIN (ai_personality);

-- 用户设置（前端配置 JSON）
CREATE TABLE user_settings (
  user_id     BIGINT PRIMARY KEY REFERENCES app_user(id) ON DELETE CASCADE,
  settings    JSONB NOT NULL,
  updated_at  TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_user_settings_json ON user_settings USING GIN(settings);

四、菜品表
CREATE TABLE dish (
  id                 BIGSERIAL PRIMARY KEY,
  name               TEXT NOT NULL,
  normalized_name    TEXT NOT NULL,
  category           VARCHAR(50),
  nutrition_estimate JSONB,
  image_urls         TEXT[],
  created_at         TIMESTAMP DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_dish_normalized
ON dish(normalized_name);

五、菜单扫描记录
CREATE TABLE menu_scan (
  id              BIGSERIAL PRIMARY KEY,
  user_id         BIGINT REFERENCES app_user(id) ON DELETE SET NULL,
  raw_image_url   TEXT,
  raw_image_urls  JSONB,
  ocr_text        TEXT,
  parsed_menu     JSONB,
  restaurant_hint TEXT,
  created_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_menu_scan_user_time
ON menu_scan(user_id, created_at DESC);

CREATE INDEX idx_menu_scan_images
ON menu_scan USING GIN(raw_image_urls);

六、AI 决策结果
CREATE TABLE ai_decision (
  id              BIGSERIAL PRIMARY KEY,
  user_id         BIGINT REFERENCES app_user(id) ON DELETE CASCADE,
  dish_id         BIGINT REFERENCES dish(id) ON DELETE SET NULL,
  scan_id         BIGINT REFERENCES menu_scan(id) ON DELETE SET NULL,
  decision        VARCHAR(20),      -- ok / limit / avoid
  score           INT CHECK (score BETWEEN 0 AND 100),
  reason          TEXT,
  ai_raw_output   JSONB,
  created_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_ai_decision_user_time
ON ai_decision(user_id, created_at DESC);

七、用户真实饮食记录（强烈推荐）
CREATE TABLE eat_log (
  id          BIGSERIAL PRIMARY KEY,
  user_id     BIGINT REFERENCES app_user(id) ON DELETE CASCADE,
  dish_id     BIGINT REFERENCES dish(id) ON DELETE SET NULL,
  eat_time    TIMESTAMP,
  portion     FLOAT CHECK (portion > 0),
  created_at  TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_eat_log_user_time
ON eat_log(user_id, eat_time DESC);

八、用户就餐记录（前端同步）
CREATE TABLE meal_record (
  id          BIGSERIAL PRIMARY KEY,
  user_id     BIGINT REFERENCES app_user(id) ON DELETE CASCADE,
  source      VARCHAR(20) NOT NULL,          -- menu / food / manual
  items       JSONB NOT NULL DEFAULT '[]',   -- 用餐菜品列表
  image_urls  JSONB,                         -- 上传图片 URL
  ratings     JSONB,                         -- 可选评分
  meta        JSONB,                         -- 扫描文本、图片数量等扩展信息
  recorded_at TIMESTAMP NOT NULL DEFAULT NOW(),
  created_at  TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_meal_record_user_time
ON meal_record(user_id, recorded_at DESC);

CREATE INDEX idx_meal_record_items
ON meal_record USING GIN (items);

CREATE INDEX idx_meal_record_meta
ON meal_record USING GIN (meta);

CREATE INDEX idx_meal_record_images
ON meal_record USING GIN (image_urls);

九、聊天记录（可用于缓存）
CREATE TABLE chat_message (
  id          BIGSERIAL PRIMARY KEY,
  user_id     BIGINT REFERENCES app_user(id) ON DELETE CASCADE,
  role        VARCHAR(20) NOT NULL,          -- user / assistant
  text        TEXT,
  image_urls  JSONB,
  created_at  TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_chat_message_user_time
ON chat_message(user_id, created_at DESC);

十、订阅与内购记录
CREATE TABLE subscription (
  id              BIGSERIAL PRIMARY KEY,
  user_id         BIGINT REFERENCES app_user(id) ON DELETE CASCADE,
  platform        VARCHAR(20),     -- ios / android
  sku             VARCHAR(50),
  status          VARCHAR(20),     -- active / expired / canceled
  expire_at       TIMESTAMP,
  created_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_subscription_user
ON subscription(user_id);

十一、每日摄入能量
CREATE TABLE daily_intake (
  user_id    BIGINT REFERENCES app_user(id) ON DELETE CASCADE,
  day        DATE NOT NULL,
  calories   INT NOT NULL DEFAULT 0,
  protein    INT NOT NULL DEFAULT 0,
  carbs      INT NOT NULL DEFAULT 0,
  fat        INT NOT NULL DEFAULT 0,
  updated_at TIMESTAMP DEFAULT NOW(),
  PRIMARY KEY (user_id, day)
);

CREATE INDEX idx_daily_intake_user_day
ON daily_intake(user_id, day);

十二、-- 用户饮食人格表
CREATE TABLE user_food_personality (
    user_id        BIGINT PRIMARY KEY REFERENCES app_user(id) ON DELETE CASCADE,
    personality    JSONB NOT NULL,           -- 存储各维度的值
    confidence     FLOAT DEFAULT 0.0,       -- 数据可信度，0.0~1.0
    last_updated   TIMESTAMP DEFAULT NOW()  -- 最后一次更新时间
);

-- 索引：加速根据 JSON 查询
CREATE INDEX idx_user_personality_json ON user_food_personality USING GIN(personality);

-- 示例 JSONB 数据结构
-- {
--   "strictness": 0.62,
--   "ai_obedience": 0.58,
--   "fat_tolerance": "medium",
--   "carb_sensitivity": "high",
--   "late_eating": "often",
--   "protein_priority": true,
--   "cheat_acceptance": "medium",
--   "training_bias": true
-- }

十三、每周菜单（发现页）
CREATE TABLE weekly_menu (
  id              BIGSERIAL PRIMARY KEY,
  user_id         BIGINT REFERENCES app_user(id) ON DELETE CASCADE,
  week_start      DATE NOT NULL,              -- 周一日期
  weekday         SMALLINT NOT NULL,          -- 1-7
  plan_meals      JSONB NOT NULL DEFAULT '[]',
  recommendations JSONB NOT NULL DEFAULT '[]',
  created_at      TIMESTAMP DEFAULT NOW(),
  updated_at      TIMESTAMP DEFAULT NOW(),
  UNIQUE (user_id, week_start, weekday)
);

CREATE INDEX idx_weekly_menu_user_week
ON weekly_menu(user_id, week_start);