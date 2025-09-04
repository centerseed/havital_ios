# Strava 数据源集成计划

## 项目概述
为 Havital iOS 应用的 UserProfileView 添加 Strava 作为第三个数据源选项，允许用户连接和同步 Strava 账户数据。

## 架构研究结果

### 现有数据源架构
- **DataSourceType 枚举**: `.unbound`, `.appleHealth`, `.garmin`
- **管理器模式**: `GarminManager` 处理 OAuth 和状态管理
- **UI 组件**: UserProfileView 中的 `dataSourceSection` 和 `dataSourceRow`
- **后端服务**: 统一的服务层架构用于 API 通信

### Strava API 要求
- **认证方式**: 标准 OAuth 2.0（使用 client_secret，**不需要 PKCE**）
- **令牌管理**: 访问令牌 6 小时过期，需要刷新令牌
- **速率限制**: 每 15 分钟 200 请求，每日 2000 请求
- **所需范围**: `read`, `activity:read`, `profile:read`

## 实施计划

### ✅ 阶段 1: 研究和规划
- [x] 研究现有应用架构和 Strava 后端实现
- [x] 检查 UserProfileView 结构和数据源模式
- [x] 审查 Strava API 文档集成要求
- [x] 设计 Strava 集成 UI 组件

### 🔄 阶段 2: 核心实现
- [ ] **更新 DataSourceType 枚举** (UserPreferenceManager.swift)
  - 添加 `.strava` case
  - 为 Strava 添加 `displayName` 支持
  - 添加本地化字符串

- [ ] **创建 StravaManager 类**
  - 仿照 `GarminManager` 模式
  - 实现标准 OAuth 2.0 流程（无 PKCE）
  - 管理连接状态和令牌
  - 处理连接/断开连接
  - 实现错误处理和重连逻辑

- [ ] **后端服务集成**
  - 创建 `StravaConnectionService`
  - 创建 `StravaDisconnectService`
  - 实现连接状态检查 API
  - 遵循现有的统一架构模式

### 🔄 阶段 3: UI 集成
- [ ] **更新 UserProfileView**
  - 在 `dataSourceSection` 中添加 Strava 选项
  - 实现 Strava 的 `dataSourceRow`
  - 添加 Strava 图标和品牌元素
  - 实现连接确认对话框

- [ ] **本地化支持**
  - 添加 Strava 相关的本地化字符串
  - 更新 LocalizationKeys.swift

### 🔄 阶段 4: 配置和安全
- [ ] **API 配置**
  - 在 APIKeys.plist 添加 Strava Client ID/Secret
  - 配置开发和生产环境重定向 URI
  - 实现安全的令牌存储

- [ ] **深度链接处理**
  - 在 AppDelegate/SceneDelegate 中添加 Strava 回调处理
  - 实现 URL scheme 支持

### 🔄 阶段 5: 测试和验证
- [ ] **功能测试**
  - 验证 OAuth 流程完整性
  - 测试连接状态管理
  - 验证断开连接功能
  - 测试错误处理场景

- [ ] **集成测试**
  - 确保与现有数据源的兼容性
  - 测试数据源切换流程
  - 验证 UI 状态同步

## 技术实现细节

### OAuth 2.0 流程（标准模式，无 PKCE）
1. 用户点击连接 Strava
2. 重定向到 Strava 授权页面
3. 用户授权后返回应用
4. 使用 authorization code + client_secret 交换令牌
5. 存储 access_token 和 refresh_token

### 关键组件

#### StravaManager
```swift
class StravaManager: NSObject, ObservableObject {
    @Published var isConnecting = false
    @Published var connectionError: String?
    @Published var isConnected = false
    @Published var needsReconnection = false
    
    func startConnection() async
    func disconnect() async
    func checkConnectionStatus() async
}
```

#### DataSourceType 扩展
```swift
enum DataSourceType: String, CaseIterable {
    case unbound = "unbound"
    case appleHealth = "apple_health"
    case garmin = "garmin"
    case strava = "strava"  // 新增
}
```

### UI 组件更新
- 添加 Strava 橙色品牌色彩
- 使用 Strava 官方 logo
- 保持与现有数据源一致的 UX 模式

## 依赖关系
- 需要后端 API 支持 Strava OAuth 流程
- 需要 Strava 开发者账户和应用注册
- 需要配置适当的重定向 URI

## 风险和注意事项
- Strava API 速率限制需要适当处理
- 令牌过期管理需要可靠的刷新机制
- 需要处理用户取消授权的情况
- 确保遵循 Strava API 使用条款

## 成功标准
- [ ] 用户可以成功连接 Strava 账户
- [ ] 数据源状态正确显示和同步
- [ ] 连接错误得到适当处理和显示
- [ ] 与现有数据源功能完全兼容
- [ ] 所有 UI 状态正确更新

## 后续阶段
- 实现 Strava 数据同步（活动、个人资料）
- 添加 Strava 特定的数据展示
- 实现 webhook 支持以获取实时数据更新

---

**创建日期**: 2025-09-03  
**状态**: 规划阶段  
**负责人**: Claude Code  
**预计完成时间**: TBD