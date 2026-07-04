# Parrot 界面国际化 PRD

版本：0.2 Draft  
日期：2026-07-04  
平台：macOS  
适用范围：当前 Parrot macOS App 的用户界面国际化规划  
当前依据：当前代码、`feature_list.json`、`parrot-progress.md`、`DESIGN.md`

## 1. 背景

Parrot 当前已经具备菜单栏常驻、Quick Text、Screenshot OCR Translation、Settings、Launch Hub、History、About、更新检测、快捷键配置、Provider 配置、翻译语言选择、翻译风格、Prompt、术语表和隐私说明等用户界面。

现状问题是：应用界面文案基本为英文，中文用户首次安装和日常使用时，需要在英文菜单、窗口、设置项、错误提示和权限说明之间理解功能。虽然 Parrot 已经支持“翻译源语言和目标语言”的选择，但这只影响翻译请求，不等于应用界面语言。

本 PRD 聚焦“App UI Language”。目标是在不扩大产品范围、不改变隐私边界、不影响现有翻译语言偏好的前提下，让 Parrot 支持中文和英文界面，并默认使用中文。当前项目尚未公开发布，不需要为既有外部用户保留英文默认体验。

## 2. 产品目标

### 2.1 目标

- 支持简体中文和英文两套用户界面文案。
- 首次启动默认显示简体中文界面。
- 用户可以在 Settings 中切换界面语言。
- 界面语言切换后立即保存，并提示用户重启 Parrot 后生效；本版本不做运行时即时切换。
- 界面语言设置与翻译源语言、目标语言、翻译风格、Prompt、术语表保持独立。
- 所有新增本地化资源不包含 API Key、翻译文本、历史内容、截图内容或 Provider 响应。

### 2.2 成功标准

- 新用户打开 App 后，菜单栏菜单、Launch Hub、Settings、Quick Text、Screenshot Translation、History、About 和关键错误提示默认展示中文。
- 用户可以在 Settings 中将界面语言切换为英文，重启 Parrot 后主要窗口展示英文文案。
- 用户再次启动 App 后，保留上次选择的界面语言。
- 翻译语言选择默认行为不被破坏：中文输入仍可译英文，英文输入仍可译中文。
- 本地化后构建通过，核心 E2E 回归通过，且不会引入新的权限、网络请求或外部依赖。

## 3. 非目标

本版本不做以下能力：

- 不支持繁体中文、日文、韩文、法文、西班牙文等更多界面语言。
- 不做按系统语言自动切换作为默认策略，默认始终为简体中文。
- 不翻译用户输入、翻译结果、翻译历史内容、术语表内容、自定义 Prompt 内容或 Provider 返回内容。
- 不改变翻译源语言和目标语言的现有能力。
- 不做云端语言包、在线文案更新或远程配置。
- 不引入第三方本地化框架。
- 不做运行时热切换，不要求当前已打开窗口在保存语言偏好后立即重绘文案。
- 不重构视觉设计，不借 i18n 改动重新设计 Settings 或窗口布局。

## 4. 用户与场景

### 4.1 核心用户

- 中文 macOS 用户，主要使用中文界面，希望用 Parrot 翻译英文资料、软件界面和截图文字。
- 中英双语用户，希望在中文和英文界面之间切换，便于截图、演示或与英文环境协作。
- 使用未签名 RC 包的早期用户，需要更容易理解权限、Gatekeeper、Provider 和 Keychain 说明。

### 4.2 核心场景

- 首次启动：用户看到中文 Launch Hub 或 Setup，引导其配置模型、理解权限和开始第一次翻译。
- 日常翻译：用户打开 Quick Text 或 Screenshot Translation，看到中文的输入提示、状态、按钮和错误恢复动作。
- 设置切换：用户进入 Settings，在 General 区将界面语言改为 English，看到“重启 Parrot 后生效”的提示。
- 问题排查：用户看到中文错误提示和隐私说明，知道应该打开 Model Settings、Setup、Screen Recording Settings 或 Retry。
- 演示和协作：用户临时切换为英文界面，重开相关窗口后看到英文文案。

## 5. 范围

### 5.1 必须本地化的界面

