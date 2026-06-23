# Parrot 进度交接

## 当前状态

- 日期：2026-06-24
- 项目形态：macOS SwiftUI App scaffold
- Xcode 工程：`Parrot.xcodeproj`
- Scheme：`Parrot`
- 产品依据：`Docs/ai-translation-macos-prd.md`；V1 翻译偏好规划见 `Docs/ai-translation-macos-v1-prd.md`
- 初始化入口：`./init.sh`
- 最新验证：`./init.sh` 已成功完成工程元数据检查和 Debug 构建；设置菜单可打开统一 Settings 窗口，当前分为 `Model`、`Shortcuts`、`Translation`、`Privacy`。`Cmd+Shift+T` 可打开 Quick Text Translation 小窗并完成流式翻译；语言选择栏已改为紧凑原生风格，并通过真实窗口截图检查。本地 OCR 已通过等效 smoke test 识别临时生成的两行文字图片。截图 OCR 结果窗口已升级为原文/译文对照窗口，并已由用户本地验证真实截图选择、Provider 流式响应、复制、重试和 Esc 关闭；`p0.comparison-result-window` 已标记通过。中英自动互译已由共享翻译实现确认通过；`p0.zh-en-auto-translation` 已标记通过。权限、OCR、认证、网络和超时错误已补齐可操作用户提示，并通过 Debug 构建、CGEvent 窗口 smoke 与等效集成/E2E 检查；首轮 Screen Recording 授权请求已修复为只显示 macOS 系统级“录屏”提示，不再叠加 Parrot 自己的 `Screenshot Capture Failed` 窗口；同一 App 会话里如果仍未授权后再次触发截图，会显示 Parrot 权限错误指引而不是静默无响应；`p0.user-facing-errors` 已标记通过。2026-06-23 修复 `./init.sh --run` Debug App 录屏授权身份漂移：Debug App 现在会在构建后 ad-hoc 签名为稳定本地 designated requirement `identifier "com.example.parrot"`，与已安装 `/Applications/Parrot.app` 对齐。Keychain API Key 体验已改为非秘密设置记录 + 进程内缓存 + 非交互钥匙串读取；首次启动缺少 API Key 设置时自动打开 Settings 引导，翻译路径不会弹系统钥匙串密码窗，缺 Key 或旧调试构建 Key 需要交互时显示 App 内错误；已通过源码链接 E2E 和真实 Debug smoke。翻译历史已实现本地文本记录、菜单栏历史窗口、复制/清空和设置开关，并通过 Debug 构建、源码链接 E2E 与真实状态栏菜单 smoke；`p1.translation-history` 已标记通过。自定义快捷键已支持录制、持久化、冲突/无效校验和保存后热更新，并通过 Debug 构建、源码链接 E2E 与真实全局快捷键 smoke；`p1.custom-shortcuts` 已标记通过。设置全局快捷键已作为第三个可配置动作接入 Shortcuts，默认 `Cmd+Option+,`，并通过源码链接 E2E 与 Finder 前台真实全局快捷键 smoke；`p1.settings-global-shortcut` 已标记通过。语言选择与一键互换已接入 Quick Text 和截图翻译结果窗口，并进入真实 Provider prompt，已通过源码链接 E2E、Debug 构建和真实 Quick Text 窗口 smoke；`p1.translation-language-controls` 已标记通过。翻译风格已接入 Translation 设置区和真实 Provider prompt，支持 Accurate、Natural、Professional、Concise，并通过源码链接 E2E、Debug 构建和真实 Settings 窗口 smoke；`p1.translation-style` 已标记通过。unsigned Release 打包流程已落地，支持 SemVer/tag 校验、GitHub 风格 `.dmg`/`.zip`/校验和/Release Notes 产物，并已通过本地 dev 打包验证；`foundation.release-packaging` 已标记通过。2026-06-23 修复 `v0.1.3-alpha` DMG 录屏授权重启后仍失效：release ad-hoc 签名现在写入稳定本地 designated requirement `identifier "com.example.parrot"` 并阻断纯 `cdhash` 产物。2026-06-23 新增 V1 翻译偏好 PRD，并在 `feature_list.json` 中拆分 custom Prompt、glossary、OCR source editing 和 floating-window position preferences，均保持 `passes: false` 等待实现验收。日常调试启动使用 `./init.sh --run`，固定从 `./.DerivedData` 构建、签名并启动同一个 Debug App bundle。
- 2026-06-24 最新补充：自定义 Prompt 已接入 Translation 设置区和共享 Provider prompt，支持默认 Prompt 展示、启用/关闭、必需变量校验、Restore Default 和无效模板回退；已通过源码链接 E2E、Debug 构建和真实 Settings 窗口 smoke；`p1.custom-translation-prompt` 已标记通过。术语表已接入 Translation 设置区和共享 Provider prompt，支持本地 JSON 持久化、增删改、启停、搜索、目标语言范围、重复校验，并且只把当前源文本命中的启用术语注入 Prompt；已通过术语表源码链接 E2E、回归 E2E、Debug 构建和真实 Settings 窗口 smoke；`p1.terminology-glossary` 已标记通过。
- 设计参考：`Design/` 已保存 5 张产品高保真原型图，并通过 `Design/README.md` 建立索引。

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
- 添加 GitHub 风格 unsigned Release 打包流程：
  - `Docs/release-process.md`：SemVer、Git tag、GitHub Release 资产、unsigned 限制和安全规则。
  - `Scripts/package-release.sh`：从 Release 配置读取版本，构建 unsigned Release，并生成 `.dmg`、`.zip`、`SHA256SUMS.txt` 和 `RELEASE_NOTES.md` 到 `Dist/`。
  - 正式模式要求干净工作区和 `v<MARKETING_VERSION>` tag；`--allow-untagged` 仅用于本地 dev 包验证。
  - 2026-06-23 修复 `v0.1.2-alpha` DMG 启动时报“Parrot.app 已损坏”：打包脚本现在会在生成 zip/DMG 前对完整 `Parrot.app` 做 ad-hoc app bundle 签名，并用 `codesign --verify --deep --strict` 阻断缺失资源封签的产物。
