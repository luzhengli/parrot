# Parrot 进度交接

## 当前状态

- 日期：2026-06-22
- 项目形态：macOS SwiftUI App scaffold
- Xcode 工程：`Parrot.xcodeproj`
- Scheme：`Parrot`
- 产品依据：`Docs/ai-translation-macos-prd.md`
- 初始化入口：`./init.sh`
- 最新验证：`./init.sh` 已成功完成工程元数据检查和 Debug 构建；设置菜单可打开 LLM Provider 设置窗口；`Cmd+Shift+T` 可打开 Quick Text Translation 小窗并完成流式翻译。本地 OCR 已通过等效 smoke test 识别临时生成的两行文字图片。截图 OCR 结果窗口已升级为原文/译文对照窗口，并已由用户本地验证真实截图选择、Provider 流式响应、复制、重试和 Esc 关闭；`p0.comparison-result-window` 已标记通过。中英自动互译已由共享翻译实现确认通过；`p0.zh-en-auto-translation` 已标记通过。权限、OCR、认证、网络和超时错误已补齐可操作用户提示，并通过 Debug 构建、CGEvent 窗口 smoke 与等效集成/E2E 检查；`p0.user-facing-errors` 已标记通过。日常调试启动使用 `./init.sh --run`，固定从 `./.DerivedData` 构建产物启动。
- 设计参考：`Design/` 已保存 4 张产品高保真原型图，并通过 `Design/README.md` 建立索引。

## 启动就绪清单

- [x] 能启动：`./init.sh --run` 可停止旧实例、构建并打开固定 Debug App；`./init.sh --open` 可打开 Xcode 工程。
- [x] 能验证：`./init.sh` 会列出工程元数据并在 `./.DerivedData` 执行 Debug 构建。
- [x] 能看进度：本文件记录当前状态、已完成事项、已知问题和下一步。
- [x] 能接手下一步：`feature_list.json` 记录功能清单、验收标准和通过状态。

## 已完成

- 初始化 Xcode 项目结构：`Parrot.xcodeproj`、`Parrot/App`、`Parrot/Resources`、`Config`。
- 添加产品 PRD：`Docs/ai-translation-macos-prd.md`。
- 添加 Agent 初始化文件：
  - `init.sh`：新会话启动、工程检查、Debug 构建。
  - `parrot-progress.md`：进度交接日志。
  - `feature_list.json`：结构化功能验收清单。
- 添加产品高保真原型图：
  - `Design/quick-text-translation-panel.png`
  - `Design/screenshot-translation-result-card.png`
  - `Design/settings-window.png`
  - `Design/menu-bar-dropdown.png`
  - `Design/README.md`
- 添加原生菜单栏常驻入口：
  - `Parrot/App/AppDelegate.swift` 管理 `NSStatusItem`。
  - 菜单包含快捷文本翻译、截图翻译、设置和退出。
  - 快捷文本翻译、截图翻译和设置目前打开占位窗口，完整功能后续实现。
- 添加全局快捷键实现：
  - `Cmd+Shift+T` 触发快捷文本翻译入口。
  - `Cmd+Shift+2` 触发截图翻译入口。
  - 菜单栏支持暂停/启用快捷键，并在注册失败时显示不可用状态。
  - Debug 构建已通过，并已通过自动化 GUI 烟测；`p0.global-shortcuts` 已标记通过。
- 添加截图框选基础能力：
  - `Cmd+Shift+2` 或菜单截图入口会进入全屏框选模式。
  - 拖拽选区后截取屏幕区域，并交给 OCR 管线处理。
  - `Esc` 可取消框选，不生成截图结果窗口。
  - Debug 构建已通过，并已通过自动化 GUI 烟测；`p0.screenshot-selection` 已标记通过。
- 添加本地 OCR 基础能力：
  - 截图选区图片通过 Vision `VNRecognizeTextRequest` 在本机识别文字。
  - 截图图片默认不上传；结果窗口只展示本地识别出的文字。
  - 未识别到文字时展示清晰提示，识别结果按 Vision observation 使用换行保留基础段落/行结构。
  - Debug 构建和本地生成图片 OCR smoke test 均已通过；`p0.local-ocr` 已标记通过。
