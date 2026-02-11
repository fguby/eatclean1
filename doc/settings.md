SettingsPage
├── 基本信息
│   ├── 身高 (height)
│   ├── 体重 (weight)
│   ├── 年龄 (age)
│   ├── 性别 (gender)
│   ├── 活动水平 (activity_level)
│   └── 训练经验 (training_experience)
├── 健身目标
│   ├── 健身目标 (goal_type)
│   ├── 每周训练天数 (weekly_training_days)
│   ├── 偏好训练时间 (preferred_training_time)
│   └── 训练类型偏好 (training_type_preference)
├── 饮食偏好与限制
│   ├── 饮食偏好 (diet_preferences)
│   ├── 不吃食物 (excluded_foods)
│   ├── 热量目标 (calorie_target)
│   ├── 宏量目标 (macro_targets)
│   ├── 放纵频率 (cheat_frequency)
│   └── 晚间进食习惯 (late_eating_habit)
├── AI 个性化设置
│   ├── AI 饮食建议风格 (ai_suggestion_style)
│   ├── 是否启用行动提示 (action_suggestion_enabled)
│   ├── 提醒频率 (reminder_frequency)
│   └── 数据使用 (data_usage_consent)
├── 通知与提醒
│   ├── 饮食提醒 (meal_reminder_enabled + meal_reminder_time)
│   ├── 训练提醒 (training_reminder_enabled + training_reminder_time)
│   ├── 水分摄入提醒 (water_reminder_enabled + water_reminder_interval)
│   └── 每日小贴士 (daily_tips_enabled)
└── 高级选项
    ├── AI 偏好调整 (ai_personality_adjustment)
    ├── AI 饮食人格重置 (reset_food_personality)
    └── 数据导出 (export_data)


每个字段的详细说明
| 字段名                       | 类型       | 说明             | 数据类型/建议值                |
| ------------------------- | -------- | -------------- | ----------------------- |
| height                    | 输入框 / 滑块 | 身高             | cm，整数                   |
| weight                    | 输入框 / 滑块 | 体重             | kg，整数                   |
| age                       | 输入框      | 年龄             | 整数                      |
| gender                    | 单选       | 性别             | 男/女                     |
| activity_level            | 下拉       | 活动水平           | 久坐 / 轻活动 / 中等活动 / 高强度活动 |
| training_experience       | 下拉       | 训练经验           | 新手 / 中级 / 高级            |
| goal_type                 | 单选       | 健身目标           | 减脂 / 增肌 / 维持            |
| weekly_training_days      | 滑块       | 每周训练天数         | 0~7                     |
| preferred_training_time   | 时间段选择    | 偏好训练时间         | 早上 / 中午 / 晚上            |
| training_type_preference  | 多选       | 偏好训练类型         | 力量训练 / 有氧 / HIIT / 体重训练 |
| diet_preferences          | 多选       | 饮食偏好           | 高蛋白 / 低碳 / 低脂 / 素食 / 偏辣 |
| excluded_foods            | 多选       | 不吃食物           | 列表，如坚果 / 海鲜 / 奶制品       |
| calorie_target            | 输入框 / 自动 | 每日热量目标         | kcal                    |
| macro_targets             | 输入框 / 自动 | 宏量目标           | 蛋白 g / 碳水 g / 脂肪 g      |
| cheat_frequency           | 滑块       | 放纵餐频率          | 0~5（次/周）                |
| late_eating_habit         | 单选       | 晚间进食习惯         | 从不 / 偶尔 / 经常            |
| ai_suggestion_style       | 单选       | AI建议风格         | 严谨 / 灵活 / 亲近 / 不近人情     |
| action_suggestion_enabled | 开关       | 是否提示用户使用功能     | true/false              |
| reminder_frequency        | 滑块       | 提醒频率           | 0~5（次/天）                |
| data_usage_consent        | 开关       | 是否允许 AI 记录用户行为 | true/false              |
| meal_reminder_enabled     | 开关       | 饮食提醒开关         | true/false              |
| meal_reminder_time        | 时间选择     | 饮食提醒时间         | 08:00/12:00/19:00等      |
| training_reminder_enabled | 开关       | 训练提醒开关         | true/false              |
| training_reminder_time    | 时间选择     | 训练提醒时间         | 用户自定义                   |
| water_reminder_enabled    | 开关       | 喝水提醒开关         | true/false              |
| water_reminder_interval   | 滑块       | 喝水提醒间隔         | 30~120分钟                |
| daily_tips_enabled        | 开关       | 每日小贴士推送        | true/false              |
| ai_personality_adjustment | 滑块       | AI推荐严格度        | 0~100                   |
| reset_food_personality    | 按钮       | 重置用户饮食人格       | 点击触发                    |
| export_data               | 按钮       | 导出用户数据         | CSV或JSON                |
