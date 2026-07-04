# Parrot Release Candidate 用户体验与正式发布 PRD

版本：0.4 Draft
日期：2026-07-04
平台：macOS
适用范围：面向用户发布前的 Release Candidate 版本规划
前置文档：`Docs/ai-translation-macos-prd.md`、`Docs/ai-translation-macos-v1-prd.md`、`Docs/ai-translation-macos-v2-prd.md`
当前依据：当前代码、`feature_list.json`、`parrot-progress.md`、`DESIGN.md`、`Docs/release-process.md`
审查基线：基于 2026-07-04 当前工作区审查；当时 `feature_list.json`、`parrot-progress.md` 有未提交修改，本文为未跟踪 PRD 草稿。落地前需要重新记录 commit hash、dirty state 和本轮验证命令。

## 1. 背景

Parrot 已经从原型进入可日常使用阶段。当前已完成菜单栏常驻、全局快捷键、Quick Text Translation、Screenshot OCR Translation、本地 OCR、OpenAI-compatible Provider、Keychain API Key、翻译历史、自定义快捷键、语言选择、翻译风格、自定义 Prompt、术语表、OCR 原文编辑、浮窗位置偏好、请求生命周期、Provider 端点规范化、超时设置、长文本分段和 Setup Checklist。

因此，面向用户正式发布前，最重要的工作不再是继续堆翻译能力，而是补齐“入口可见、首次成功、失败恢复、发布可信、可反馈、可检测更新、可升级”的用户体验闭环。

当前主要证据：

- `feature_list.json` 中 MVP、V1 和 V2.0 核心功能均已标记通过。
- `Config/Release.xcconfig` 当前版本为 `0.1.4`，bundle id 仍为 `com.example.parrot`，`DEVELOPMENT_TEAM` 为空。
- `Docs/release-process.md` 当前只定义 unsigned / ad-hoc signed 本地包流程，明确 Developer ID 签名与 notarization 仍是 future work。
- `README.md` 仍描述为 early SwiftUI scaffold，且版本仍写 `0.1.0`，与当前实现和发布配置不一致。
- 代码中未发现 About、Feedback、Check for Updates、Sparkle、release channel、首次安装引导、启动入口保障、Dock 图标开关、独立页面置顶或面向用户隐私说明入口。
- App 当前是 `LSUIElement` 菜单栏工具；启动时如果 Provider 已配置完成，不会默认展示前台窗口。菜单栏空间不足、刘海屏或菜单栏 App 过多时，用户可能看不到 Parrot 图标，只能依赖尚未熟悉的快捷键。
- 核心翻译流可用，但部分失败状态缺少直接恢复动作，例如 Quick Text 错误只展示 banner，Screenshot Provider 错误不如 Quick Text 结构化，OCR 在结果窗口出现前同步执行，Settings 保存允许明显无效 Provider 配置落盘，History 清空无确认或撤销。

本 PRD 保持单版本规划，不拆成多个 PRD。为了避免同一版本内返工，RC 内部按 gate 推进：先确认发布路线和不可逆决策，再补首译与失败恢复，最后补更新、置顶、Dock 图标等用户体验增强。所有条目仍属于同一个 RC 版本范围，但实施和验收必须按优先级分层。

## 2. 版本定位

一句话定位：

> Parrot RC 要让新用户第一次安装后能信任它、配置它、遇到失败能自己恢复，并安全完成一次真实翻译。

Release Candidate 不是新能力大版本，而是“正式发布前的信任与可恢复性版本”。

关键词：

- 首次成功
- 入口可见
- 失败可恢复
- 隐私透明
- 发布可信
- 反馈可达
- 更新可检查
- 升级可解释
- 窗口可控

## 3. 目标用户

### 3.1 核心用户

- 第一次从 GitHub Release 或网站下载 Parrot 的 macOS 用户。
- 自带 OpenAI-compatible API Key，但不熟悉 Parrot 设置结构的用户。
- 高频使用 Quick Text 和 Screenshot Translation 的研发、产品、设计、运营、研究用户。
- 关注隐私边界，想确认截图是否上传、API Key 存在哪里、历史如何保存的用户。

### 3.2 关键场景

- 用户安装后首次启动，知道还缺 API Key、连接测试或 Screen Recording 权限。
- 用户 Provider 配置错误，能从翻译窗口直接进入修复路径，而不是只看到错误。
- 用户框选截图后，即使 OCR 较慢，也能看到正在识别的状态，不误以为 App 无响应。
- 用户想确认版本、隐私承诺、发布说明、反馈方式和更新方式。
- 用户首次安装后不需要阅读完整 README，也能按引导完成 API Key、连接测试、快捷键认知、Quick Text 首译和可选 Screen Recording 授权。
- 用户首次启动和已配置后启动时，默认能看到一个前台入口窗口，而不是只能寻找菜单栏图标或记忆快捷键。
- 用户菜单栏图标被刘海区域、系统折叠或其他菜单栏 App 挤掉时，仍能通过 Launch Hub、Dock 图标开关或全局快捷键打开核心页面。
- 用户想检查当前是否是最新版本，并能查看更新说明、下载新版或理解当前更新通道限制。
- 用户需要把 Quick Text、Screenshot OCR、History、Settings 等任一页面临时置顶，同时不影响其他页面的置顶状态。
- 用户准备清空历史或重置配置时，能避免误删或至少看到确认。
- 用户从 unsigned 内测包升级到正式包时，能理解 Screen Recording 和 Keychain 可能需要重新授权或重新保存。

## 4. 产品目标

### 4.1 RC 目标

- 在开始代码实现前，先确认本次 RC 的发布路线：`unsigned public RC` 或 `public signed release`。该路线决定 About、README、Release Notes、更新检测、安装说明和 TCC/Keychain 升级说明的文案。
- 把首次启动和 Provider 配置从“能找到设置”提升为“能完成首次成功翻译”。
- 把核心失败状态从“展示错误文字”提升为“错误 + 原因 + 恢复动作”。
- 把发布包从“可打包”提升为“用户可理解、可安装、可验证、可反馈”。
- 把更新体验从“用户自己找 Release”提升为“App 内可检查、可理解、可跳转更新”。
- 把首次安装体验从“自动打开设置”提升为“有步骤、有完成感、有首译目标的 onboarding”。
- 把启动体验从“只有菜单栏图标和快捷键”提升为“有可靠前台入口、可关闭、可恢复”。
- 把窗口控制从“系统默认层级”提升为“每个核心页面可独立置顶，不互相干扰”。
- 把隐私说明从文档散落提升为 App 内可达的用户承诺。
- 把高风险破坏性动作增加确认、撤销或明确后果说明。

### 4.2 单版本内推进 gate

RC 仍然是一个版本，但实施时必须按以下 gate 推进。前一个 gate 的决策会影响后续文案、入口和验证方式。