本节是完整覆盖范围。P0 必须覆盖菜单栏、Launch Hub、Quick Text、Screenshot Translation、Settings 主路径、History、About 和关键错误；P1 补齐 tooltip、accessibility label、窄窗口布局和低频状态文案。

- 菜单栏菜单：Quick Text Translation、Screenshot Translation、Translation History、Pause/Resume Shortcuts、Settings、Quit Parrot、Shortcuts Unavailable。
- Launch Hub：标题、副标题、入口按钮、快捷键说明、关闭和不再启动选项。
- Quick Text：标题、副标题、输入区、译文区、语言控制、状态提示、按钮、长文本确认提示、错误 CTA。
- Screenshot Translation：标题、本地 OCR loading、无文本、OCR 失败、原文和译文区、复制、重试、重新截图、权限错误。
- Settings：侧边栏、General、Model、Setup、Launch、Shortcuts、Translation、Privacy、About 各区标题、说明、按钮、状态提示。
- Provider 设置：预设、Base URL、模型、API Key、超时、保存、连接测试、删除 Keychain API Key、校验错误。
- Shortcuts 设置：动作名称、录制、冲突、无效组合、恢复默认、保存成功或失败。
- Translation 设置：翻译风格、默认 Prompt、自定义 Prompt、术语表、浮窗位置、说明和错误。
- Launch 和窗口偏好：Launch Hub 启动偏好、Dock icon 开关、页面级置顶状态说明。
- Privacy 和 About：隐私摘要、诊断摘要、更新检测、下载并打开更新、反馈、未签名 RC、Gatekeeper 说明。
- History：空状态、记录列表、详情、复制、清空确认、完成状态。
- 通用控件：Close、Cancel、Retry、Again、Copy、Save、Delete、Open、Reset、Restore Default 等。
- 窗口 title 中用户可见的文案。
- Accessibility label、tooltip 和辅助功能可读文案作为 P1 补齐项，不阻塞 P0 基础 i18n，但不能在正式完整验收中遗漏。

### 5.2 不需要本地化的内容

- 用户输入的源文本、翻译结果和历史记录内容。
- API Key 输入内容、Provider 返回原始错误中的服务商名称或状态码。
- Base URL、模型名、Provider preset id、bundle id、版本号、快捷键符号。
- 自定义 Prompt、术语表条目、诊断摘要中的 allowlist 技术字段名。
- 代码注释、开发脚本输出和 Agent handoff 文档。

## 6. 语言策略

### 6.1 支持语言

首版只支持：

- 简体中文：`zh-Hans`
- 英文：`en`

### 6.2 默认语言

默认界面语言为简体中文。

规则：

- 新安装或没有保存界面语言偏好时，使用简体中文。
- 不跟随系统语言作为默认值，即使系统语言是英文，也默认中文。
- 用户手动切换后，保存用户选择；重启 Parrot 后使用用户选择。
- 如果保存值损坏或语言资源缺失，回退到简体中文。

### 6.3 语言显示名称

Settings 中建议展示：

- `简体中文`
- `English`

英文界面中建议展示：

- `Simplified Chinese`
- `English`

## 7. 信息架构

Settings 新增 `General` 设置入口。

首版采用以下方案：

- 在 Settings 侧边栏新增 `General`。
- `General` 内包含 `App Language`。
- 当前已有的启动入口类设置继续保留在 `Launch`，不借 i18n 改动重排 Launch Hub、Dock icon 或启动展示逻辑。
- 不把 `App Language` 放进 `Launch`，避免用户把界面语言误解为启动行为偏好。

字段：

- Label：`界面语言` / `App Language`
- 控件：原生 Picker 或 segmented control。
- 选项：`简体中文`、`English`
- 说明：`仅影响 Parrot 的界面文案，不影响翻译源语言和目标语言。`
- 英文说明：`Changes Parrot's interface language only. Translation source and target languages stay separate.`
- 保存提示：`界面语言已保存。重启 Parrot 后生效。`
- 英文保存提示：`App language saved. Restart Parrot to apply it.`

## 8. 功能需求

### 8.1 本地化资源

要求：