- 添加产品高保真原型图：
  - `Design/quick-text-translation-panel.png`
  - `Design/screenshot-translation-result-card.png`
  - `Design/settings-window.png`
  - `Design/menu-bar-dropdown.png`
  - `Design/custom-shortcuts-settings-prototype.png`
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
- 添加翻译历史：
  - `TranslationHistoryStore` 将成功的 Quick Text 和 Screenshot 翻译保存为本地文本记录，默认最多保留最近 50 条。
  - 历史记录写入 `Application Support/Parrot/translation-history.json`，只保存原文、译文、来源类型和时间，不保存截图图片或 API Key。
  - 菜单栏新增 `Translation History`，可查看近期原文/译文对照、复制译文、复制原文、清空历史，并支持 `Esc` 关闭。
  - 设置页新增 `Save translation history` 开关，关闭后不再保存新记录，已有记录保留到用户清空。
  - 已运行 `./init.sh`、源码链接 E2E `Scripts/translation-history-e2e.swift`、真实 App 状态栏菜单 smoke；`p1.translation-history` 已标记通过。
- 添加自定义快捷键：
  - 新增 `ShortcutPreferences`、`ShortcutSettingsStore` 和原生快捷键录制控件，支持 Quick Text Translation 与 Screenshot Translation 两个真实动作。
  - 默认快捷键保持 `Cmd+Shift+T` 和 `Cmd+Shift+2`；用户配置保存到 UserDefaults，不写入密钥或截图数据。
  - Settings 已轻量整理为 `Model`、`Shortcuts`、`Privacy` 三段；`Shortcuts` 支持录制、冲突/无效组合提示、恢复默认和保存。
  - `GlobalShortcutManager` 改为读取保存的快捷键注册 Carbon HotKey，保存后会重新注册，无需重启 App。
  - 已运行 `./init.sh`、源码链接 E2E `Scripts/custom-shortcuts-e2e.swift`、真实 App 自定义快捷键 smoke 和状态栏 Settings 打开 smoke；`p1.custom-shortcuts` 已标记通过。
- 添加 V1 翻译偏好规划：
  - 新增 `Docs/ai-translation-macos-v1-prd.md`，覆盖设置快捷键、语言选择与互换、翻译风格、自定义 Prompt、术语表、OCR 原文编辑和浮窗位置偏好。
  - 已更新 `feature_list.json` 的 `source_documents`，并新增 7 个未实现 feature，均保持 `passes: false` 和 `last_verified: null`。
- 实现设置全局快捷键：
  - `Open Settings` 已作为第三个可配置全局动作接入 `Shortcuts` 设置区，默认快捷键为 `Cmd+Option+,`。
  - 继续保留菜单栏 `Settings` 入口；保存快捷键后复用现有热重载逻辑，无需重启 App。
  - 旧版仅包含两个快捷键的 `ShortcutPreferences` 会保留原有自定义配置，并自动补齐 Open Settings 默认快捷键。
  - 已运行 `./init.sh`、源码链接 E2E `Scripts/custom-shortcuts-e2e.swift`、`git diff --check`、`feature_list.json` JSON 校验和真实 Debug App 全局快捷键 smoke；`p1.settings-global-shortcut` 已标记通过。
- 实现语言选择与一键互换：
  - Quick Text Translation 和 Screenshot Translation 结果窗口都显示源语言、目标语言、互换和重新翻译控制。
  - 支持 `Auto`、`Auto Opposite` 以及中文、英文、日文、韩文、法文、西班牙文显式选择；同一显式源/目标语言会禁用翻译并显示提示。
  - 语言选择持久化到 UserDefaults，不保存 API Key 或截图图片；翻译时会进入真实 Provider system prompt。
  - 已运行 `./init.sh`、源码链接 E2E `Scripts/translation-language-controls-e2e.swift`、`git diff --check` 和真实 Debug App Quick Text 窗口 smoke；`p1.translation-language-controls` 已标记通过。

## 当前未实现

- P1/P2 V1 翻译偏好功能尚未实现：OCR 原文编辑和浮窗位置偏好。

## 已知约束

- MVP 仅面向 macOS。
- 默认使用本地 OCR，仅将识别后的文本发送给 LLM。
- API Key 只能保存到 macOS Keychain，不能写入配置文件、日志、fixture 或文档。
- 命令行构建默认使用 `CODE_SIGNING_ALLOWED=NO`，因为当前未配置 `DEVELOPMENT_TEAM`。
- Release 包当前为 unsigned/unnotarized，仅适合本地或小范围内测；正式对外分发前需要稳定 bundle id、Developer ID 签名和 notarization。
- unsigned Release 包必须带稳定本地 designated requirement；如果 `codesign -dr - Parrot.app` 只显示 `cdhash H"..."`，录屏 TCC 授权会绑定到单次构建哈希，升级或重复安装后可能在系统设置里出现多个 `Parrot.app` 条目，并导致用户开启了旧条目但当前 App 仍未授权。
- TCC/录屏权限调试使用 `./init.sh --run`，避免多个系统 DerivedData 副本和旧进程导致权限身份漂移或全局快捷键被占用。验证 release 权限体验时，应从 DMG 安装到 `/Applications/Parrot.app` 后触发 `Cmd+Shift+2`，并用窗口列表确认首轮只出现系统 `universalAccessAuthWarn` 录屏提示，不出现 Parrot 的权限错误窗。
- `./init.sh --run` 会在 `CODE_SIGNING_ALLOWED=NO` 构建后对 Debug-only dylib 和 `Parrot.app` 做本地 ad-hoc 签名，并阻断 `codesign -dr - ./.DerivedData/Build/Products/Debug/Parrot.app` 退化为纯 `cdhash`。如果本机已有旧调试构建或旧 DMG 造成的重复录屏条目，先运行 `tccutil reset ScreenCapture com.example.parrot` 后重新启动当前 Debug App 并授权。
- 如 `xcodebuild` 使用 Command Line Tools 而非完整 Xcode，需要运行：

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