- 添加 LLM Provider 设置基础能力：
  - 设置窗口支持厂商预设、OpenAI-compatible Base URL、模型名和 API Key。
  - 默认推荐 DeepSeek V4 Flash；预设包含 DeepSeek、GLM、OpenAI 和 Custom。
  - Base URL/模型名/厂商选择保存到 UserDefaults；API Key 按厂商隔离保存、替换、删除于 macOS Keychain。
  - 设置页提供连接测试入口，调用 OpenAI-compatible `/chat/completions` 并展示认证、网络、超时等简短错误。
  - Debug 构建已通过；用户本地使用 DeepSeek 预设和已保存 Keychain API Key 验证连接测试成功，`p0.llm-provider-settings` 已标记通过。
- 确认中英自动互译基础能力：
  - 共享翻译实现会自动判断目标语言：包含中文时翻译为英文，否则翻译为简体中文。
  - 翻译 prompt 要求保留段落、代码、变量名、链接、产品名和专有名词，且只输出译文。
  - Quick Text Translation 和截图翻译对照窗口均复用同一条流式翻译路径；`p0.zh-en-auto-translation` 已标记通过。
- 补齐用户可见错误闭环：
  - 截图权限错误显示专用错误窗口，提供 `Open Screen Recording Settings`、`Retry` 和 `Close`。
  - OCR 无文本/不可用/失败会保留在截图结果窗口，并提供 `New Screenshot` 重新框选入口。
  - Provider 错误统一转成标题、说明和恢复建议；认证错误和服务商错误会清洗换行、截断并脱敏 token-like 内容。
  - Quick Text Translation 失败后新增显式 `Retry` 按钮，截图翻译保留已有 `Retry` 按钮用于网络、超时和 Provider 失败。
  - 已运行 `./init.sh`、`git diff --check`、`feature_list.json` JSON 校验、`Cmd+Shift+T` CGEvent 窗口 smoke，以及从应用源码编译的等效集成/E2E 检查；`p0.user-facing-errors` 已标记通过。

## 当前未实现

- P1 翻译历史和自定义快捷键。

## 已知约束

- MVP 仅面向 macOS。
- 默认使用本地 OCR，仅将识别后的文本发送给 LLM。
- API Key 只能保存到 macOS Keychain，不能写入配置文件、日志、fixture 或文档。
- 命令行构建默认使用 `CODE_SIGNING_ALLOWED=NO`，因为当前未配置 `DEVELOPMENT_TEAM`。
- TCC/录屏权限调试使用 `./init.sh --run`，避免多个系统 DerivedData 副本和旧进程导致权限身份漂移或全局快捷键被占用。
- 如 `xcodebuild` 使用 Command Line Tools 而非完整 Xcode，需要运行：

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

## 建议下一步

1. 运行 `./init.sh`，确认当前 scaffold 可构建；调试运行使用 `./init.sh --run`。
2. 从 `feature_list.json` 中选择最高优先级且 `passes: false` 的 P0 功能。
3. 一次只实现一个功能，并补充必要的验证方式。
4. 验证通过后更新对应功能的 `passes`、`last_verified` 和本进度文件。
5. 保持工作区整洁，提交描述性 commit。

## 会话记录

### 2026-06-21 - 初始化 Harness 文件

- 参考飞书文档“长时间运行 Agent 的有效 Harness 设计”。
- 将文档中的通用 Web 项目 harness 思路改写为适合 macOS SwiftUI/Xcode 项目的初始化文件。
- 新增 `init.sh`、`parrot-progress.md`、`feature_list.json`。
- 已运行 `./init.sh`，确认 `Parrot` scheme 可发现且 Debug 构建通过。

### 2026-06-21 - 添加产品高保真原型图

- 新建 `Design/` 目录并保存 4 张上传的产品原型图。
- 使用语义化文件名区分快捷文本翻译小窗、截图翻译结果卡片、设置窗口、菜单栏下拉菜单。
- 新增 `Design/README.md`，记录每张原型图对应的产品界面与实现参考。
- 更新 `feature_list.json` 的 `source_documents`，并新增 `foundation.design-references` 验收项。

### 2026-06-21 - 实现菜单栏常驻入口

- 新增 `AppDelegate`，在应用启动时创建原生 `NSStatusItem`。
- 菜单项包含 `Quick Text Translation`、`Screenshot Translation`、`Settings` 和 `Quit Parrot`。
- `Quick Text Translation`、`Screenshot Translation` 和 `Settings` 会打开 SwiftUI 占位窗口，明确标注对应完整功能尚未实现。
- 已将 `AppDelegate.swift` 接入 `ParrotApp` 并注册到 Xcode target sources。
- 已更新 `feature_list.json`：`p0.menu-bar-residency` 通过，后续动作仍由对应 P0 功能继续实现。