1. 发布路线 gate：确认 `unsigned public RC` 还是 `public signed release`，并确认 bundle id、签名、公证、更新 channel、反馈入口和诊断字段边界。
2. 首次成功 gate：完成 Settings 保存前校验、错误恢复 CTA、Setup/Onboarding 可首译路径、README/Privacy/About 基础说明。
3. 入口可见 gate：完成 Launch Hub、启动展示偏好和必要的 onboarding 状态机。`Show Dock icon` 只作为同版本后置增强，必须在 Launch Hub 稳定后接入。
4. 发布可信 gate：完成 About/Feedback、Release Notes、更新检测、unsigned 或 signed 文案、历史清空保护和发布包验证。
5. 窗口可控 gate：完成 OCR 异步 loading、页面置顶、Dock 图标等对窗口层级或 activation policy 有影响的功能，并通过真实 macOS smoke。

### 4.3 成功指标

- 新用户从首次启动到完成 Quick Text 首次翻译的目标时间不超过 3 分钟。
- 缺 API Key、Provider 认证失败、Base URL 无效、网络超时、Screen Recording 未授权等失败状态均提供直接 CTA。
- 截图翻译从框选结束到 OCR/翻译窗口出现期间有明确 loading 或进度反馈。
- App 内可以查看版本、build、bundle id、隐私说明、发布说明、反馈入口和更新检查结果。
- 首次安装后有一次性 onboarding，用户能明确完成配置、测试连接、认识默认快捷键并完成首译。
- 首次启动和已配置后启动默认展示前台 Launch Hub 或 onboarding 入口；状态机必须明确全新安装、已跳过、已完成、配置无效、用户关闭启动展示和版本升级时谁优先。
- Settings 提供 `Show Launch Hub on Startup` 和 `Show Dock icon` 控制；用户关闭启动窗口后仍能恢复入口策略。
- Quick Text、Screenshot OCR、History、Settings 和 About/Update 等用户可见页面都提供独立置顶控制；Quick Text 和 OCR 页面置顶按钮位于 History 按钮左侧。
- 正式发布包通过签名、公证和 Gatekeeper 验证，或如果仍是 unsigned RC，用户文案必须清楚标记限制。

## 5. 非目标

RC 不做以下能力：

- 云同步、账号系统、团队术语库或协作权限。
- 内置模型服务、订阅、license、试用计费或支付。
- 默认上传截图给多模态模型。
- 原位覆盖翻译、PDF 工作台或专业 CAT 工具。
- 跨平台版本。
- 静默后台强制更新、未经用户确认的自动安装，或 unsigned/dev 包混入正式更新通道。
- 大规模工程重构。RC 只允许为发布风险服务的小步拆分和测试补齐。

### 5.1 UI/UX 设计约束

本 PRD 涉及多个 UI/UX surface：菜单栏、Settings、Launch Hub、Onboarding、About/Update/Feedback、错误恢复 CTA、OCR loading、空状态、页面置顶按钮、Dock 图标开关和窗口层级。所有实现都必须先读取并遵循根目录 `DESIGN.md`。

设计执行规则：

- 以 `DESIGN.md` 的 `Invisible Utility` 为主线：界面应低干扰、轻量、像 macOS 原生工具，避免变成重型控制台或营销页。
- SwiftUI/AppKit 实现优先使用 macOS semantic colors、系统字体、原生 Button、Picker、TextField、Toolbar、Popover、Sheet 和窗口行为。`DESIGN.md` 中的 hex 色值和 Inter 字体只作为 review、lint 或 Web 原型 fallback，不应直接硬编码到原生界面。
- 遵循 `DESIGN.md` 的低装饰原则：少阴影、少强边框、少大色块，用 native 分组、留白、hairline divider 和 tonal layer 表达层级。
- 菜单栏必须保持短、小、工具化，只承载高频动作；低频发布可信入口放到 Settings、About 或 Launch Hub。
- Settings、About、Launch Hub 和 Onboarding 的信息层级要保持克制，不重复成多套配置系统。
- 错误态、loading、空状态、禁用态、成功态和更新失败态都需要可读、可恢复，不用装饰性插画或强营销文案。
- 新增按钮、pin 图标、状态 pill、banner、表单分区和窗口顶栏动作时，不得引入新的自定义颜色、字体、圆角、阴影或动画，除非 PRD 或 `DESIGN.md` 明确需要。
- 所有用户可操作控件必须有清晰 label、tooltip 或 accessibility label。置顶、更新检测、清空历史、Dock 图标开关等状态型控件需要表达当前状态。
- 不默认引用 `/Design` HTML 原型。只有用户明确要求对照 `/Design` 或按原型重构时，才读取对应 `code.html`。

验收规则：

- 每个 UI/UX feature 的实现记录必须说明已读取 `DESIGN.md`，并说明是否存在本地设计例外。
- 至少完成一次 light/dark、长文本、错误态或空状态检查；涉及窗口层级、Dock 图标、Launch Hub、Onboarding 的功能还需要真实 macOS smoke。
- 如果 UI 文案或布局与当前代码、macOS HIG 或隐私约束冲突，优先级为：隐私/安全/macOS 权限/Keychain > macOS HIG > `DESIGN.md` > PRD 文案。

## 6. 推荐 Feature / Issue 清单

### 6.1 P0：必须解决，作为面向用户发布 gate

#### RC-P0-1 翻译错误恢复 CTA

问题：

Quick Text 和 Screenshot Translation 已能展示 Provider 错误，但修复路径不够贴身。Quick Text 错误 banner 没有显式 `Open Setup` / `Open Settings` 按钮；Screenshot Provider 错误只显示状态文案，没有结构化错误标题、说明和恢复建议。

用户价值：

- 用户不需要猜测该去哪里修复 API Key、Base URL、模型名或网络问题。
- 减少“我配置了但不能用”的首次流失。

范围：

- Quick Text 错误 banner 增加恢复 CTA：`Open Setup`、`Open Model Settings` 或 `Retry`。
- Screenshot Translation 使用与 Quick Text 同源的错误 presentation。
- Provider 配置类错误优先引导到 Setup / Model。
- 网络或超时错误保留 `Retry`，不要强迫进入 Settings。
- CTA 不记录待翻译文本、Provider 响应或 API Key。

验收：

- 缺 API Key 时，Quick Text 和 Screenshot Translation 都能一键打开 Setup 或 Model。
- Base URL 无效、模型为空、认证失败、网络失败、超时失败均显示可行动恢复建议。
- 错误 UI 不泄漏 API Key、Bearer token 或 token-like 文本。
- 取消翻译仍显示为取消状态，不被当作 Provider 错误。

#### RC-P0-2 截图 OCR 异步 loading

问题：

当前截图框选完成后，`AppDelegate` 会先执行本地 Vision OCR，再创建结果窗口。大区域或复杂截图时用户可能感知为“框选后没反应”。

用户价值：

- 框选后立即得到反馈。
- 用户知道 App 正在本地识别，不误判为卡死或快捷键失效。

范围：