## 建议下一步

1. 运行 `./init.sh`，确认当前 scaffold 可构建；调试运行使用 `./init.sh --run`。
2. 如需验证发布包，先运行 `Scripts/package-release.sh --allow-untagged`；正式发布前先提交、打 `v<MARKETING_VERSION>` tag，再运行 `Scripts/package-release.sh`。
3. 下一项建议从 `Docs/ai-translation-macos-v1-prd.md` 中选择 P1：优先实现 `p1.ocr-source-text-editing`。
4. 语言、Prompt、术语等设置必须接入真实翻译链路后再标记通过，不要只添加空壳设置项。
5. 验证通过后更新对应功能的 `passes`、`last_verified` 和本进度文件，并保持工作区整洁，提交描述性 commit。

## 会话记录

### 2026-06-24 - 实现术语表

- 新增 `TranslationGlossaryEntry`、`TranslationGlossary` 和 `TranslationGlossaryStore`，术语表保存到 `Application Support/Parrot/terminology-glossary.json`，只包含原词、译词、可选目标语言、可选上下文和启用状态，不保存 API Key、截图图片或完整未命中术语到请求。
- Settings > Translation 新增 `Terminology Glossary` 区，保持现有原生简约风格，支持新增、编辑、删除、启用/停用、按原词或译词搜索，并校验原词/译词必填和同一目标语言下重复原词。
- `OpenAICompatibleProviderClient` 的流式和非流式翻译都会加载本地术语表，根据当前源文本和解析后的目标语言只注入命中的启用术语；内置 Prompt 和自定义 Prompt 的 `{glossary}` 变量复用同一份命中术语文本，未命中时只发送 `No matched glossary entries.`。
- 修复 Settings 分区高度不协调：Settings 窗口现在按当前分区显式调整内容高度，Model、Shortcuts、Translation 和 Privacy 各自使用协调的目标高度；Translation 仍保留内部滚动区，避免内容多时撑爆窗口，也避免短页面出现大片空白。
- 新增源码链接 E2E `Scripts/terminology-glossary-e2e.swift`，覆盖本地 JSON 持久化、重复拒绝、增删改启停、目标语言和 Any-target 匹配、禁用/未命中排除、内置 Prompt 注入和自定义 Prompt `{glossary}` 渲染。
- 验证：已运行 `xcrun swiftc -parse-as-library Parrot/App/ProviderSettings.swift Scripts/terminology-glossary-e2e.swift -o /tmp/parrot-terminology-glossary-e2e && /tmp/parrot-terminology-glossary-e2e`、`Scripts/custom-translation-prompt-e2e.swift`、`Scripts/translation-style-e2e.swift`、`Scripts/translation-language-controls-e2e.swift`、`./init.sh`、`git diff --check`、`ruby -rjson -e 'JSON.parse(File.read("feature_list.json"))'`。
- 真实 smoke：`./init.sh --run` 启动固定 Debug App 后，用 CGEvent 发送 `Cmd+Option+,`，`CGWindowList` 确认出现 `owner=Parrot name=Settings`；后续验证 Settings 分区高度，Model 初始窗口约 `600x552`，切到 Translation 后约 `600x792`，再切到 Privacy 后约 `600x392`。当前环境 `osascript` 缺少辅助功能权限，未使用 AX 窗口列表作为依据。
- 已更新 `feature_list.json`：`p1.terminology-glossary.passes = true`，`last_verified = 2026-06-24`。

### 2026-06-24 - 实现自定义翻译 Prompt

- 新增 `TranslationPromptPreferences`，默认关闭自定义 Prompt；内置 Prompt 模板可在 Settings 的 `Translation` 区完整查看，支持变量 `{source_language}`、`{target_language}`、`{style}`、`{glossary}` 和 `{text}`。
- 自定义 Prompt 启用后保存前校验必须包含 `{target_language}` 和 `{text}`；缺变量或空模板时阻止保存并展示错误，`Restore Default` 会清除保存项并恢复内置 Prompt 行为。
- `OpenAICompatibleProviderClient` 的非流式与流式翻译都会加载最新 Prompt 偏好；Quick Text 与截图翻译结果窗口复用该共享 `translateStreaming` 路径，因此有效自定义模板会进入两条真实翻译链路，无效已保存模板会回退内置 Prompt。
- 新增源码链接 E2E `Scripts/custom-translation-prompt-e2e.swift`，覆盖默认 Prompt 变量展示、校验、持久化、自定义模板渲染、无效回退、Restore Default 和默认加载已保存模板。
- 验证：已运行 `xcrun swiftc -parse-as-library Parrot/App/ProviderSettings.swift Scripts/custom-translation-prompt-e2e.swift -o /tmp/parrot-custom-translation-prompt-e2e && /tmp/parrot-custom-translation-prompt-e2e`、`Scripts/translation-style-e2e.swift`、`Scripts/translation-language-controls-e2e.swift`、`./init.sh`。
- 真实 smoke：`./init.sh --run` 启动固定 Debug App 后，用 CGEvent 发送 `Cmd+Option+,`，窗口列表出现 `Settings`。
- 已更新 `feature_list.json`：`p1.custom-translation-prompt.passes = true`，`last_verified = 2026-06-24`。

