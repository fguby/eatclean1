# EatClean Backend Service

基于 Go + Echo 框架的高性能后端服务

## 技术栈

- Go 1.21+
- Echo v4 (Web 框架)
- PostgreSQL (数据库)
- JWT (身份认证)

## 项目结构

```
eatclean/
├── cmd/server/          # 应用入口
├── internal/
│   ├── config/         # 配置管理
│   ├── handler/        # HTTP 处理器
│   ├── middleware/     # 中间件
│   ├── model/          # 数据模型
│   ├── repository/     # 数据访问层
│   └── service/        # 业务逻辑层
└── pkg/response/       # 通用响应包
```

## 快速开始

### 1. 安装依赖

```bash
cd eatclean
go mod download
```

### 2. 配置环境变量

复制 `.env.example` 为 `.env` 并修改配置：

```bash
cp .env.example .env
```

编辑 `.env` 文件，设置数据库连接信息和 JWT 密钥。

### 3. 初始化数据库

使用 `DB/db.md` 中的 SQL 语句创建数据库表。

### 4. 运行服务

```bash
go run cmd/server/main.go
```

服务将在 `http://localhost:8080` 启动。

## API 接口

### 健康检查

```
GET /health
```

### 用户登录

```
POST /api/v1/auth/login
Content-Type: application/json

# iOS 登录
{
  "platform": "ios",
  "apple_identity_token": "APPLE_IDENTITY_TOKEN",
  "apple_user_id": "001234.abc123def456.1234"
}

# Android 登录
{
  "platform": "android",
  "wechat_openid": "oABC123DEF456",
  "unionid": "uABC123DEF456"
}

# 账号密码登录
{
  "platform": "account",
  "account": "user@example.com",
  "password": "your_password"
}
```

响应：
```json
{
  "code": 0,
  "message": "success",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "user": {
      "id": 1,
      "platform": "ios",
      "apple_user_id": "001234.abc123def456.1234",
      "created_at": "2026-02-05T10:00:00Z",
      "last_login_at": "2026-02-05T10:00:00Z"
    },
    "is_new_user": false
  }
}
```

### 获取用户信息（需要认证）

```
GET /api/v1/auth/profile
Authorization: Bearer <token>
```

### 菜单文本解析（需要认证）

```
POST /api/v1/menu/parse
Authorization: Bearer <token>
Content-Type: application/json

{
  "text": "红烧牛肉面 28\\n番茄鸡蛋 18\\n..."
}
```

### 用户注册

```
POST /api/v1/auth/register
Content-Type: application/json

# iOS 注册
{
  "platform": "ios",
  "apple_identity_token": "APPLE_IDENTITY_TOKEN"
}

# 账号密码注册
{
  "platform": "account",
  "account": "user@example.com",
  "password": "your_password"
}
```

响应：
```json
{
  "code": 0,
  "message": "success",
  "data": {
    "user_id": 1
  }
}
```

## 性能优化

- 使用连接池管理数据库连接
- JWT 无状态认证，减少数据库查询
- 使用索引优化数据库查询
- Echo 框架高性能路由

## 开发建议

1. 生产环境务必修改 `JWT_SECRET`
2. 根据实际需求调整 `JWT_EXPIRE_HOURS`
3. 配置适当的数据库连接池参数
4. 添加日志记录和监控
5. 实现请求限流和防护机制
6. iOS 登录需配置 `APPLE_CLIENT_ID`（通常为 App Bundle ID）