- 框选完成后立即打开 Screenshot Translation 窗口。
- 窗口先展示截图预览和 `Recognizing text locally...` 状态。
- OCR 在后台任务执行，完成后更新 Original pane 并自动进入翻译。
- OCR 失败、无文字、取消或新截图请求必须能停止旧状态回写。
- 不上传截图，不保存截图图片或截图几何。

验收：

- 复杂截图场景中，窗口在框选完成后立即出现 loading。
- OCR 成功后自动进入现有翻译链路。
- OCR 无文本时保留可操作空状态和 `New Screenshot`。
- 关闭窗口后，OCR 或翻译晚到不会写入已关闭窗口或成功历史。

#### RC-P0-3 Settings 保存前校验

问题：

Provider Settings 的保存动作当前主要负责持久化，明显无效的 Base URL 或空 model 可能被保存，之后才在翻译或 checklist 中暴露。

用户价值：

- 用户在错误配置进入日常翻译流之前就被拦截。
- 降低“测试成功/翻译失败”或“保存成功但不能用”的困惑。

范围：

- `Save Settings` 前校验 Base URL 可规范化为 HTTPS chat completions endpoint。
- 校验 model 非空。
- timeout 保持现有 clamping 行为，并展示边界说明。
- 不强制要求保存时必须通过连接测试；连接测试仍是单独动作。
- 自定义 Provider 可以保存合法 HTTPS endpoint 和 model。

验收：

- 空 model、非 HTTPS URL、无法规范化 endpoint 时不能显示 `Settings saved`。
- 合法 root、`/v1`、完整 `/chat/completions` 仍能保存。
- Save 与 Test Connection 使用同一套 Provider endpoint validation。
- API Key 仍只保存到 Keychain，不进入 UserDefaults。

#### RC-P0-4 App 内 About / Privacy / Feedback

问题：

当前 App 内没有 About、Feedback、版本信息、隐私承诺或发布说明入口。用户无法确认自己运行的版本，也找不到反馈路径。

用户价值：

- 用户能确认版本、build、bundle id 和 release channel。
- 用户能理解 API Key、截图、OCR、Provider 请求和历史数据的隐私边界。
- 用户遇到问题时有明确反馈路径。

范围：

- Settings 新增 `About` 分区，菜单栏不单独新增 `About Parrot`。
- 展示 App version、build number、bundle identifier、macOS requirement。
- 展示隐私摘要：API Key in Keychain、local OCR、only recognized text sent to configured Provider、text-only history、history can be disabled/cleared。
- 提供 `Open Release Notes`、`Copy Diagnostics Summary`、`Send Feedback`。
- Diagnostics summary 默认只能包含版本、build、bundle id、macOS version、provider preset id、release channel、permission status、feature flags；不能包含 API Key、待翻译文本、Provider 响应、历史内容、截图、窗口标题、来源 App 或 Provider endpoint host。
- 如果未来需要包含 sanitized endpoint host，必须由用户在复制前显式勾选，且默认关闭。

验收：

- 用户能从 Settings 打开 About；Launch Hub 可提供 About 快捷入口。
- 用户能复制诊断摘要，且摘要不包含 secret 或用户文本。
- 反馈入口可用；如果没有服务端反馈系统，至少打开 GitHub Issues 或 mailto 链接。
- Privacy 文案和实际代码边界一致。

#### RC-P0-5 发布文档与 README 更新

问题：

`README.md` 仍描述为 early scaffold，版本为 `0.1.0`，不符合当前实现。正式发布时，用户需要明确安装、权限、API Key、Gatekeeper、隐私和已知限制。

用户价值：

- 下载前知道 Parrot 能做什么、不能做什么。
- 安装失败、权限失败、Provider 配置失败时能自助排查。

范围：

- 更新 README：当前功能、默认快捷键、Provider 配置、Screen Recording、Keychain、历史、长文分段、隐私边界。
- 增加 `Docs/user-release-notes-template.md` 或扩展 release notes 模板。
- 增加用户向 FAQ：Gatekeeper、Screen Recording、重复 Parrot.app 权限条目、API Key 重新保存、卸载与数据位置。
- 保持 AGENTS / feature tracking 仍是 agent-facing，不把内部流程暴露成用户主文档。

验收：

- README 不再声称 core features under development。
- README 版本信息与 `Config/Release.xcconfig` 同步或改为说明由 Release 配置决定。
- Release notes 包含安装步骤、权限说明、隐私说明、已知限制和反馈方式。

#### RC-P0-6 正式分发签名决策

问题：

当前 release 包是 ad-hoc signed、unsigned/unnotarized。若“正式发布”指面向普通用户公开下载，Gatekeeper 与 TCC/Keychain 体验会成为信任阻碍。

用户价值：

- 减少“App 已损坏”“无法验证开发者”“录屏权限重复条目”等安装和升级困惑。
- 让发布版本具备更稳定的 macOS 身份。

范围：

- 决策门必须在任何面向用户发布体验实现前完成：本次发布是 `public signed release` 还是 `unsigned public RC`。
- 如果是 public signed release：确认正式 bundle id、Apple Developer Team、Developer ID Application 证书、notarization credentials、stapling 流程。
- 如果仍是 unsigned RC：文件名、Release Notes、About、README 都必须明确 `unsigned` 和 Gatekeeper 限制。
- 不允许在普通 feature PR 中顺手修改 bundle id 或 signing team。
- 该决策必须输出当前版本的发布 channel 文案：`unsigned RC`、`public signed release` 或 `local dev build`，供 About、README、Release Notes 和 Check for Updates 复用。
- 如果发布路线在实现中途变化，需要重新检查 About、诊断摘要、更新检测、安装说明、TCC/Keychain 升级说明和 package artifact 命名。

验收：

- public signed release 必须通过 `spctl` 验证。
- unsigned RC 必须清楚标记限制，并给出安装和权限恢复步骤。
- 从旧 ad-hoc 包升级的 TCC/Keychain 行为有手动验证记录或已知限制说明。
- PRD 落地任务开始前记录 release lane、bundle id、签名状态、notarization 状态、目标 release asset 类型和验证命令。

#### RC-P0-7 软件检测和更新功能

问题：

当前 App 内没有 `Check for Updates`，用户无法知道自己是否运行最新版本，也无法从 App 内查看更新内容或进入下载路径。正式面向用户发布后，缺少更新检测会增加支持成本，也会让 bugfix 和安全修复难以触达用户。

用户价值：

- 用户能在 App 内确认当前版本是否最新。
- 用户能看到新版本号、发布时间、更新摘要和下载入口。
- 用户在 unsigned RC、公测包和正式 signed release 之间能理解当前更新通道限制。

范围：