### 2026-06-23 - 实现翻译风格

- 新增 `TranslationStyle` 偏好，默认 `Accurate`，支持 `Natural`、`Professional`、`Concise`，保存到 UserDefaults，不涉及 API Key、截图图片或 Provider 配置。
- Settings 新增 `Translation` 分段，展示风格选择和说明；现有 `Model`、`Shortcuts`、`Privacy` 保持原功能。
- `OpenAICompatibleProviderClient` 的非流式与流式翻译消息都会读取最新保存风格，并在 system prompt 中加入风格名称和对应指令；Quick Text 的 `Again` 与截图结果的 `Retry` 会在不重新输入文本/不重新截图的情况下使用最新风格重新请求。
- 新增源码链接 E2E `Scripts/translation-style-e2e.swift`，覆盖默认值、持久化、非法值回退、四种风格 prompt 指令、语言/核心要求保留，以及同一文本改风格后重译 prompt 变化。
- 验证：已运行 `xcrun swiftc -parse-as-library Parrot/App/ProviderSettings.swift Scripts/translation-style-e2e.swift -o /tmp/parrot-translation-style-e2e && /tmp/parrot-translation-style-e2e`、`xcrun swiftc -parse-as-library Parrot/App/ProviderSettings.swift Scripts/translation-language-controls-e2e.swift -o /tmp/parrot-translation-language-controls-e2e && /tmp/parrot-translation-language-controls-e2e`、`git diff --check`、`./init.sh`、`ruby -rjson -e 'JSON.parse(File.read("feature_list.json"))'`。
- 真实 smoke：`./init.sh --run` 启动固定 Debug App 后，用 CGEvent 在 Finder 前台发送 `Cmd+Option+,`，窗口列表出现 `owner=Parrot name=Settings`。AppleScript/System Events 路径被当前会话辅助功能权限拦截，未作为验证依据。
- 已更新 `feature_list.json`：`p1.translation-style.passes = true`，`last_verified = 2026-06-23`。

### 2026-06-23 - 修复 Debug OCR 权限身份漂移并优化语言栏

- 根因 1：`./init.sh --run` 使用 `CODE_SIGNING_ALLOWED=NO` 构建 Debug App，构建产物只有 linker/ad-hoc 可执行签名，`codesign -dr - ./.DerivedData/Build/Products/Debug/Parrot.app` 显示纯 `cdhash`；而已安装的 `/Applications/Parrot.app` 是稳定 `identifier "com.example.parrot"`，因此 Screen Recording TCC 授权可能命中正式包身份而不是当前 Debug App。
- 修复 1：`init.sh` 在 Debug 构建后先签 `Parrot.debug.dylib` 和 `__preview.dylib`，再用本地 ad-hoc 签名给 `Parrot.app` 写入稳定 designated requirement `identifier "com.example.parrot"`，并用 `codesign --verify --deep --strict` 和 `codesign -dr -` 阻断退化为纯 `cdhash` 的 Debug 产物。
- 根因 2：语言栏 UI 直接把默认 `.menu` Picker、文字标签和操作按钮平铺在大灰色卡片里，和 Quick Text 现有原生轻量层级不一致，导致控件显得重、散、突兀。
- 修复 2：`TranslationLanguageControls` 改为紧凑双字段布局：小号 uppercase 标签、small control picker、圆形互换图标按钮、轻量 `Again` 重译按钮和更低存在感的检测提示，保留原有持久化、互换和同语种校验逻辑。
- 验证：已运行 `./init.sh` 和 `./init.sh --run`；Debug App 与 `/Applications/Parrot.app` 均验证为 `designated => identifier "com.example.parrot"`；`codesign --verify --deep --strict` 通过；`Scripts/translation-language-controls-e2e.swift` 和 `Scripts/screen-capture-access-gate-e2e.swift` 源码链接 E2E 通过；`git diff --check`、`bash -n init.sh`、`feature_list.json` JSON 校验通过。
- 真实 smoke：`./init.sh --run` 后发送 `Cmd+Shift+T` 打开 Quick Text Translation，截图 `/tmp/parrot-quick-text-after.png` 确认语言栏视觉已收敛到更轻的原生控件风格；发送 `Cmd+Shift+2` 后本机仍显示权限指引窗口，因为当前机器没有给 Parrot 录屏授权，但当前 Debug App 的 TCC 身份已与已安装 App 对齐。若用户机器已有旧重复条目，运行 `tccutil reset ScreenCapture com.example.parrot` 后重新授权当前 Parrot。

### 2026-06-23 - 实现语言选择与一键互换

- 新增 `TranslationLanguagePreferences`、语言选择枚举和 `TranslationLanguageResolver`，默认保持 `Auto` -> `Auto Opposite` 的中英自动互译：中文默认译英文，英文默认译简体中文。
- Quick Text Translation 和截图翻译结果窗口新增共享语言栏，包含源语言、目标语言、互换按钮和 `Retranslate`；支持中文、英文、日文、韩文、法文、西班牙文显式选择。
- 互换逻辑覆盖显式语言对调、`Auto` + 显式目标转为显式源 + `Auto Opposite`，以及基于最近一次检测语言的 `Auto Opposite` 互换。
- `OpenAICompatibleProviderClient` 的流式和非流式翻译入口现在接收语言偏好，真实 system prompt 会写入 resolved source/target language；同一显式源/目标语言会在发请求前阻断。
- 新增 `Scripts/translation-language-controls-e2e.swift`，覆盖默认值、UserDefaults 持久化、默认中英方向、显式日文到西班牙文 prompt、同语种阻断、互换后 prompt 改变。
- 验证：已运行 `xcrun swiftc -parse-as-library Parrot/App/ProviderSettings.swift Scripts/translation-language-controls-e2e.swift -o /tmp/parrot-translation-language-controls-e2e && /tmp/parrot-translation-language-controls-e2e`、`./init.sh`、`git diff --check`、`ruby -rjson` 解析 `feature_list.json`；真实 smoke 使用 `./init.sh --run` 启动 Debug App 后在 Finder 前台发送 `Cmd+Shift+T`，窗口列表出现 `Quick Text Translation`。
- 已更新 `feature_list.json`：`p1.translation-language-controls.passes = true`，`last_verified = 2026-06-23`。