- 使用 Apple 原生本地化能力，优先采用 String Catalog 或 `.strings` 资源。
- SwiftUI、AppKit 菜单、窗口标题、tooltip、accessibility label 都从同一套本地化机制读取。
- 新增文案时必须提供中英文，不允许只写英文 fallback。
- 文案 key 应稳定、可搜索，避免把整句英文直接散落在 Swift 代码中。
- 不把用户数据、Provider 响应或动态隐私内容写入本地化资源。
- 动态文案必须使用完整句子或格式化字符串，不允许把半句翻译拼接成一句 UI 文案。
- 格式化参数必须保留占位符语义，例如字符数、segment 数、版本号、快捷键、Provider 名称和错误状态码。

建议 key 组织：

- `menu.quick_text`
- `window.quick_text.title`
- `settings.language.title`
- `error.provider.auth.title`
- `history.clear.confirm.title`

### 8.2 界面语言偏好

要求：

- 新增本地偏好 `AppLanguagePreference`，保存用户选择的界面语言。
- 默认值为 `zh-Hans`。
- 保存位置使用 UserDefaults，只保存语言枚举值，不保存任何用户内容。
- 非法值回退为 `zh-Hans`。
- 设置项变更后更新当前设置页状态。

生效策略：

- 本版本不做运行时热切换。
- 用户在 Settings 中切换界面语言后立即保存偏好，并显示当前语言下的重启提示。
- 中文提示：`界面语言已保存。重启 Parrot 后生效。`
- 英文提示：`App language saved. Restart Parrot to apply it.`
- 不自动重启 Parrot，不关闭窗口，不取消正在进行的翻译请求。
- 重启前已打开窗口和菜单可以继续显示切换前语言；重启后所有新窗口、菜单和状态文案使用保存后的界面语言。

### 8.3 菜单栏和窗口标题

要求：

- 菜单栏所有菜单项按当前界面语言展示。
- 切换语言后不要求当前会话菜单立即更新；重启 Parrot 后菜单项必须使用保存后的界面语言。
- Quick Text、Screenshot Translation、History、Settings、Launch Hub 等窗口标题按当前语言展示。
- Dock icon 模式下，点击 Dock 重开 Quick Text 时使用当前语言。

### 8.4 Settings 语言切换

要求：

- 用户可以在 Settings 中切换 `简体中文` 和 `English`。
- 切换后立即保存。
- 切换后显示“重启 Parrot 后生效”的提示。
- 切换操作不会修改 Provider 设置、API Key、翻译语言、翻译风格、Prompt、术语表、历史开关、Launch Hub、Dock icon 或页面置顶偏好。
- 切换失败时展示可理解错误，并保留原语言。

### 8.5 翻译语言独立性

必须明确分离两类语言：

- 界面语言：控制 App 菜单、按钮、说明、错误和设置文案。
- 翻译语言：控制源语言、目标语言和 Provider prompt。

验收要求：

- 界面语言为中文时，用户仍可以把文本翻译成英文、日文或其它已有翻译目标语言。
- 界面语言为英文时，中文输入默认仍可以译为英文，英文输入默认仍可以译为中文。
- 切换界面语言不会重置翻译语言选择。

### 8.6 错误和隐私文案

要求：

- Provider、Keychain、网络、超时、Screen Recording、OCR 无文本、OCR 失败、更新检测失败等错误都提供中英文版本。
- 认证错误和 Provider 错误继续脱敏，不因为本地化改动暴露 API Key、Bearer token 或 token-like 文本。
- Provider 原始错误只允许作为脱敏、截断后的详情展示；错误标题、说明、恢复建议和 CTA 必须使用本地化模板。
- 隐私文案必须保持当前边界：API Key 只在 Keychain，截图本地 OCR，只把识别或输入文本发送给用户配置的 Provider，历史为本地 text-only。
- 中文文案避免过度营销，保持清晰、短句、可操作。

### 8.7 版式和文案长度

要求：