- About 页面新增 `Check for Updates`，Launch Hub 可提供快捷入口；菜单栏不单独新增更新入口。
- 更新检测默认由用户主动触发；可选支持每日最多一次的轻量自动检测，但必须能关闭，且失败不打扰核心翻译流程。
- 更新源优先使用 GitHub Releases 或项目维护的 HTTPS JSON feed，返回 latest version、release date、release notes URL、download URL、minimum macOS version、checksum 或 signature metadata。
- 当前版本来自 `CFBundleShortVersionString` 和 `CFBundleVersion`，不能硬编码。
- 检测结果展示三种状态：`Up to Date`、`Update Available`、`Unable to Check`。
- `Update Available` 提供 `Open Release Notes`、`Download Update`、`Copy Version Info`。
- 如果未引入 Sparkle 或 notarized 自动更新链路，`Download Update` 只打开浏览器下载页，不在 App 内静默替换应用。
- signed release 和 unsigned RC 使用不同 channel 文案；unsigned/dev 包不能自动接入正式更新安装通道。
- feed 契约必须固定字段和解析规则：version、build、channel、releaseDate、minimumMacOS、releaseNotesURL、downloadURL、checksum 或 signature metadata、isPrerelease。
- 版本比较使用 SemVer；当前版本高于 feed latest 时显示本地版本较新，不提示降级。
- GitHub Releases API 方案必须考虑 rate limit 和离线失败；静态 JSON feed 方案必须记录托管地址和更新发布流程。
- 未实现 Sparkle 或签名更新链路前，更新检测只做“检查和跳转下载”，不能展示“自动安装”“后台更新”或类似文案。

验收：

- 用户能从 About 页面触发更新检测；Launch Hub 可作为快捷入口跳转到同一页面。
- 网络失败、feed 无效、版本解析失败时显示可理解错误，不影响 Quick Text、Screenshot OCR 和 Settings。
- 当前版本等于或高于 feed latest 时显示已是最新版。
- feed latest 高于当前版本时显示版本号、日期、摘要和下载入口。
- 更新检测不发送 API Key、Provider 配置、翻译文本、历史内容、截图或诊断摘要。
- 自动检测如果启用，频率不超过每天一次，并支持关闭。
- feed 无 checksum 或 signature metadata 时，下载入口必须标记为手动下载，不能暗示 App 已验证安装包完整性。

#### RC-P0-8 用户首次安装后的使用引导

问题：

当前首次启动会在缺 API setup record 或 Provider 配置无效时打开 Setup Checklist，但它更像设置页，不是完整的新用户引导。第一次安装的用户仍需要自己理解菜单栏入口、默认快捷键、Provider/API Key、连接测试、Quick Text 首译、Screenshot OCR 权限和隐私边界。

用户价值：

- 用户首次安装后能按步骤完成首译，而不是在 Settings 中摸索。
- 用户能理解 Quick Text 不需要 Screen Recording，而 Screenshot OCR 需要 macOS 权限。
- 用户能在首次成功后知道如何再次打开 Quick Text、Screenshot、History 和 Settings。

范围：

- 首次安装或首次运行当前 bundle version 时显示 onboarding。
- Onboarding 使用轻量原生窗口或 Settings `Setup` 顶部引导模式，不引入重型教程系统。
- 步骤建议：
  1. Welcome：说明 Parrot 是菜单栏翻译工具，展示隐私承诺摘要。
  2. Provider：选择 Provider、输入 API Key、保存到 Keychain。
  3. Test Connection：测试连接并展示错误恢复 CTA。
  4. Learn Shortcuts：展示默认 Quick Text、Screenshot、Open Settings 快捷键，并链接到 Shortcuts 设置。
  5. First Translation：引导用户输入短文本完成 Quick Text 首译。
  6. Optional Screenshot OCR：解释 Screen Recording 权限只用于本地截图 OCR，用户可跳过。
- 用户可跳过 onboarding；跳过后仍可从 Settings 或 Launch Hub 重新打开。
- Onboarding 完成状态按 bundle version 或 schema version 本地保存，不上传。
- 如果用户已配置 API Key 和可用 endpoint，onboarding 直接展示完成状态和快捷入口，不强迫重复配置。
- Onboarding 与 Launch Hub 共用一套启动状态机，不能在同一次启动里同时弹出两个前台窗口。
- 如果 Provider 配置无效，优先打开 Setup/Onboarding 修复路径；如果配置有效且 onboarding 已完成，才按 `Show Launch Hub on Startup` 展示 Launch Hub。
- 用户跳过 onboarding 不等于关闭 Launch Hub；用户关闭 Launch Hub 启动展示也不等于完成 onboarding。

验收：

- 全新安装首次启动时出现 onboarding 或明显的 Setup 引导入口。
- 用户能在 onboarding 中完成 API Key 保存、连接测试和 Quick Text 首译。
- Screen Recording 权限步骤是可选项，跳过后 Quick Text 仍可用。
- 跳过、完成、重新打开 onboarding 的状态清晰可控。
- Onboarding 不保存 API Key 明文，不上传用户输入，不把首译文本写入 diagnostics。
- 更新版本后，只有当 onboarding schema 变化或需要说明关键发布变化时才再次提示。
- 覆盖启动状态：全新安装、已跳过 onboarding、已完成 onboarding、Provider 配置无效、关闭 Launch Hub 启动展示、版本升级且 schema 未变化、版本升级且 schema 变化。

#### RC-P0-9 所有页面独立置顶按钮

问题：

Parrot 的核心窗口是短时工具窗口，但用户在阅读、对照、配置或抄录内容时，可能需要把某个页面保持在其他窗口之上。当前没有统一置顶控制；如果未来只做全局置顶，会导致 Quick Text、OCR、History 和 Settings 互相影响，不符合用户对“只置顶当前页面”的预期。

用户价值：

- 用户可以让当前页面临时保持可见，减少在多窗口工作流中反复找窗口。
- Quick Text 和 Screenshot OCR 可在查资料、写文档时保持翻译结果可见。
- Settings 可在配置 Provider 或快捷键时置顶，不影响翻译窗口。

范围：

- 所有用户可见页面都新增页面置顶按钮，包括 Quick Text、Screenshot OCR/Translation、History、Settings、About/Update/Feedback 等独立窗口或页面。
- Quick Text 和 Screenshot OCR 页面中，置顶按钮固定放在 History 按钮左侧。
- Settings 页面也必须提供置顶按钮，位置与窗口顶栏动作区一致。
- 每个页面的置顶状态独立，不会相互影响。例如 Quick Text 置顶不改变 Screenshot OCR、History 或 Settings 的置顶状态。
- 置顶行为作用于当前窗口的 `NSWindow.Level`，不改变 App 激活策略、全局快捷键或其他窗口层级。
- 置顶状态建议本地持久化到每个 surface 的偏好键，例如 `quickText.alwaysOnTop`、`screenshotTranslation.alwaysOnTop`、`history.alwaysOnTop`、`settings.alwaysOnTop`、`about.alwaysOnTop`。
- 置顶按钮使用轻量 pin 图标或文字按钮，符合 `DESIGN.md` 的 native、低干扰、工具属性，不使用强装饰样式。
- 置顶状态需要可见反馈，例如 selected/tinted state、tooltip 或 accessibility label。
- 实施顺序上先接入 Quick Text 和 Screenshot OCR/Translation，再接入 History、Settings、About/Update。后续页面必须复用同一套窗口层级工具，避免每个窗口自行设置 level。
- 置顶状态不能影响截图框选 overlay；overlay 仍只在截图选择期间使用高层级窗口，结束或取消后释放。