### 2026-06-23 - 实现设置全局快捷键

- 新增 `GlobalShortcutAction.openSettings`，默认快捷键为 `Cmd+Option+,`，触发后打开现有统一 `Settings` 窗口。
- `Shortcuts` 设置区新增 `Open Settings` 行，复用现有快捷键录制、保存、恢复默认、无效组合校验、冲突提示和保存后热重载流程。
- `ShortcutPreferences` 新增兼容解码逻辑：旧版只保存 Quick Text 与 Screenshot 两个快捷键时，不丢弃已有自定义配置，并自动补齐 Open Settings 默认快捷键。
- 扩展 `Scripts/custom-shortcuts-e2e.swift`，覆盖三动作默认值、持久化、冲突检测、Shift-only 无效组合、恢复默认和旧配置迁移。
- 验证：已运行 `./init.sh`、源码链接 E2E `xcrun swiftc -parse-as-library Parrot/App/GlobalShortcutManager.swift Parrot/App/ShortcutSettings.swift Scripts/custom-shortcuts-e2e.swift -o /tmp/parrot-custom-shortcuts-e2e && /tmp/parrot-custom-shortcuts-e2e`、`git diff --check`、`ruby -rjson` 解析 `feature_list.json`；真实烟测使用 `./init.sh --run` 启动 Debug App，确认无 Parrot 窗口后切到 Finder，发送 `Cmd+Option+,`，窗口列表出现 `owner=Parrot name=Settings`。
- 已更新 `feature_list.json`：`p1.settings-global-shortcut.passes = true`，`last_verified = 2026-06-23`。

### 2026-06-23 - 新增 V1 翻译偏好 PRD 和 feature 拆分

- 新增 `Docs/ai-translation-macos-v1-prd.md`，作为 MVP PRD 后续扩展，聚焦 Settings 快捷键、语言选择与一键互换、翻译风格、自定义 Prompt、术语表、OCR 原文编辑和浮窗位置偏好。
- 更新 `feature_list.json` 的 `source_documents`，新增 `p1.settings-global-shortcut`、`p1.translation-language-controls`、`p1.translation-style`、`p1.custom-translation-prompt`、`p1.terminology-glossary`、`p1.ocr-source-text-editing` 和 `p2.floating-window-position-preferences`，全部保持 `passes: false`，等待真实实现和验收。
- 更新 `AGENTS.md` 和本交接文件，明确后续实现 V1 翻译偏好功能前应读取 `Docs/ai-translation-macos-v1-prd.md`，且语言、Prompt、术语等设置必须接入真实翻译链路后再标记通过。
- 验证：已运行 `ruby -rjson` 解析 `feature_list.json`、`git diff --check` 检查新增 PRD 和 feature JSON 改动，并确认新增规划 feature 未被误标为通过。

### 2026-06-23 - 修复 v0.1.3-alpha DMG 录屏授权重启后仍失效

- 复现依据：`/Applications/Parrot.app` 为 `0.1.3-alpha` 且从该路径运行，但 `Cmd+Shift+2` 后仍出现系统 `universalAccessAuthWarn name=录屏`；打开系统设置的“录屏与系统录音”后可见两个 `Parrot.app` 录屏条目，一个已开启、一个未开启，当前运行 App 命中未开启条目。
- 根因：release 脚本对完整 App bundle 做纯 ad-hoc 签名后，`codesign -dr - /Applications/Parrot.app` 的 designated requirement 退化为 `cdhash H"..."`。macOS TCC 会把 Screen Recording 授权绑定到这次构建的哈希，而不是稳定 bundle id；旧 DMG/旧构建残留会生成多个 `Parrot.app` TCC 身份，用户开启旧身份后当前 release 重启仍未授权。
- 修复：`Scripts/package-release.sh` 现在读取并校验 `PRODUCT_BUNDLE_IDENTIFIER`，用 `codesign --requirements '=designated => identifier "com.example.parrot"'` 生成 ad-hoc app bundle 签名，并在打包前用 `codesign -dr -` 阻断退化为纯 `cdhash` 的产物；`Docs/release-process.md` 和生成的 Release Notes 已记录该 unsigned 本地签名约束。
- 验证：已运行 `bash -n Scripts/package-release.sh`、`Scripts/package-release.sh --allow-untagged`、`shasum -a 256 -c SHA256SUMS.txt`；构建产物、DMG 内 `Parrot.app` 和 ZIP 解包 `Parrot.app` 均通过 `codesign --verify --deep --strict --verbose=4`，且 `codesign -dr -` 均显示 `designated => identifier "com.example.parrot"`。已从新 DMG 覆盖安装到 `/Applications/Parrot.app` 并确认安装后 App 同样满足该 requirement。真实 UI 检查确认旧包已造成重复 `Parrot.app` 录屏条目；当前环境无法通过无障碍自动切换系统设置开关，因此完整“勾选新条目后重启并框选”需用户或具备系统设置 UI 权限的机器手动复验。若复验机已有重复条目，先执行 `tccutil reset ScreenCapture com.example.parrot` 或删除旧条目后再授权当前 `/Applications/Parrot.app`。