### 2026-06-21 - 实现全局快捷键基础能力

- 新增 `GlobalShortcutManager`，使用 Carbon `RegisterEventHotKey` 注册默认快捷键。
- `Cmd+Shift+T` 会触发现有快捷文本翻译占位窗口，`Cmd+Shift+2` 会触发现有截图翻译占位窗口。
- 菜单栏新增 `Pause Shortcuts` / `Resume Shortcuts`，并在快捷键注册失败时显示 `Shortcuts Unavailable`。
- 已将 `GlobalShortcutManager.swift` 加入 Xcode target sources。
- 已运行 Debug 构建命令并通过：`xcodebuild -scheme Parrot -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`。
- 已完成自动化 GUI 烟测：Finder 前台时 `Cmd+Shift+T` 打开 `Quick Text Translation`，`Cmd+Shift+2` 打开 `Screenshot Translation`。
- 已通过 Swift Accessibility `AXPress` 验证菜单栏 `Pause Shortcuts` 会切换为 `Resume Shortcuts`，暂停后两个快捷键不再打开窗口，恢复后两个快捷键重新生效。
- 已更新 `feature_list.json`：`p0.global-shortcuts.passes = true`。

### 2026-06-21 - 实现截图框选基础能力

- 新增 `ScreenshotSelectionController`，使用原生 AppKit borderless overlay 窗口进入屏幕区域框选模式。
- 截图翻译菜单项和 `Cmd+Shift+2` 快捷键改为启动框选，而不是打开占位窗口。
- 拖拽选区后隐藏 overlay，截取选中屏幕区域，并通过 `PendingScreenshotOCRPipeline` 交给 OCR 管线占位。
- 框选完成后打开 `Screenshot Translation` 结果窗口，展示选中图片预览和 OCR 待接入状态。
- `Esc` 可取消框选，且不会生成截图结果窗口。
- 已将 `ScreenshotSelectionController.swift` 加入 Xcode target sources。
- 已运行 Debug 构建命令并通过：`xcodebuild -scheme Parrot -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`。
- 已完成自动化 GUI 烟测：`Cmd+Shift+2` 进入框选，自动拖拽区域后窗口列表出现 `Screenshot Translation` 结果窗口；再次进入框选并发送 `Esc` 后，窗口列表中 `Screenshot Translation` 数量为 0。
- 已更新 `feature_list.json`：`p0.screenshot-selection.passes = true`。

### 2026-06-21 - 修复截图框选验证问题

- 修复菜单入口混淆：将 App 配置为 `LSUIElement` / accessory 菜单栏工具，并将状态栏入口改为固定宽度 `Parrot` 文本。
- 修复截图预览错位：截图前将 AppKit 选区 rect 转换为 Quartz 截图坐标，并应用 Retina backing scale。
- 稳定命令行构建：将 `ContentView` 的宏式 `#Preview` 改为 `PreviewProvider`，避免 Xcode Preview 宏插件在命令行构建中间歇失败。
- 已运行 Debug 构建命令并通过：`xcodebuild -scheme Parrot -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`。
- 已验证生成的 Debug App 包含 `LSUIElement = true`，运行态为 accessory policy，`Cmd+Shift+2` 可进入截图框选 overlay。
- 当前会话的合成鼠标拖拽不稳定，截图预览内容对齐仍建议由用户手动确认。

### 2026-06-21 - 修复菜单入口和截图预览一致性

- 修复启动后菜单入口误导：`ParrotApp` 不再创建默认 `WindowGroup`，冷启动无主窗口；`AppDelegate` 启动时使用 `prohibited` activation policy，只保留状态栏入口，打开设置/翻译窗口或截图 overlay 时再切到 `accessory`。
- 验证状态栏菜单：通过 Accessibility 打开 status menu，确认包含 `Quick Text Translation`、`Screenshot Translation`、`Pause Shortcuts`、`Settings` 和 `Quit Parrot`；Quick Text 与 Settings 菜单项可打开对应窗口。
- 重构截图预览来源：进入框选模式前先缓存每个屏幕的截图，拖拽完成后从缓存图按选区裁剪，避免 overlay 隐藏时机、屏幕内容变化或坐标系二次转换导致预览和框选内容不一致。
- 已运行 Debug 构建命令并通过：`xcodebuild -scheme Parrot -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`。
- 已完成截图流程自动化烟测：状态栏触发 `Screenshot Translation`，合成多段拖拽后出现 `Screenshot Translation` 结果窗口，结果显示选区 origin/尺寸并将裁剪图交给 OCR placeholder。