验收：

- Quick Text 的置顶按钮在 History 按钮左侧，切换后只影响 Quick Text 当前/后续窗口。
- Screenshot OCR/Translation 的置顶按钮在 History 按钮左侧，切换后只影响 OCR/Translation 当前/后续窗口。
- History、Settings、About/Update 页面都有置顶按钮，并且状态互相独立。
- 重启 App 后，每个页面按各自最近保存的置顶偏好恢复。
- 关闭某个置顶页面不会取消其他页面的置顶状态。
- 置顶窗口仍可被 Esc、Close、Quit 正常关闭，不截获系统级输入或影响 macOS Mission Control。
- VoiceOver/accessibility label 能表达 `Keep Window on Top` 和当前开关状态。
- 至少完成一次真实 macOS smoke：同时打开两个不同 surface，分别切换置顶，确认窗口 level、关闭行为、Esc 和 Mission Control 没有明显异常。

#### RC-P0-10 启动入口保障 / Launch Hub

问题：

Parrot 当前是菜单栏工具形态。首次启动或已配置后启动时，如果没有缺失配置，App 可能只显示菜单栏图标，不默认打开前台页面。对于刘海屏、菜单栏空间很小、菜单栏 App 较多或系统自动隐藏部分图标的用户，Parrot 图标可能不可见；新用户又不熟悉快捷键，因此会不知道如何打开 Quick Text、Screenshot OCR、History 或 Settings。

用户价值：

- 用户首次安装和后续启动时都有可靠、可见、可操作的入口。
- 菜单栏图标不可见时，用户仍能打开翻译界面。
- 熟练用户可以关闭启动入口，保留轻量菜单栏/快捷键模式。
- 需要更传统入口的用户可以开启 Dock 图标。

范围：

- 新增轻量 `Launch Hub`，作为启动后的前台入口窗口。
- 首次安装默认展示 onboarding；已完成 onboarding 且 Provider 配置可用时，启动默认展示 Launch Hub。
- Launch Hub 提供 Quick Text、Screenshot OCR、History、Settings、Onboarding Guide、Check for Updates 等入口，并展示当前快捷键。
- Launch Hub 必须前台可见：启动时使用 accessory activation、activate、make key/order front；必要时对启动入口窗口使用短时 `orderFrontRegardless()`，但不能长期强占焦点。
- Launch Hub 提供 `Don't show this on startup`，用户关闭后不再每次启动弹出。
- Settings 新增 `Show Launch Hub on Startup`，用户可随时恢复启动展示。
- Settings 新增 `Show Dock icon` 开关，允许用户把 Parrot 从纯菜单栏工具切换为可在 Dock、App Switcher 中看到的 App。
- `Show Dock icon` 默认关闭，保持 Parrot 的轻量菜单栏定位；开启后应用 activation policy 切换为 regular，关闭后恢复 accessory/prohibited 菜单栏形态。
- `Show Dock icon` 文案必须说明：开启后 Parrot 会出现在 Dock 和 App Switcher；关闭后仍可通过 Launch Hub、菜单栏和快捷键打开。
- Dock 图标开关不改变全局快捷键、截图权限、Provider 设置、历史保存或窗口置顶偏好。
- 菜单栏图标仍保留；Dock 图标是补充入口，不替代菜单栏菜单。
- `Show Dock icon` 是同版本后置增强。必须先完成 Launch Hub 和 `Show Launch Hub on Startup`，再接入 activation policy 切换。
- Dock 图标开启后，关闭最后一个窗口时 Parrot 仍保持后台运行，除非用户选择 `Quit Parrot`。该行为需要在 Settings 文案中说明，避免用户把 Dock 模式误解为普通退出语义。
- 启动状态机优先级：权限或 Provider 配置修复入口优先于 Launch Hub；onboarding schema 变化优先于普通 Launch Hub；用户关闭启动展示后不自动弹出 Launch Hub；用户主动开启 Dock 图标不自动改变 Launch Hub 展示偏好。

验收：

- 全新安装首次启动时，用户不用点击菜单栏图标也能看到 onboarding 或 Launch Hub。
- 已完成配置后重启 App，默认展示 Launch Hub，除非用户关闭了 `Show Launch Hub on Startup`。
- Launch Hub 在普通桌面窗口前可见，能直接打开 Quick Text、Screenshot OCR、History 和 Settings。
- 用户关闭 `Show Launch Hub on Startup` 后，重启不再弹出 Launch Hub；在 Settings 中重新开启后恢复。
- 开启 `Show Dock icon` 后，Parrot 出现在 Dock 和 App Switcher；关闭后恢复菜单栏工具行为。
- Dock 图标开关重启后保持用户选择。
- 菜单栏图标被隐藏或不可见时，用户仍能通过 Launch Hub 或 Dock 图标打开核心页面。
- Launch Hub 不保存翻译文本、截图、历史内容或 API Key，不写入 diagnostics。
- Launch Hub 和 onboarding 在同一次启动中不会同时抢前台；配置无效、用户关闭启动展示、schema 升级和 Dock 图标开启场景都有明确验证记录。

### 6.2 P1：建议进入 RC polish

#### RC-P1-1 清空历史确认或撤销

问题：

History 的 `Clear History` 直接删除所有记录，没有确认或撤销。

验收：

- 清空历史前显示确认，说明只清除本地 text-only 历史。
- 或提供短时 Undo，不要求跨重启恢复。
- 禁用历史开关不删除已有历史，文案保持清晰。

#### RC-P1-2 Quick Text 多行输入提示

问题：

Quick Text 实际支持 `Shift+Enter` 换行，但 header 只提示 Enter、Cmd+Enter 和 Esc。

验收：

- Quick Text 文案包含 `Shift+Enter inserts a new line`。
- 文案不挤占主要输入区，不增加操作复杂度。

#### RC-P1-3 长文确认信息增强

问题：

超过 8000 字符时已有确认机制，但提示偏技术化，没有展示预计分段数、费用/延迟风险和可取消性。

验收：

- 大文本确认展示字符数、预计分段数、顺序翻译、可取消、失败可重试。
- 用户确认前不发起 Provider 请求。
- 取消或未确认不写历史。

#### RC-P1-4 History 搜索、筛选、收藏、再翻译

问题：

历史现在只能浏览、复制、查看详情和清空。正式版本长期使用后，历史会成为复用入口。

范围：

- 搜索原文/译文。
- 按来源筛选：Quick Text、Screenshot，未来兼容 Selection。
- 收藏本地记录。
- 从历史记录重新打开 Quick Text 或直接按当前偏好再翻译。

验收：

- 50 条默认历史内搜索不卡顿。
- 收藏只保存本地 text-only 标记。
- 关闭历史保存后，不新增记录，但已有记录仍可搜索直到用户清空。

#### RC-P1-5 Screen Recording 权限恢复文案