### 2026-06-23 - 修复 release DMG 启动被判定为已损坏

- 复现依据：`Dist/v0.1.2-alpha/Parrot-0.1.2-alpha-macos-arm64-unsigned.dmg` 校验和和 DMG 挂载均正常，但包内 `Parrot.app` 执行 `codesign --verify --deep --strict --verbose=4` 失败，报 `code has no resources but signature indicates they must be present`；截图中的“已损坏，无法打开”来自 Gatekeeper 对隔离下载 App 的签名完整性拦截。
- 根因：发布脚本使用 `CODE_SIGNING_ALLOWED=NO` 构建 Release 后直接打包，主可执行文件只有 linker/ad-hoc 签名，整个 `.app` 没有完整 `_CodeSignature/CodeResources` 资源封签。
- 修复：`Scripts/package-release.sh` 新增 `codesign` 依赖，在版本校验后、创建 zip/DMG 前执行 `codesign --force --deep --sign - "$APP_PATH"`，并立即执行 `codesign --verify --deep --strict --verbose=4 "$APP_PATH"`；发布说明同步改为“ad-hoc app bundle signature; no Developer ID signature”。
- 验证：已运行 `bash -n Scripts/package-release.sh`、`git diff --check`、`Scripts/package-release.sh --allow-untagged`，生成 `Dist/dev-5cd9e9b-dirty/`；`shasum -a 256 -c SHA256SUMS.txt` 对 dmg/zip 均通过；挂载新 DMG 后包内 `Parrot.app` 通过 `codesign --verify --deep --strict`，签名信息显示 `Signature=adhoc`、`Sealed Resources version=2`；解压 ZIP 后同样通过签名验证。`spctl` 仍因没有 Developer ID 签名而拒绝，这是 unsigned 内测包的预期限制，不再是资源封签损坏。

### 2026-06-22 - 修复未配置 API 时 OCR/快速翻译仍弹钥匙串密码窗

- 复现依据：用户在首次启动自动打开 Settings 后没有配置 API Key，直接触发 OCR/快速翻译仍看到系统提示“Parrot 想要使用你储存在钥匙串中的 com.example.parrot 机密信息”；该提示来自翻译路径的 `KeychainSecretStore.readAPIKey()` 进入 `SecItemCopyMatching` 读取旧/不安全 Keychain item。
- 根因：上次修复只设置了 `LAContext.interactionNotAllowed`，但 macOS 对调试构建签名变化后的 Keychain ACL 授权仍可能弹系统密码窗；并且该旧 provider setup record 没有在“需要系统 UI”失败后清除，导致后续 OCR 和 Quick Text 重试继续进入同一条 Keychain 读取路径。
- 修复：Quick Text 和截图 OCR 翻译入口现在先检查当前 provider 的 setup record，未配置时直接抛 App 内 `missingAPIKey`，不调用 `readAPIKey()`；`readAPIKey()` 也改为先检查 setup record 再返回进程缓存。翻译读取时同时设置 `kSecUseAuthenticationUIFail` 和非交互 `LAContext`；若 Keychain 返回 `errSecInteractionNotAllowed` 或 `errSecAuthFailed`，立即清除该 provider 的非秘密 setup record 和进程缓存并抛出 App 内重新保存 API Key 错误。下一次 OCR/快速翻译会直接走“未配置 API Key”软件提示，不再访问 Keychain。
- 验证：`Scripts/keychain-cache-e2e.swift` 新增断言覆盖 setup record 清除后即使存在进程缓存也不能返回 API Key、authentication UI fail 参数、需要系统 UI 的旧记录清理、清理后重试不再调用 `copyMatching`；`keychain-cache-e2e passed`，`./init.sh` Debug 构建通过。

### 2026-06-22 - 优化 API Key 设置和钥匙串弹窗体验

- 复现依据：Quick Text 和截图 OCR 翻译都会在翻译前调用 `KeychainSecretStore.readAPIKey()`；旧实现即使已有进程内缓存，首次读取旧 Keychain item 仍允许 macOS 展示系统钥匙串密码窗。Settings 初始化和 provider 切换也曾通过 Keychain 查询判断是否保存过 API Key。
- 根因：翻译路径把“是否配置 API Key”和“读取 secret”耦合在一起，并且 Keychain secret 读取没有使用非交互上下文；调试构建的 ad-hoc 身份变化会让 macOS 要求用户重新允许访问旧 item，于是翻译动作被系统级密码窗打断。
- 修复：`KeychainSecretStore` 现在只把非秘密 provider setup record 写入 UserDefaults 用于缺 Key 判断；保存/删除 API Key 时同步该记录；翻译读取使用进程内缓存，否则通过 `LAContext.interactionNotAllowed = true` 做非交互 Keychain 读取，遇到需要系统交互时抛出 App 内“重新输入 API Key”错误。首次启动若当前 provider 没有 setup record，会自动打开 Settings；Settings Model 区新增 API Key setup guide。Test Connection 对刚输入的新 Key 直接使用内存中的值，不再保存后立刻二次读钥匙串。
- 验证：`Scripts/keychain-cache-e2e.swift` 覆盖无 setup record 不读 Keychain、Settings 初始化/保存不读 Keychain、保存后走进程缓存、删除清记录，以及 locked Keychain item 使用非交互读取并转为 App 内错误；`./init.sh` Debug 构建通过；`./init.sh --run` 后确认缺 setup record 时自动打开 Settings，触发 Quick Text 并尝试翻译未出现系统钥匙串/Keychain 密码窗。

### 2026-06-22 - 修复录屏权限二次触发静默无响应