### 2026-06-21 - 修复无屏幕录制权限时截图只包含桌面的问题

- 根因：`CGWindowListCreateImage` 在缺少 Screen Recording 权限时仍可能返回桌面/壁纸层图像，旧逻辑只判断是否返回图片，误把桌面图当作有效截图缓存。
- 修复：截图框选开始前调用 `CGPreflightScreenCaptureAccess()`，未授权时调用 `CGRequestScreenCaptureAccess()`，仍未授权则显示权限错误并停止框选。
- 已更新 `feature_list.json` 的截图框选说明，记录该权限场景仍需要用户在 System Settings 中手动复验。

### 2026-06-21 - 稳定本地调试 Harness

- 仅修改 harness，不改 Swift 业务代码。
- `init.sh` 现在固定使用仓库内 `./.DerivedData`，避免 Xcode/命令行生成多个 `~/Library/Developer/Xcode/DerivedData/Parrot-*` 副本。
- 新增 `./init.sh --run`：先停止旧 `Parrot` 进程，再构建并打开 `./.DerivedData/Build/Products/Debug/Parrot.app`，降低录屏权限和全局快捷键被旧实例干扰的概率。
- 新增 `./init.sh --stop`、`--reset-screen-capture`、`--signed`，分别用于停止旧实例、显式重置录屏权限、在配置 Team 后使用正常 Xcode 签名构建。
- `.gitignore` 已忽略 `./.DerivedData/`；`AGENTS.md` 已记录 TCC 调试必须优先使用 `./init.sh --run`。

### 2026-06-22 - 实现本地 OCR

- 将截图 OCR 占位管线替换为 `ScreenshotOCRPipeline`，使用 Vision `VNRecognizeTextRequest` 在本机识别选区图片文字。
- OCR 请求启用 accurate 识别和语言校正，识别语言包含英文、简体中文和繁体中文。
- 结果窗口展示 OCR 状态、截图预览、选区信息和可选中的识别文本；无文字时展示“未识别到可翻译文字”的可操作提示。
- 图片仍只在本地处理，当前功能不会上传截图；后续翻译功能只应消费识别出的文本。
- 已运行 `./init.sh` 并通过 Debug 构建。
- 已运行等效 OCR smoke test：临时编译当前 `ScreenshotSelectionController.swift` 和本地生成的两行文字图片，Vision 成功识别 `Hello Parrot OCR` 与 `Translate this text` 并保留换行。
- 已更新 `feature_list.json`：`p0.local-ocr.passes = true`。

### 2026-06-22 - 优化中文 OCR

- 针对中文小字号截图误识别问题，OCR 前会将小尺寸选区最多放大 4 倍，提升 Vision 对紧凑 UI 文本的输入分辨率。
- OCR 语言优先级改为简体中文、繁体中文、英文，并降低 `minimumTextHeight` 以覆盖更小字号。
- 已运行 `./init.sh` 并通过 Debug 构建。
- 已运行等效中文 OCR smoke test：临时生成深色背景、白色小字号的混排图片，Vision 成功识别 `时间线` 和 `Cue-Pro`。

### 2026-06-22 - 实现 LLM Provider 设置基础能力

- 新增 `ProviderSettingsStore`、`KeychainSecretStore` 和 `OpenAICompatibleProviderClient`。
- 新增 `ProviderSettingsView`，替换设置占位页，支持 Base URL、模型名、API Key 输入、保存、删除 Keychain API Key 和连接测试。
- 连接测试使用 OpenAI-compatible `/chat/completions`，仅发送最小测试消息，不记录或展示 API Key。
- 已将新增 Swift 文件加入 Xcode target sources，并运行 `./init.sh` 通过 Debug 构建。
- 已运行设置入口 GUI 烟测：`./init.sh --run` 启动 Debug app 后，通过状态栏 `Parrot > Settings` 打开 `Settings` 窗口。
- 已运行 `git diff --check`，并扫描仓库源文件未发现 token-like API secret。
- 当时当前环境没有真实 Provider 凭据，未完成真实连接测试验收；后续已由用户本地验证 DeepSeek 连接成功并标记通过。