问题：

权限错误窗口能打开系统设置，但没有充分解释授权后可能需要重新触发截图、重启 App、或 unsigned 包可能出现重复 `Parrot.app` 条目。

验收：

- 权限错误说明“授权后请重新触发 Screenshot Translation”。
- Release notes / FAQ 覆盖重复权限条目和 `tccutil reset ScreenCapture <bundle id>` 的高级修复路径。
- Quick Text 明确不需要 Screen Recording。

### 6.3 P2：发布后增强，不阻塞 RC

#### RC-P2-1 Translate Selection

价值明确，但涉及剪贴板副作用和跨 App smoke，不建议阻塞 RC。

进入条件：

- 复制/恢复剪贴板方案经过 Safari、Chrome、TextEdit/编辑器等至少 3 类 App 验证。
- 复杂剪贴板无法安全恢复时 fallback 到 Quick Text。
- 不保存来源 App、窗口标题或选区上下文。

#### RC-P2-2 自动下载与安装更新

RC-P0-7 先实现可解释的更新检测和下载入口。自动下载、自动安装或 Sparkle 集成需要更高的签名、公证和更新 feed 安全要求，不阻塞 RC。

进入条件：

- 已有 Developer ID 签名、公证和安全更新 feed。
- 更新失败有回滚说明和手动下载 fallback。
- unsigned dev 包不混入正式更新通道。
- 自动安装前必须展示版本、来源和用户确认。

#### RC-P2-3 工程拆分第二阶段

当前第一阶段 seam 已建立，后续可继续拆分 Keychain、Prompt、Glossary、Provider client、AppDelegate window/menu 协调，但不应压进 RC 主线。

进入条件：

- 每次拆分只移动一个职责。
- `Scripts/run-core-e2e.sh` 和 `./init.sh` 通过。
- 行为不变说明写入 feature notes。

## 7. 信息架构调整

### 7.1 菜单栏

建议 RC 菜单结构：

- `Quick Text Translation`
- `Screenshot Translation`
- `Translation History`
- `Pause/Resume Shortcuts`
- `Settings`
- `Quit Parrot`

原则：

- 菜单栏只保留用户最常用、最符合菜单栏工具习惯的入口：翻译、历史、快捷键暂停、设置和退出。
- `Setup Checklist`、`Onboarding Guide`、`About`、`Check for Updates` 和 `Send Feedback` 收进 Settings 或 Launch Hub，避免菜单栏变成长清单。
- `About`、`Check for Updates`、`Send Feedback` 属于发布可信入口，放在 Settings > About；Launch Hub 可以提供快捷入口，但不重复占用菜单栏。
- `Onboarding Guide` 放在 Settings > Setup / Onboarding，也可以从 Launch Hub 进入。
- `Check for Updates` 必须接入真实更新检测；如果更新 feed 尚未准备好，不在菜单栏或 Launch Hub 显示空壳入口。
- 页面置顶按钮属于窗口标题栏/页面顶栏动作，不建议放进菜单栏作为全局开关，避免误导为全 App 置顶。

### 7.2 Settings

建议 RC Settings 结构：

- `Setup`：配置健康检查与首次成功路径。
- `Model`：Provider、Base URL、Model、Timeout、API Key、连接测试。
- `Shortcuts`：Quick Text、Screenshot、Open Settings。
- `Translation`：语言、风格、Prompt、术语表、浮窗位置、长文策略说明。
- `Privacy`：历史开关、清空历史、截图/OCR/Provider/Keychain 边界说明。
- `Launch`：`Show Launch Hub on Startup`、`Show Dock icon`、默认启动入口说明和恢复入口策略。
- `About`：版本、build、bundle id、release notes、check for updates、feedback、diagnostics summary。
- `Onboarding`：可以作为 `Setup` 的引导模式，也可以作为独立入口，但不应和日常 Settings 表单重复成两套配置系统。

如果新增 `About` 导致 Settings 过重，可以做成独立窗口，但入口仍从 Settings 或 Launch Hub 打开，不单独占用菜单栏。

### 7.3 页面顶栏动作

所有用户可见窗口和页面使用一致的低干扰顶栏动作原则：

- Quick Text：`Pin on Top`、`History`、`Settings`，其中 `Pin on Top` 位于 `History` 左侧。
- Screenshot OCR/Translation：`Pin on Top`、`History`、`Settings`，其中 `Pin on Top` 位于 `History` 左侧。
- History：`Pin on Top`、必要的搜索/清空/关闭动作。
- Settings：`Pin on Top`、必要的帮助/关闭动作。
- About/Update/Feedback：`Pin on Top`、必要的复制/打开链接/关闭动作。

原则：

- 置顶是页面级状态，不是 App 全局状态。
- 按钮视觉应保持工具属性，优先使用 native toolbar button 或轻量 icon button。
- 置顶状态需要可见、可访问、可持久化，但不能抢占主操作。

### 7.4 启动状态机

Launch Hub、Onboarding 和 Setup 共享同一套启动判定，避免多窗口同时抢前台。

| 状态 | 启动行为 | 用户可恢复入口 |
| --- | --- | --- |
| 全新安装，未配置 Provider | 打开 onboarding 或 Setup 引导，优先完成 API Key、endpoint、model 和连接测试 | Settings > Setup / Onboarding |
| Provider 配置无效 | 打开 Setup 修复入口，不展示普通 Launch Hub | Settings > Setup |
| Provider 有效，onboarding 未完成 | 打开 onboarding；如果用户跳过，记录跳过状态但不视为完成 | Settings > Onboarding 或 Launch Hub |
| Provider 有效，onboarding 已完成，`Show Launch Hub on Startup` 开启 | 打开 Launch Hub | Settings > Launch |
| Provider 有效，用户关闭启动展示 | 不自动打开 Launch Hub，只保留菜单栏和快捷键 | Settings > Launch 恢复 |
| 版本升级，onboarding schema 未变化 | 不重复打扰，沿用用户原启动偏好 | Settings > About / Release Notes |
| 版本升级，onboarding schema 变化或有关键发布说明 | 展示轻量 release highlights 或 onboarding 更新页，不重复要求已完成的 API Key 配置 | Settings > About / Onboarding |
| `Show Dock icon` 开启 | 恢复 regular activation policy，但不改变 Launch Hub 展示偏好 | Settings > Launch |

## 8. 数据与隐私

### 8.1 继续保持的边界

- API Key 只保存在 macOS Keychain。
- 默认不上传截图图片。
- 默认只发送待翻译文本、命中术语和 Prompt 给用户配置的 Provider。
- 不保存截图图片、截图几何、窗口标题、来源 App 名或完整屏幕上下文。
- 历史记录继续是本地 text-only JSON，并允许关闭和清空。
- 不把待翻译文本、剪贴板内容、Provider 响应或错误原文写入诊断摘要。
- 更新检测只发送必要的 HTTP 请求到 release feed，不附带 API Key、Provider 配置、翻译内容、历史内容或截图。

