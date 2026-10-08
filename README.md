# 拖拽提醒（DragReminder）— 猫吃鱼版 🐱🐟

一款类似 Gestimer 的 macOS 菜单栏提醒应用，核心交互：**从菜单栏的猫图标往下"钓鱼"来创建提醒**。

> 按住猫图标向下拖拽 → 拉出一条鱼线、末端挂一条小鱼（鱼身上显示时长）→ 松手弹出窗口填写提醒内容 → 确认后开始倒计时，到点弹出系统通知。

当前版本：0.2.0

## 亮点功能

- 🐱 **彩色猫图标**：菜单栏常驻透明底橙色猫头（代码绘制，可自行重绘），旁边显示最近提醒的剩余倒计时
- 🎣 **猫吃鱼拖拽交互**：按住猫图标往下拖，拖得越久时间越长（1pt ≈ 10 秒，上限 6 小时）
  - 拖拽过程中实时显示**鱼线 + 鱼形时间**（时间写在小鱼身上），松手后弹出窗口填写提醒内容
  - 填写名称后才开始倒计时，不会出现"不知道这个倒计时是干嘛的"的情况
- 📋 **点击图标弹菜单**：
  - 「新建提醒…」手动创建（内容 + 分钟数）
  - 提醒列表（显示标题 + 剩余时间，子菜单可删除）
  - 退出
- 🔔 **到点系统通知**（横幅 + 声音），应用不在前台也会弹
- 💾 **提醒持久化**：重启不丢失，保存在 `~/Library/Application Support/DragReminder/reminders.json`
- 🎨 **自定义应用图标**：扁平橙色小猫（全套 16~1024px 打包为 AppIcon.icns）

## 使用

1. 打开 `DragReminder.app`
2. 首次启动会请求通知权限，请点「允许」
3. 菜单栏出现橙色猫图标：
   - **拖拽**：按下猫图标向下拖（像钓鱼一样）→ 看到鱼线和鱼形时间 → 松手 → 输入提醒内容 → 开始倒计时
   - **点击**：弹出菜单

## 构建（重新编译）

无需 Xcode，只需 Command Line Tools（自带 swiftc）：

```bash
cd DragReminder
swiftc -O -o DragReminder Sources/*.swift -framework AppKit -framework UserNotifications
cp DragReminder DragReminder.app/Contents/MacOS/
codesign --force --sign - DragReminder.app
```

生成图标（可选，透明底猫头 / 扁平猫应用图标）：

```bash
cd scripts
swiftc -O -o draw_cat_icon_clear draw_cat_icon_clear.swift -framework AppKit
./draw_cat_icon_clear assets/cat_icon_menu_1024.png   # 菜单栏透明猫头
sips -s format png -z 44 44 assets/cat_icon_menu_1024.png --out assets/cat_icon_menu.png
```

## 目录结构

```
DragReminder/
├── Sources/
│   ├── main.swift             # 入口：菜单、弹窗、通知、提醒调度
│   ├── ReminderManager.swift  # 提醒增删查、JSON 持久化、通知调度
│   ├── StatusBarView.swift    # 猫图标+倒计时、拖拽手势、鱼线窗口驱动
│   └── DragLineView.swift     # 全屏绘制鱼线 + 鱼形时间（猫吃鱼）
├── scripts/
│   ├── draw_cat_icon.swift        # 扁平橙色猫应用图标（1024px）
│   ├── draw_cat_icon_clear.swift  # 透明底猫头（菜单栏彩色图标）
│   └── assets/                    # 生成的图标资源
├── APPSTORE.md                # App Store 上架路线图
├── PRIVACY.md                 # 隐私政策
└── README.md
```

## 售卖计划

- **App Store 全球上架**（目标）：美国区 $4.99，中国区 ¥20（App Store Connect 自定义地区价格）
- 当前为 ad-hoc 签名本地版本；上架需要 Apple Developer Program（$99/年）+ App Sandbox 改造 + Xcode/Transporter 上传
- 详见 [APPSTORE.md](APPSTORE.md)

## 当前限制 / 待办

- [x] 自定义应用图标（扁平猫 + 透明猫头）
- [x] 拖拽弹窗填写提醒名称后再倒计时
- [x] 鱼线 + 鱼形时间（猫吃鱼）
- [ ] 开机自启动设置
- [ ] 提醒到期后编辑 / 贪睡
- [ ] App Sandbox 改造（上架必需）
- [ ] Developer ID / App Store 签名 + 公证

## License

**MIT + Commons Clause**（受限开源许可证），见 [LICENSE](LICENSE)。

- ✅ 可自由学习、修改、个人/内部使用，二开后提供服务（SaaS/咨询）不受限
- ❌ **禁止将本软件（或其功能）作为商业产品直接售卖获利**（Sell，详见 Commons Clause）
- 对外分发须保留完整版权与许可声明
- 作者（Licensor）保留在 App Store 等渠道上架售卖的权利；他人如需商业售卖授权，请联系作者
