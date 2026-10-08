# 拖拽提醒（DragReminder）— App Store 上架路线图

目标：**全球上架，美国区 $4.99，中国区 ¥20**（App Store Connect 自定义地区价格）。

---

## 0. 成本与前置条件

| 项目 | 费用 | 说明 |
|---|---|---|
| Apple Developer Program | **$99/年** | 上架 App Store 的硬性门槛，必须注册（个人或公司） |
| 苹果抽成 | 收入 15%（小开发者计划）或 30% | 年收入 ≤100 万美元可申请 15% |
| Xcode | 免费 | 本机只有 Command Line Tools，**需从 Mac App Store 安装完整 Xcode**（约 12GB），用于打包与上传；或用免费的 **Transporter** 应用上传 |

**必须由您亲自完成的步骤**（涉及付款、账号、协议，我无法代办）：
1. 注册 Apple Developer Program 并付费
2. 在 App Store Connect 创建应用、填协议/税务/银行信息
3. 用您的 Apple ID 上传构建
4. 点击"提交审核"

其余材料（元数据文案、隐私政策、定价方案、沙盒改造说明）本文件已备好。

---

## 1. 代码改造（上架前必须）

当前版本是 ad-hoc 签名、无沙盒，**App Store 强制要求**：

### 1.1 启用 App Sandbox
创建 `DragReminder.entitlements`：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <!-- 如需写 Application Support：沙盒应用写容器内路径，代码需改用 FileManager 的 Application Support 目录（沙盒容器），无需额外 entitlement -->
</dict>
</plist>
```

**代码改动点**（提醒持久化路径）：
- 沙盒下 `~/Library/Application Support/DragReminder/reminders.json` 会指向沙盒容器内路径。把路径获取改为：
  ```swift
  FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
  ```
  这样沙盒内外都能正确写入，无需硬编码 `~/Library/...`。

### 1.2 版本号与 Bundle ID
- Info.plist：`CFBundleShortVersionString` = `1.0.0`，`CFBundleVersion` = `1`
- Bundle ID `com.dragreminder.app` 需与 App Store Connect 中创建的 App 一致（或新建 Bundle ID 后在 Xcode 修改）

### 1.3 正式签名
用 Xcode 自动签名（选择 Team 后 Xcode 管理证书/描述文件），或：
```bash
# 手动：需从开发者账号申请证书
codesign --force --options runtime --sign "Developer ID Application: ..." DragReminder.app
```
> App Store 渠道签名类型是 **"Apple Distribution"**，由 Xcode 自动处理最省事。

---

## 2. App Store Connect 创建应用

1. 登录 [App Store Connect](https://appstoreconnect.apple.com) → 我的 App → 新建 App
2. 平台 macOS，名称建议：**Drag Reminder - Cat Timer**（检查是否与其他应用重名；名称一旦占用需换）
3. 填 Primary Language、Bundle ID、SKU

### 2.1 建议元数据（可直接复用）

| 字段 | 建议内容 |
|---|---|
| 名称 | Drag Reminder — 拖拽提醒 |
| 副标题 | 像钓鱼一样创建提醒 |
| 描述 | 从菜单栏的猫图标往下拖，像钓鱼一样拉出时间；松手填个名字就开始倒计时。猫吃鱼，时间看得见。支持：拖拽选时长、自定义提醒内容、到点横幅+声音通知、提醒本地保存。 |
| 关键词 | reminder, timer, menu bar, countdown, cat, 提醒, 倒计时, 菜单栏 |
| 支持 URL | GitHub 仓库地址（宣传页） |
| 营销 URL | （可选）GitHub 仓库 |
| 隐私政策 URL | GitHub 仓库中的 PRIVACY.md（或用 GitHub Pages 生成网页版） |

**截图要求（macOS）**：1280×800 或 1440×900，至少 3 张：
1. 菜单栏猫图标 + 倒计时（全景）
2. 拖拽中的鱼线 + 鱼形时间（亮点图，放第一张）
3. 创建提醒弹窗
4. 到点通知横幅
> 截图建议后续生成——需要真实拖拽画面，用录屏/截屏工具抓取。

### 2.2 隐私（App Review 必填）
- 隐私政策 URL：仓库内 PRIVACY.md（或 GitHub Pages）
- 隐私标签：**不收集任何数据**（无网络请求、无分析、无广告、无第三方 SDK）→ 在"App 隐私"页面如实选择即可

---

## 3. 定价：美国 $4.99 + 中国 ¥20

App Store 支持**按国家/地区自定义价格**（2022 年起的标准价格点 + 自定义价格功能）：

1. App Store Connect → 定价与可用性 → 管理价格
2. 选择基准价格 **Tier / $4.99**（默认全球同步）
3. 进入"按地区调整"（Customize / 自定义）：
   - 美国等全球默认保持 **$4.99**
   - **中国区改为 ¥20**（价格点选择 ¥20 或自定义 ¥20）
4. 保存后生效（下次价格更新一般几分钟内）

> 说明：App Store 价格需从价格点表中选择，¥20 为可选价格点之一；若想精确 ¥20.00，使用自定义价格功能（可用性较新，按界面引导设置）。

---

## 4. 上传与提交审核

1. **安装完整 Xcode**（App Store 免费）→ 用 Xcode 打开工程（当前是纯源码，需新建 Xcode 工程或把源码拖入），配置 Signing & Capabilities（沙盒 + 自动签名）
2. Product → Archive → Distribute App → App Store Connect
3. 或安装 **Transporter**（App Store 免费），把 `.ipa`/`.app` 导出后上传
4. App Store Connect → 该 App → TestFlight（可选内测）→ 添加版本 → 选择上传的构建 → 填写元数据 → 提交审核

### 审核注意点（macOS 菜单栏应用常见坑）

| 风险 | 应对 |
|---|---|
| 菜单栏应用"看不到主窗口"被质疑功能完整性 | 首次启动引导文案写清楚：图标在菜单栏（右上角），拖拽即可创建提醒 |
| 通知权限未合理请求 | 首次启动即请求；拒绝后菜单可引导重新开启 |
| 截图与实际界面不符 | 截图必须是真实界面 |
| 无隐私政策 / 隐私标签不符 | 如实填写"不收集数据" + 提供 PRIVACY.md 链接 |
| 应用名侵权/混淆 | 勿用 Gestimer 相关字样；自有品牌名 |
| 审核期间无法测试拖拽 | 提交时在"审核备注"写明：打开 App → 菜单栏出现猫图标 → 按住向下拖 2 秒 → 输入内容 → 到点收到通知 |

### 审核时长
- 首次提交一般 1~3 个工作日；被拒后按理由修改重新提交。

---

## 5. 时间线预估

| 步骤 | 耗时 |
|---|---|
| 注册 Developer Program | 1~2 天（付款后即时） |
| Xcode 安装 + 沙盒改造 + 打包 | 1~2 天 |
| App Store Connect 建 App + 元数据 + 截图 | 半天 |
| 上传构建 + 提交审核 | 半天 |
| 审核 | 1~3 个工作日 |
| **合计** | **约 1 周**（不含踩坑） |

---

## 6. 售卖注意事项（重要）

- **定价区间建议**：$4.99 / ¥20 在提醒类工具中属于中低价位，竞争力足够；可配合限免/打折促销
- **开源与售卖的关系**：README 采用 MIT 开源（宣传），他人可免费编译使用；若不希望被白嫖，改成闭源仓库或受限许可证（如 Commons Clause、Elastic License 2.0），App Store 版本照常售卖
- **收入分成**：小开发者计划抽 15%（需每年申请），普通 30%
- **税务**：中国开发者需在 App Store Connect 填写税务信息（中美税收协定下通常可减免预扣税率）