### 8.2 允许新增的本地数据

- About / diagnostics summary 的非敏感配置快照。
- History 收藏标记、搜索状态或本地索引。
- 用户已读 release notes 的版本号。
- 用户是否主动关闭 RC onboarding 的非敏感状态。
- onboarding 完成状态、跳过状态和引导 schema version。
- 每个页面独立置顶偏好，例如 Quick Text、Screenshot OCR、History、Settings、About/Update。
- 更新检测的最近检查时间、最近看到的版本号和用户是否关闭每日自动检测。
- Launch Hub 启动展示偏好、最近展示版本、用户是否关闭启动展示。
- `Show Dock icon` 偏好，用于恢复用户选择的 activation policy。

### 8.3 不允许新增的数据

- 明文 API Key。
- 截图图片缓存。
- OCR 图片持久化。
- 自动上传日志。
- 用户翻译文本、Provider 返回文本、历史内容进入 diagnostics。
- 来源 App 名、窗口标题或完整屏幕上下文。
- 更新检测请求中携带用户文本、API Key、Provider endpoint、历史条目或 diagnostics summary。
- 把某个页面的置顶偏好扩散成全局置顶状态。
- 因 Launch Hub 或 Dock 图标开关记录当前前台 App、窗口标题、菜单栏布局、刘海屏状态或用户屏幕尺寸。

### 8.4 Diagnostics 字段白名单

`Copy Diagnostics Summary` 使用显式白名单，默认只包含：

- App version、build、bundle id、release channel。
- macOS version、architecture。
- Provider preset id 或 `custom` 标记，不包含 Base URL、endpoint host、model 自定义值或 API Key。
- Screen Recording permission status。
- History enabled、automatic update check enabled、Show Launch Hub on Startup、Show Dock icon 等布尔配置。

默认不包含 endpoint host。如果需要排查自建网关，后续可以增加用户显式勾选项，复制前必须展示将包含的字段。

### 8.5 更新 feed 契约

RC 更新检测支持 GitHub Releases API 或静态 HTTPS JSON feed，但必须先固定 feed schema。建议字段：

- `version`：SemVer 字符串。
- `build`：可选 build number。
- `channel`：`unsigned-rc`、`signed-stable` 或 `dev`。
- `isPrerelease`：布尔值。
- `releaseDate`：ISO 8601 日期。
- `minimumMacOS`：最低 macOS 版本。
- `summary`：短更新摘要。
- `releaseNotesURL`：HTTPS URL。
- `downloadURL`：HTTPS URL。
- `checksum` 或 `signature`：可选完整性元数据。

解析规则：

- 当前版本等于 latest：显示 `Up to Date`。
- 当前版本高于 latest：显示本地版本较新，不提示降级。
- feed channel 与当前 release channel 不匹配：说明当前通道限制，不展示自动更新入口。
- 无 checksum 或 signature 元数据：只提供手动下载链接，不暗示 App 已验证安装包。
- 网络、rate limit、无效 JSON、字段缺失和 minimum macOS 不满足时，都显示 `Unable to Check` 的可理解原因，不影响翻译主流程。

## 9. 发布门槛

### 9.1 RC 可发布门槛

- 已记录本次 release lane：`unsigned public RC` 或 `public signed release`。
- `./init.sh` 通过。
- `Scripts/run-core-e2e.sh` 通过。
- `Scripts/package-release.sh --allow-untagged` 通过。
- README、Release Notes、Privacy/About 文案与当前实现一致。
- 所有 UI/UX 改动都记录 `DESIGN.md` 对齐结果；如有例外，必须说明原因和影响范围。
- 缺 API Key、认证失败、Base URL 无效、网络超时、Screen Recording 未授权、OCR 无文本、长文超限均有可操作恢复路径。
- 首次安装 onboarding 可完成 Provider 配置、连接测试、快捷键认知和 Quick Text 首译。
- 首次启动和已配置后启动均有可靠前台入口：onboarding 或 Launch Hub；关闭启动展示后可从 Settings 恢复。
- Settings 提供 `Show Dock icon`，开启后 Parrot 可在 Dock/App Switcher 中被发现，关闭后恢复菜单栏工具形态。
- `Check for Updates` 能返回最新版、可更新和失败三类状态，并有下载/Release Notes 入口。
- Quick Text、Screenshot OCR、History、Settings、About/Update 等页面均有独立置顶按钮和互不影响的持久化状态。
- 历史清空有确认或撤销。
- 若仍为 unsigned RC，所有用户入口清楚标注 unsigned 限制。
- 若走 signed release，必须同时满足 9.2；若走 unsigned RC，不能使用 signed/stable channel 文案。

### 9.2 Public signed release 门槛

- 使用正式 bundle identifier，不再是 `com.example.parrot`。
- Developer ID Application 签名配置完成。
- Notarization 和 stapling 完成。
- `spctl` 验证通过。
- 从旧 unsigned 包升级的 Screen Recording 和 Keychain 行为有验证记录。
- 更新检测 feed 使用 HTTPS，release asset、checksum 和 channel 文案与签名策略一致。
- GitHub Release 包含 `.dmg`、`.zip`、`SHA256SUMS.txt`、release notes 和隐私说明。

## 10. 验证计划

### 10.1 自动化

- 记录 `git rev-parse HEAD` 和 `git status --short --branch -uall`，作为 PRD 落地与验证基线。
- `./init.sh`
- `Scripts/run-core-e2e.sh`
- `Scripts/package-release.sh --allow-untagged`
- `shasum -a 256 -c SHA256SUMS.txt`
- `codesign --verify --deep --strict`
- signed release 模式下增加 `spctl --assess --type execute`
- 更新检测 feed fixture：最新版、可更新、网络失败、无效 JSON、低于 minimum macOS。
- 更新检测 feed fixture：channel 不匹配、本地版本较新、缺 checksum/signature、GitHub rate limit。
- 置顶偏好源码链接测试：每个 surface 独立读写，不互相污染。
- Launch preference 测试：首次启动展示、关闭启动展示、Settings 恢复、已配置用户展示 Launch Hub。
- Dock icon preference 测试：`Show Dock icon` 开关持久化并驱动 activation policy。
- UI 源码或 smoke 覆盖：菜单栏短清单、Settings 分区、About/Update、Onboarding、Launch Hub、错误态、loading、空状态和置顶按钮均符合 `DESIGN.md` 的 native、低干扰和可访问性要求。

### 10.2 手动 smoke