- 中文文案通常比英文更短，但不能依赖固定宽度假设。
- 英文文案可能更长，按钮、状态条、Settings label-column 和 tooltip 需要避免截断。
- Quick Text、Screenshot Translation 和 Settings 的核心区域不能因为语言切换导致底部按钮被挤出窗口。
- 窄窗口检查至少覆盖 Quick Text、Screenshot Translation、Settings、History 和 About。
- 长文检查至少覆盖长英文错误、长中文说明、长 Provider 名称、长模型名、长更新摘要和长 segment 进度。
- 遵循 `DESIGN.md`，使用系统字体、语义色、原生控件和轻量布局，不为 i18n 新增自定义视觉体系。

### 8.8 本地化完整性检查

要求：

- 新增源码链接测试 `Scripts/i18n-localization-e2e.swift`，并接入 `Scripts/run-core-e2e.sh`。
- 测试至少覆盖默认中文、英文偏好、非法偏好回退、重启生效提示、翻译语言独立性和 Settings 关键文案 key。
- 增加本地化资源完整性检查，确保源码引用的 key 在 `zh-Hans` 和 `en` 中都存在。
- 增加硬编码英文扫描，至少扫描 `Text("`、`Button("`、`NSMenuItem(title:)`、`window.title`、`accessibilityLabel`、`help(` 和主要状态 banner。
- 扫描允许维护少量 allowlist，例如 API Key、Base URL、Provider、Keychain、bundle id、版本号、快捷键符号和技术状态码。
- 缺失 key、非法资源格式或非 allowlist 的新增硬编码英文都应阻断该功能标记为通过。

## 9. 文案原则

### 9.1 中文语气

- 使用简洁、直接、偏工具型的中文。
- 按钮优先使用动词：`翻译`、`复制译文`、`重试`、`保存`、`打开设置`。
- 错误提示先说明发生了什么，再给下一步。
- 保留必要英文产品词：Quick Text、Provider、API Key、Keychain、Launch Hub、Gatekeeper。
- `Quick Text` 作为产品内固定入口名保留英文；中文说明中可以解释为“快速文本翻译”。

### 9.2 英文语气

- 保持当前简洁专业风格。
- 不引入营销化表达。
- 错误和隐私说明优先清楚，不追求口号。

### 9.3 术语建议

| English | 简体中文 |
| --- | --- |
| Quick Text | Quick Text（快速文本翻译） |
| Screenshot OCR | 截图 OCR |
| Screenshot Translation | 截图翻译 |
| Translation History | 翻译历史 |
| Settings | 设置 |
| Setup | 设置向导 |
| Launch Hub | 启动中心 |
| App Language | 界面语言 |
| Provider | Provider |
| API Key | API Key |
| Keychain | 钥匙串 |
| Always on Top | 窗口置顶 |
| Check for Updates | 检查更新 |
| Unsigned RC | 未签名 RC |

## 10. 隐私与安全

本需求不得改变当前隐私边界：

- API Key 仍只保存到 macOS Keychain。
- 界面语言偏好只保存语言枚举值。
- 不上传截图图片。
- 不保存截图图片、截图几何、来源 App、窗口标题或完整屏幕上下文。
- 不把翻译历史、用户输入、Provider 响应写入本地化资源。
- 不新增网络请求。
- 不把当前语言偏好发送给 Provider，除非它本来就是用户选择的翻译目标语言。
- 诊断摘要如需展示界面语言，只能展示枚举值，不包含用户内容。

## 11. 迁移策略

### 11.1 新用户

- 首次启动默认 `zh-Hans`。
- Launch Hub、Setup 和 Settings 默认中文。
- 不要求用户先选择语言。

### 11.2 当前项目迁移

- 当前项目尚未公开发布，不需要为外部既有用户保留旧英文默认体验。
- 本需求落地后，没有保存界面语言偏好的安装都按新用户处理，默认 `zh-Hans`。
- Provider、API Key、快捷键、翻译语言、历史、术语表、Prompt、Launch Hub、Dock icon、置顶和窗口位置偏好全部保持不变。
- 如本地开发者或内测者希望继续英文界面，可以在 Settings > General 中切换为 English，并重启 Parrot。

### 11.3 回滚

- 如果本地化资源加载失败，回退到简体中文。
- 如果某条文案缺失，允许临时使用英文 fallback，但该情况必须被测试或脚本发现，不能作为可接受发布状态。

## 12. 验收标准

### 12.1 功能验收