### 2026-06-22 - 支持多厂商模型预设

- 参考 DeepSeek 官方文档 `https://api-docs.deepseek.com/zh-cn/`，将默认推荐设置改为 DeepSeek：Base URL `https://api.deepseek.com`，模型 `deepseek-v4-flash`。
- Provider 设置新增厂商预设：DeepSeek、GLM、OpenAI、Custom；GLM 预设使用智谱 OpenAI-compatible 端点 `https://open.bigmodel.cn/api/paas/v4` 和官方示例模型 `glm-4.7`。
- 选择厂商预设会自动填充 Base URL 与模型名；Custom 可继续手动填写任意 OpenAI-compatible 端点。
- Keychain API Key 改为按厂商账号后缀隔离，避免 DeepSeek、GLM、OpenAI 和 Custom 密钥互相覆盖。
- 已运行 `./init.sh` 并通过 Debug 构建。
- 尝试运行 `./init.sh --run` 后用 GUI 自动化打开设置窗口，但当前环境被 macOS Accessibility 权限拦截，未作为完整 UI 验收。

### 2026-06-22 - 用户本地验证 DeepSeek API 连接

- 用户本地在设置窗口选择 DeepSeek 预设，Base URL 为 `https://api.deepseek.com`，模型为 `deepseek-v4-flash`。
- API Key 已保存到 Keychain，输入框显示“Leave blank to keep saved Keychain API Key”。
- 点击 `Test Connection` 后返回成功状态：“Connection test succeeded. Provider accepted the test request.”
- 已更新 `feature_list.json`：`p0.llm-provider-settings.passes = true`，`last_verified = 2026-06-22`。
- 用户随后本地验证 API Key 替换和删除流程也正常。
- 已更新 `feature_list.json`：`p0.keychain-secrets.passes = true`，`last_verified = 2026-06-22`。

### 2026-06-22 - 实现快捷文本翻译小窗

- 新增 `QuickTextTranslationView`，用原生 `NSTextView` 包装输入区，支持呼出后自动聚焦。
- 快捷文本入口从占位页改为真实小窗：`Enter` 触发翻译，`Esc` 关闭，`Cmd+K` 清空，`Cmd+Enter` 复制译文并关闭。
- 复用已配置的 OpenAI-compatible Provider 和 Keychain API Key；翻译请求按 PRD 要求自动判断中英方向，保留段落、代码、变量名、链接、产品名和专有名词，只输出译文。
- 已将 `QuickTextTranslationView.swift` 加入 Xcode target sources，并运行 `./init.sh` 通过 Debug 构建。
- 已运行 `./init.sh --run` 启动固定 Debug App，并通过 `Cmd+Shift+T` smoke 确认 `Quick Text Translation` 窗口出现。
- 当前环境在自动输入阶段被 macOS `System Events` 权限拦截（`-10004`），因此最初未标记通过；后续已由用户本地完成端到端复验并标记通过。

### 2026-06-22 - 修复快捷文本翻译首轮结果不显示

- 根因：快捷翻译旧实现等待非流式 `/chat/completions` 完整返回后才一次性写入 `translatedText`，并且 `isTranslating` 时 UI 不渲染 `Translation` 结果区，导致首次翻译期间无法把结果显示在灰底区域。
- 修复：新增 OpenAI-compatible SSE streaming 翻译路径，逐个解析 `data:` chunk 并把 delta 追加到 `translatedText`。
- 调整 UI：翻译中也持续显示 `Translation` 区域；尚未收到首个 token 时显示等待提示，收到 token 后逐步显示译文。
- 状态提示现在只在 stream 完整结束后显示 “Translation ready. Press Cmd+Enter to copy and close.”；异常时清空部分结果并展示错误信息。
- 已运行 `./init.sh` 通过 Debug 构建；已运行 `git diff --check` 和 `feature_list.json` JSON 校验；已 grep 确认 Swift 代码中没有其他调用旧的非流式快捷翻译路径。

### 2026-06-22 - 二次修复快捷文本 Translation 区域空白