- 首次启动缺 API Key：打开 Setup，保存 API Key，测试连接，完成 Quick Text 首译。
- 首次安装 onboarding：从欢迎页到连接测试、快捷键认知、首译、可选 Screenshot OCR 权限跳过/授权。
- 已配置后启动：不依赖菜单栏图标，Launch Hub 前台可见，并能打开 Quick Text、Screenshot OCR、History 和 Settings。
- Dock 图标开关：开启后 Dock/App Switcher 可见，关闭后恢复菜单栏工具形态，重启后保持选择。
- Provider 错误：无效 Base URL、错误模型、认证失败、超时，确认翻译窗口内 CTA 可达。
- Screenshot：首次无 Screen Recording、授权后重试、框选大区域 OCR loading、OCR 无文本、OCR 成功自动翻译。
- History：新增记录、复制、详情、清空确认或 Undo、关闭历史后不新增。
- Privacy/About：版本信息正确，diagnostics summary 不含用户文本和 secret，Check for Updates 三种状态可达。
- Always on Top：Quick Text、Screenshot OCR、History、Settings、About/Update 分别切换置顶，确认每个页面互不影响并在重启后恢复。
- DESIGN.md 对齐：检查 light/dark、长文本、空状态、错误态、loading、菜单栏短清单、Settings 信息密度和 Launch Hub 前台展示，确认没有新增重装饰、硬编码 web 色值、非原生字体或不必要动画。
- Release：从 DMG 安装、首次启动、权限引导、退出重启、覆盖安装升级。

## 11. 风险与应对

| 风险 | 影响 | 应对 |
| --- | --- | --- |
| RC 继续扩功能导致回归 | 已有高频路径变慢或变复杂 | 同版本内按 gate 推进，先完成发布路线、首译和失败恢复，再做窗口层级与 Dock 图标 |
| 签名/公证准备不足 | 用户无法顺利安装或授权 | 把 public signed release 作为明确决策门，不混入普通功能 |
| About/diagnostics 泄漏隐私 | 破坏产品信任 | 只允许版本、系统、权限状态和非敏感配置，不包含用户文本 |
| 更新检测制造安全感假象 | 用户误以为 App 已验证或可自动安装更新 | feed 缺 checksum/signature 时只做手动下载，不展示自动安装文案 |
| OCR 异步化引入旧结果回写 | 关闭窗口后仍更新 UI | 复用 request id / active window gating 思路，增加 fake OCR 验证 |
| Settings 校验过严 | 合法 OpenAI-compatible endpoint 被误拒 | 复用现有 endpoint normalizer，允许 root、`/v1`、完整 endpoint |
| 历史确认增加摩擦 | 高频清理变慢 | 只对 destructive clear 增加确认，复制和查看不变 |
| 更新 feed 不可用 | 用户无法判断是否有新版本 | 显示 `Unable to Check`，保留 Release Notes 手动链接，不影响翻译功能 |
| 自动检测过度打扰 | 用户在工作流中被更新提示打断 | 默认主动检查优先；如启用自动检测，限制每日一次并仅在 About/Menu 显示温和状态 |
| Onboarding 变成阻塞墙 | 已会用的用户被迫重复设置 | 支持跳过、重新打开和已配置状态短路，不阻塞菜单栏核心入口 |
| 页面置顶层级失控 | 多窗口互相遮挡或难以关闭 | 每个 surface 独立偏好，只调整当前窗口 level，保留 Esc/Close/Quit |
| Launch Hub 打扰熟练用户 | 用户希望 Parrot 保持隐形工具属性 | 提供 `Don't show this on startup` 和 Settings 恢复开关，默认只解决新用户入口断裂 |
| Dock 图标改变产品感知 | 菜单栏工具变得像常规 App | `Show Dock icon` 默认关闭，只作为用户主动开启的可发现性补充入口 |
| Activation policy 切换不稳定 | 窗口无法前台展示或 Dock 状态残留 | 把 activation policy 切换集中封装，覆盖启动、开关切换、重启恢复和 Quit 场景 |

## 12. 推荐实施顺序

1. RC-P0-6 正式分发签名决策。
2. RC-P0-3 Settings 保存前校验。
3. RC-P0-1 翻译错误恢复 CTA。
4. RC-P0-4 App 内 About / Privacy / Feedback。
5. RC-P0-5 README 与 Release Notes 更新。
6. RC-P0-8 用户首次安装后的使用引导。
7. RC-P0-10 启动入口保障 / Launch Hub。
8. RC-P0-2 截图 OCR 异步 loading。
9. RC-P0-7 软件检测和更新功能。
10. RC-P1-1 历史清空确认或撤销。
11. RC-P0-9 所有页面独立置顶按钮。
12. RC-P1-2 / RC-P1-3 文案 polish。
13. RC-P0-10 中的 `Show Dock icon` 后置接入与真实 smoke。

理由：

- 签名和发布路线会影响 About、README、Release Notes、更新检测、安装说明和 TCC/Keychain 升级说明，必须先确认。
- 先拦截坏配置，再改翻译窗口恢复路径，能最快降低失败率。
- About/Privacy/Feedback 和 README 先形成可信说明，再承接 onboarding、Launch Hub 和更新检测中的跳转入口。
- Onboarding 与 Launch Hub 共用启动状态机，先做 onboarding 的首译路径，再做 Launch Hub，能减少双窗口和重复打扰。
- OCR loading 涉及异步状态回写，放在错误恢复和请求生命周期稳定后接入。
- 更新检测依赖 release channel 和 feed 契约，必须在发布路线和 About 文案确定后实现。
- 页面置顶和 Dock 图标都改变窗口层级或 activation policy，放在后段并要求真实 macOS smoke。

## 13. 待确认问题

1. 本次“正式发布”目标是 public signed release，还是 unsigned public RC？
2. 是否已有正式 bundle identifier、Apple Developer Team、Developer ID 证书和 notarization credentials？
3. Feedback 入口优先使用 GitHub Issues、邮件，还是未来自建反馈表单？
4. Diagnostics summary 是否允许用户显式勾选包含 sanitized endpoint host，还是永久禁止 endpoint host？
5. History 清空更偏好二次确认，还是短时 Undo？
6. 更新检测源使用 GitHub Releases API、静态 HTTPS JSON feed，还是两者都支持？
7. 是否启用每日一次的轻量自动检测，还是只允许用户手动 `Check for Updates`？
8. Onboarding 是否在每个重大版本展示一次 release highlights，还是只在首次安装展示？
9. 页面置顶偏好是否按 surface 持久化到下次启动，还是只在当前会话有效？
10. Launch Hub 是否默认对所有已完成 onboarding 的启动展示，还是只在首次安装和前 N 次启动展示？
11. `Show Dock icon` 是否默认关闭并只由用户主动开启？当前建议默认关闭。
12. Dock 图标开启后，关闭最后一个窗口是否仍保持 App 运行？当前建议保持运行，只通过 `Quit Parrot` 退出。

## 14. 结论

Release Candidate 应聚焦“入口可见、用户第一次能成功、失败能恢复、发布可信任、更新可触达、窗口可控”。最值得增加的不是云同步、团队能力或多模态截图上传，而是配置校验、错误 CTA、Launch Hub、首次安装引导、可选 Dock 图标、OCR loading、页面独立置顶、About/Privacy/Feedback、软件检测和更新入口、README/Release Notes、历史清空保护和签名发布决策。只有这些基础体验稳定后，`Translate Selection`、历史搜索收藏、自动下载/安装更新和更深工程拆分才适合进入后续版本。