- 新安装默认界面语言为中文。
- Settings 中可以切换中文和英文。
- 切换语言后立即保存偏好，并显示重启生效提示。
- 重启 App 后保留用户选择，并使用该语言展示主要界面。
- 菜单栏菜单、Launch Hub、Quick Text、Screenshot Translation、History、Settings、About 和关键错误提示覆盖中英文。
- 切换界面语言不改变翻译语言、Provider、API Key、快捷键、历史、Prompt、术语表和隐私设置。
- 界面语言非法保存值回退为中文。

### 12.2 回归验收

- `./init.sh` Debug 构建通过。
- `Scripts/run-core-e2e.sh` 通过。
- 新增 `Scripts/i18n-localization-e2e.swift` 并接入 `Scripts/run-core-e2e.sh`，至少覆盖默认中文、英文偏好、非法值回退、重启生效提示、翻译语言独立性和菜单/Settings 关键文案 key。
- `git diff --check` 通过。
- 本地化资源格式校验通过。
- 本地化 key 完整性检查通过。
- 硬编码英文扫描通过，或只命中已记录 allowlist。

### 12.3 手动验收

- 使用 fresh defaults 启动，确认首次打开为中文。
- 从 Settings > General 切换为 English，确认出现英文或当前语言下的重启提示。
- 重启 Parrot 后打开 Quick Text、History、Settings、About 和 Launch Hub，确认主要文案为英文。
- 切回中文并重启，确认菜单栏和主要窗口恢复中文。
- 写入非法界面语言偏好后启动，确认回退为中文。
- 在英文系统 fresh defaults 下启动，确认默认仍为中文。
- 触发至少一种错误状态，例如缺 API Key 或无效 Base URL，确认错误标题、说明和 CTA 为当前界面语言。
- 在中文界面下执行一次英文到中文翻译，在英文界面下执行一次中文到英文翻译，确认翻译方向不受 UI 语言影响。

## 13. 发布分期

### 13.1 P0：基础 i18n

- 建立本地化资源结构。
- 新增界面语言偏好和 Settings 控件。
- 默认中文，切换后提示重启生效。
- 覆盖菜单栏、Launch Hub、Quick Text、Screenshot Translation、Settings、History、About 和关键错误。
- 增加 `Scripts/i18n-localization-e2e.swift`、本地化 key 完整性检查、硬编码英文扫描和 Debug 构建验证。

### 13.2 P1：体验补齐

- 补齐 tooltip、accessibility label、状态摘要和更新检测细节文案。
- 增加长文本、错误态和窄窗口下的布局检查。
- 增加本地化缺失 key 检查。

### 13.3 P2：更多语言决策

- 评估是否增加繁体中文或跟随系统语言。
- 评估是否允许首次启动选择界面语言。
- 仅在中文和英文稳定后再进入更多语言。

## 14. 风险与对策

- 风险：界面语言和翻译语言概念混淆。  
  对策：Settings 文案明确说明界面语言只影响 UI，不影响翻译源语言和目标语言。

- 风险：AppKit 菜单和 SwiftUI 窗口运行时刷新不一致。  
  对策：本版本不做运行时热切换，保存语言偏好后提示重启 Parrot 生效。

- 风险：英文长文案导致布局截断。  
  对策：重点检查 Settings、错误 CTA、Quick Text footer 和 Screenshot pane header。

- 风险：硬编码英文遗漏。  
  对策：增加源码扫描或脚本检查，至少扫描 `Text("`、`Button("`、`NSMenuItem(title:)`、`window.title`、`accessibilityLabel`、`help(` 等常见入口，并维护明确 allowlist。

- 风险：本地化资源维护成本上升。  
  对策：只支持两种语言，使用稳定 key 和集中资源，不引入远程语言包。

## 15. 已确认决策

- Settings 新增独立 `General` 分区，`App Language` 放在 `General`，不放进 `Launch`。
- 语言切换保存后提示重启 Parrot 生效，不做运行时热切换。
- 当前项目尚未公开发布，不需要兼容外部既有用户的英文默认体验；无界面语言偏好的安装默认中文。
- `Quick Text` 保留为产品内固定入口名，中文说明中可以解释为“快速文本翻译”。