- 复现：运行固定 Debug App 后发送两次 `Cmd+Shift+2`；窗口列表显示 `owner=universalAccessAuthWarn name=录屏` 和 `owner=系统设置 name=录屏与系统录音`，但旧逻辑没有 Parrot 框选层或错误窗口。Parrot 的 `Info.plist` 和源码均无麦克风/语音 API，用户看到的“录音”来自 macOS 26 的“录屏与系统录音”隐私页命名，不是 Parrot 请求麦克风。
- 根因：`ScreenshotSelectionController.ensureScreenCaptureAccess()` 把所有 `CGRequestScreenCaptureAccess() == false` 都当成“系统请求已展示”的中间态并静默返回，导致首次系统权限提示后的后续未授权状态也被吞掉。
- 修复：新增 `ScreenCaptureAccessGate`，区分 `granted`、`requestPresented` 和 `deniedAfterRequest`；首次请求仍不叠加 Parrot 错误窗，后续仍未授权时显示 `Screenshot Capture Failed` 指引窗口。
- 验证：`Scripts/screen-capture-access-gate-e2e.swift` 通过首次请求静默、第二次未授权报错、授权后放行和 TCC reset 状态机检查；`./init.sh` Debug 构建通过；`./init.sh --run` 后发送两次 `Cmd+Shift+2`，窗口列表确认系统“录屏”提示仍在，同时出现 `owner=Parrot name=Screenshot Translation` 权限指引窗口。

### 2026-06-22 - 减少翻译时钥匙串重复密码弹窗

- 复现依据：快速翻译和截图 OCR 翻译路径都会在每次翻译前创建/使用 `KeychainSecretStore` 并调用 `SecItemCopyMatching` 读取 API Key；unsigned/ad-hoc App 访问该 Keychain secret 时会反复触发系统“Parrot 想要使用你储存在钥匙串中的机密信息”密码窗。设置页初始化和切换 provider 也曾通过读取 secret 判断是否已有 Key。
- 根因：API Key 只保存在 Keychain 是正确的，但读取路径没有进程内缓存，同一次 App 启动内每次 Quick Text / Screenshot 翻译都重新请求同一个 Keychain secret。
- 修复：`KeychainSecretStore` 新增按 service/provider 隔离的进程内 API Key 缓存；首次成功读取或保存后只在内存中复用，App 退出即丢失；删除 API Key 会清缓存。设置页的 `hasSavedAPIKey` 改为 Keychain attribute-only 查询，不读取 secret 数据。
- 验证：已运行 `./init.sh` 通过 Debug 构建；新增 `Scripts/keychain-cache-e2e.swift`，用 fake Keychain 验证 metadata-only 存在性检查不会读取 secret、首次读取只命中一次底层 secret、后续读取走缓存、删除会清缓存、保存新 Key 会刷新缓存。当前 CLI 沙箱直接访问真实 Keychain 会返回 `100001 UNIX[Operation not permitted]`，因此 E2E 使用注入式 fake Keychain 验证缓存逻辑。

### 2026-06-22 - 修复 unsigned DMG 首轮录屏授权提示叠加

- 复现：安装 `Parrot-0.1.1-alpha-macos-arm64-unsigned.dmg` 到 `/Applications/Parrot.app`，重置 `ScreenCapture` 后启动并触发 `Cmd+Shift+2`，窗口列表同时出现 `owner=universalAccessAuthWarn name=录屏` 和 `owner=Parrot name=Screenshot Translation`。
- 根因：`CGRequestScreenCaptureAccess()` 可以在已经弹出 macOS 系统录屏授权窗时仍对当前调用返回 `false`；旧逻辑把这个“请求已展示但当前未授权”的中间态当成最终失败，立即显示 Parrot 自己的 `Screenshot Capture Failed` 窗。
- 修复：`ScreenshotSelectionController.ensureScreenCaptureAccess()` 改为返回 `granted` / `requestPresented`，`requestPresented` 时停止当前截图流程但不调用失败回调，从而只保留系统级授权提示。
- 验证：已运行 `./init.sh` 通过 Debug 构建；已运行 `Scripts/package-release.sh --allow-untagged` 生成 unsigned dev DMG；已从 DMG 覆盖安装到 `/Applications/Parrot.app`，确认新 `CDHash=ee6fe99df14dee8fe3e38700bcb20d60443b03d2` 且仍为 `Signature=adhoc`；重置 `ScreenCapture com.example.parrot`、启动安装包并触发 `Cmd+Shift+2` 后，相关窗口只剩 `owner=universalAccessAuthWarn name=录屏`，不再出现 Parrot 的 `Screenshot Translation` 错误窗。

### 2026-06-22 - 落地 unsigned Release 打包流程

- 新增 `Docs/release-process.md`，明确 Parrot 发布使用 SemVer、`v<MARKETING_VERSION>` tag、GitHub Release 标题/资产/正文格式、unsigned Gatekeeper 提示和不移动已发布 tag 的安全规则。
- 新增 `Scripts/package-release.sh`，正式模式要求干净工作区和匹配 tag，开发验证可用 `--allow-untagged`，dirty dev 包会在目录、文件名和 Release Notes 中标出 `dirty`。
- 脚本会读取 `Config/Release.xcconfig` 的 `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`，校验 SemVer 和 build number，执行 unsigned Release 构建，验证 app bundle 版本，检测架构，并生成 `.dmg`、`.zip`、`SHA256SUMS.txt` 和 `RELEASE_NOTES.md`。
- 已更新 `AGENTS.md` 和 `feature_list.json`，使后续 Agent 在 release 任务中优先读取发布流程文档，并把 `foundation.release-packaging` 标记通过。
- 已验证：`bash -n Scripts/package-release.sh`、`Scripts/package-release.sh --help`、`ruby -rjson` 解析 `feature_list.json`、dirty worktree 下正式模式按预期拒绝、`Scripts/package-release.sh --allow-untagged` 完整 Release 构建成功、`--allow-untagged --skip-build` 复用构建生成 `Dist/dev-b8b3457-dirty/`，且 `shasum -a 256 -c SHA256SUMS.txt` 对 dmg 和 zip 均通过。