- 用户复验后同症状仍存在：首次翻译后 `Translation` 灰底区域为空，点外部后再次呼出才显示译文。
- 重新判断根因：首轮修复只解决了网络流式返回，但结果仍由动态 SwiftUI `ScrollView/Text` 渲染，且快捷窗口固定为 `520x420`，翻译完成后结果区在尺寸不足的 hosting window 中没有稳定重绘；重新呼出触发新布局后同一份 `translatedText` 才显示。
- 修复：将结果区替换为固定高度 AppKit 只读 `NSTextView`，每次 `translatedText` 变化时在 `updateNSView` 直接设置 `textView.string`，避免 SwiftUI ScrollView/Text 的首轮重绘失效。
- 修复：快捷文本翻译窗口尺寸从 `520x420` 调整为 `600x560`，确保输入区、状态、结果区和底部按钮在首轮结果展示时都有足够空间。
- 已运行 `./init.sh` 通过 Debug 构建；用户本地复验确认首轮输入后可流式显示翻译结果，完成后才显示 “Translation ready. Press Cmd+Enter to copy and close.”，且 `Cmd+Enter` 可复制译文并关闭窗口。
- 已更新 `feature_list.json`：`p0.quick-text-translation.passes = true`，`last_verified = 2026-06-22`。

### 2026-06-22 - 实现截图翻译对照结果窗口

- 将截图 OCR 结果窗口升级为原文/译文对照布局：顶部保留截图预览和本地 OCR 状态，下方左右展示 Original 与 Translation。
- OCR 成功后自动读取已配置 Provider 和 Keychain API Key，并复用 `OpenAICompatibleProviderClient.translateStreaming` 进行流式翻译；译文 token 到达后逐步追加显示。
- 译文区域采用 AppKit 只读 `NSTextView` 包装，与快捷文本翻译保持一致，避免 SwiftUI 动态文本在首轮流式输出时出现空白重绘问题。
- 新增 `Copy Translation`、`Copy Original`、`Retry`、`Esc`/`Close` 操作；失败时保留原文并展示可重试错误。
- 已运行 `./init.sh` 通过 Debug 构建，已运行 `git diff --check` 和 `feature_list.json` JSON 校验。
- 用户本地端到端复验确认截图翻译对照窗口通过：真实截图选择、Provider 流式响应、复制原文/译文、重试和 Esc 关闭均正常。
- 已更新 `feature_list.json`：`p0.comparison-result-window.passes = true`，`last_verified = 2026-06-22`。

### 2026-06-22 - 确认中英自动互译状态

- 当前共享翻译实现已按输入文本自动选择目标语言：包含中文字符时译为英文，否则译为简体中文。
- 翻译 prompt 已覆盖保留段落结构、代码、变量名、链接、产品名和专有名词，并要求只输出译文、不额外解释。
- Quick Text Translation 和截图翻译对照窗口均调用同一条 OpenAI-compatible 流式翻译路径。
- 已更新 `feature_list.json`：`p0.zh-en-auto-translation.passes = true`，`last_verified = 2026-06-22`。

### 2026-06-22 - 实现用户可见错误闭环

- 新增统一的用户错误展示映射，将 Provider 错误转成简短标题、说明和恢复建议，覆盖无效 Base URL、缺模型、缺 API Key、认证失败、网络失败、超时和非兼容响应。
- 认证错误与服务商错误会清洗换行、截断长消息，并脱敏 `sk-*` 与 `api key=` 这类 token-like 内容，避免把 API Key 暴露到 UI。
- 截图权限错误不再只展示静态文字，改为专用错误窗口，包含打开系统 Screen Recording 设置、重试和关闭操作。
- OCR 无文本/不可用/失败仍保留结果窗口，不崩溃，并提供 `New Screenshot` 重新框选入口。
- Quick Text Translation 在失败后新增显式 `Retry`，截图翻译继续保留 `Retry` 用于网络、超时和 Provider 错误。
- 已运行 `./init.sh` 并通过 Debug 构建；已运行 `git diff --check` 和 `feature_list.json` JSON 校验。
- 已运行 `./init.sh --run`，并通过 CGEvent 验证 `Cmd+Shift+T` 可打开 `Quick Text Translation` 窗口；当前环境的 `System Events` UI 文本读取被 Accessibility 权限拦截（`-10004`）。
- 已从应用源码临时编译等效集成/E2E 检查，覆盖认证错误脱敏、网络/超时 Retry 指引、无效 HTTPS Base URL 恢复建议，以及空白图片 OCR 的 no-text 失败处理，检查通过。
- 已更新 `feature_list.json`：`p0.user-facing-errors.passes = true`，`last_verified = 2026-06-22`。