### 2026-06-22 - 实现自定义快捷键

- 新增 `ShortcutSettings.swift`，包含可持久化快捷键描述、默认配置、冲突/无效校验、Settings store、状态提示和 AppKit 快捷键录制控件。
- `GlobalShortcutManager` 不再硬编码 `Cmd+Shift+T` / `Cmd+Shift+2`，改为从 `ShortcutPreferences` 读取当前配置注册 Carbon HotKey。
- `ProviderSettingsView` 已轻量整理为统一 Settings：`Model` 复用已有 Provider/API Key/连接测试，`Shortcuts` 配置快捷键，`Privacy` 保留历史记录开关。
- 保存快捷键后通过 `GlobalShortcutManager.reloadShortcuts()` 重新注册；暂停状态下保存不会强制恢复快捷键。
- 新增 `Scripts/custom-shortcuts-e2e.swift`，覆盖默认值、UserDefaults 持久化、冲突检测、Shift-only 无效组合和恢复默认。
- 已运行 `./init.sh`、`git diff --check`、`feature_list.json` JSON 校验和源码链接 E2E；真实 App smoke 将 Quick Text 临时配置为 `Cmd+Option+Y`，在 Finder 前台触发后成功打开 `Quick Text Translation` 窗口，并已清理测试 defaults 覆盖。
- 已通过状态栏菜单打开 `Settings` 窗口，确认统一 Settings 入口可达；`p1.custom-shortcuts` 已标记通过。

### 2026-06-22 - 添加自定义快捷键设置原型图

- 针对 `p1.custom-shortcuts` 生成高保真产品原型预览图：`Design/custom-shortcuts-settings-prototype.png`。
- 原型聚焦统一 Settings 的 `Shortcuts` 区，覆盖快捷键录制、冲突提示、无效组合校验、恢复默认和保存后立即生效反馈。
- 同步新增渲染源文件 `Design/custom-shortcuts-settings-prototype.html`，便于后续迭代同一张预览图。
- 已更新 `Design/README.md` 和 `feature_list.json` 的设计参考索引。
- 根据真实 App Settings 复验结果重绘：当前 App 是单栏 SwiftUI 表单风格，不是侧边栏偏好设置；新版原型已统一为窄窗口、系统按钮、segmented control、rounded field、Divider 和 inline 状态提示。

### 2026-06-22 - 明确自定义快捷键前的 Settings 范围

- 分析当前设置页、全局快捷键实现、PRD 和 `p1.custom-shortcuts` 验收标准后，决定实现自定义快捷键时顺手做一次轻量 Settings 结构整理。
- 推荐 Settings 当前只包含 `Model`、`Shortcuts`、`Privacy`：`Model` 复用已有 Provider/API Key/连接测试，`Privacy` 复用已有历史记录开关，`Shortcuts` 新增文本翻译和截图翻译全局快捷键配置。
- 明确不提前加入空壳配置：启动项、菜单栏行为、默认语言、翻译风格、Prompt、术语表和上传策略应等对应业务行为存在后再接入。
- 已更新 `feature_list.json` 的 `p1.custom-shortcuts` 验收和备注，作为下一步实现范围依据。

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

### 2026-06-22 - 实现翻译历史

- 新增 `TranslationHistoryStore` 和 `TranslationHistoryView`，本地保存最近 50 条成功翻译记录，记录包含原文、译文、来源类型和时间。
- Quick Text Translation 和截图翻译对照窗口在 Provider 流式翻译成功后写入历史；关闭历史或空文本/失败翻译不会写入。
- 菜单栏新增 `Translation History` 入口，历史窗口支持复制译文、复制原文、清空历史和 `Esc` 关闭。
- 设置页新增 `Save translation history` 开关；关闭后阻止新增记录，已有历史仍保留到用户清空。
- 已运行 `./init.sh` 并通过 Debug 构建。
- 已运行源码链接 E2E：`xcrun swiftc -parse-as-library Parrot/App/TranslationHistory.swift Scripts/translation-history-e2e.swift -o /tmp/parrot-translation-history-e2e && /tmp/parrot-translation-history-e2e`，覆盖本地 JSON 持久化/重载、关闭开关、最多保留条数、清空和系统剪贴板复制。
- 已运行 `./init.sh --run` 并通过 Accessibility smoke：状态栏 `Parrot > Translation History` 可打开 `Translation History` 窗口。
- 已更新 `feature_list.json`：`p1.translation-history.passes = true`，`last_verified = 2026-06-22`。

### 2026-06-22 - 修复翻译历史长文本溢出

- 用户反馈多条历史记录中某条译文较长时，文本会超出灰色卡片并覆盖下一条记录。
- 修复：历史列表卡片改为稳定摘要高度，原文和译文预览最多显示 4 行并裁剪，避免长文本影响后续卡片布局。
- 新增 `View Details` 详情 sheet，完整原文和完整译文在详情里以双栏可滚动区域展示；列表里的复制按钮仍复制完整文本。
- 已运行 `./init.sh` 并通过 Debug 构建；已运行 `Scripts/translation-history-e2e.swift` 并通过历史持久化/复制回归检查。
- 已运行 `./init.sh --run` 打开真实 App，并通过状态栏打开 `Translation History`；截图检查确认长记录摘要不再覆盖下一条记录。
- 当前环境对 `osascript click at` 触发额外 Accessibility 限制，详情 sheet 的坐标点击验证未完成；详情代码已随 Debug 构建通过。
