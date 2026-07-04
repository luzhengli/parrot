# Parrot V2 产品化与长文效率 PRD

版本：0.4 Draft  
日期：2026-07-04  
平台：macOS  
适用范围：MVP/V1 已实现后的下一版本规划  
前置文档：`Docs/ai-translation-macos-prd.md`、`Docs/ai-translation-macos-v1-prd.md`  
当前依据：当前代码、`feature_list.json`、`parrot-progress.md`、`DESIGN.md`

审查方式：本版已按对抗性审查结果收敛范围，重点防止 V2 变成“长文、选中文本、历史、分发、工程治理同时开工”的大版本。本文把高风险能力拆成 V2.0 必做项、V2.1 增强项和 V2.x 决策门，并为隐私、权限、取消、验收和降级路径补充硬边界。

## 1. 背景

Parrot 当前已经完成菜单栏常驻、全局快捷键、截图 OCR 翻译、快捷文本翻译、Provider 设置、Keychain 密钥、翻译历史、自定义快捷键、语言选择、翻译风格、自定义 Prompt、术语表、OCR 原文编辑、浮窗位置偏好和一轮高保真 UI/UX 重构。

因此下一版不应继续重复 MVP/V1 的设置项建设，而应解决从“可用原型”到“可长期日常使用工具”的缺口：

- 首次配置、权限、Provider 可用性和分发仍需要更完整的产品化闭环。
- 长文本、代码块、报错堆栈、论文段落等输入会遇到 token、延迟、取消和结果组织问题。
- 用户在真实工作流中经常已经选中了文本，希望少一步复制粘贴。
- 当前工程已出现大文件和脚本式验证沉淀，后续继续加功能前需要提高可维护性。
- unsigned 内测包已可生成，但正式对外分发仍缺 Developer ID 签名、notarization 和更清晰的升级/权限说明。

V2 的核心目标是把 Parrot 做成一个稳定、可分发、适合每天高频使用的 macOS 翻译工具，而不是扩展成完整 CAT 工作台或云协作产品。

## 2. 产品定位

一句话定位：

> 任何地方遇到外语内容，Parrot 能以最少打断完成理解、校对和复制。

V2 关键词：

- 产品化
- 稳定可恢复
- 长文可控
- 选中文本更快
- 本地优先隐私
- 可维护演进

## 3. 目标用户

### 3.1 核心用户

- 高频阅读英文资料、技术文档、论文、网页和软件界面的中文 macOS 用户。
- 经常处理中英双语文本的研发、产品、设计、运营和研究人员。
- 自带 OpenAI-compatible API Key，愿意配置模型但不想进入复杂翻译工作台的高级用户。
- 需要翻译不可复制 UI 截图、报错、图片文字，也需要翻译可复制长文本的效率用户。

### 3.2 重点场景

- 初次安装后，用户能明确知道还缺 API Key、屏幕录制权限或网络配置，并一步步完成。
- 阅读长文、报错堆栈或 PR 描述时，用户可以粘贴或输入大段文本，看到分段进度和合并结果。
- 在浏览器、编辑器、聊天软件中选中一段文本后，用户用快捷键直接翻译，无需手动复制再打开 Quick Text。
- Provider 速度慢、流式请求卡住或用户关闭窗口时，请求能取消并停止回写。
- 用户更新安装包后，屏幕录制权限、Keychain 和历史数据行为可预期，不出现重复身份或隐私误解。

## 4. 版本目标

### 4.1 V2 目标

- 完成首次启动和配置健康检查闭环，降低“能打开但不能翻译”的失败率。
- 支持长文本分段翻译，提供进度、取消、失败恢复和合并结果。
- 支持选中文本翻译作为 Quick Text 的更快入口，并保留复制粘贴 fallback。
- 补齐翻译请求生命周期管理，包括取消、超时、重试、窗口关闭后的安全回收。
- 提供必要的 Provider 高级参数和端点兼容修复，减少 OpenAI-compatible 服务接入失败。
- 建立正式测试 target 或等价可持续测试层，拆分超大核心文件，降低后续迭代风险。
- 明确 V2 是否进入正式分发准备：稳定 bundle id、Developer ID 签名、notarization 和发布说明。

### 4.2 成功标准

- 首次配置后，用户能在 3 分钟内完成 API Key、连接测试和截图权限理解。
- 2000-8000 字符长文本可以稳定翻译，用户能看到分段进度并可随时取消。
- 选中文本翻译在支持的 App 中比手动复制粘贴减少至少 1 次显式操作。
- 关闭翻译窗口或点击取消后，不再继续消耗 Provider 请求或向已关闭窗口回写。
- 常见 Provider 接入错误能在 Settings 中定位到 Base URL、模型、超时、认证或端点格式问题。
- 新增核心逻辑必须有可重复自动化验证；不能只依赖一次性源码链接脚本。

### 4.3 V2.0 发布门槛

V2.0 只在以下条件同时满足时才算可发布：

- Quick Text 和 Screenshot Translation 的现有路径没有变慢、变重或增加额外权限。
- 翻译请求具备统一取消语义：用户关闭窗口、点击取消、触发新请求或按 Esc 后，请求停止、UI 不再回写、历史不再写入。
- Provider 配置错误能被归类到 Base URL、模型、API Key、网络、超时或服务商错误，且不会泄漏 API Key、Bearer token 或其它 token-like 文本。
- 长文本分段在 2000-8000 字符范围内有可重复验证，超过上限时必须给出明确提示或二次确认，不能静默发起不可控请求。
- 新增纯逻辑至少进入 XCTest target 或稳定脚本聚合入口，并能在一次命令中重复运行。

V2.0 不默认阻塞于 `Translate Selection`、历史搜索/收藏、Developer ID 签名、公证、自动更新或自定义 Header。这些能力必须满足各自决策门后进入 V2.1 或 V2.x。

## 5. 非目标

V2 不做以下能力：

- 团队协作、云同步术语库、账号系统或权限管理。
- 专业 CAT 工具能力，例如翻译记忆库、句段确认和项目管理。
- 默认上传截图图片给多模态模型。
- 原位覆盖翻译的完整视觉还原。
- 跨平台版本。
- 内置付费模型服务、订阅和 license 系统。
- 自动更新框架，除非本版本明确进入正式分发准备并单独评估。

## 6. 推荐范围与优先级

### 6.1 P0：产品化可靠性

#### 6.1.1 首次启动与配置健康检查

用户第一次启动或配置异常时，Parrot 应展示一个轻量 onboarding/checklist，而不是只打开 Settings。

能力要求：

- 检查 Provider 是否已配置非秘密 API Key setup record。
- 检查当前 Provider Base URL、模型名、连接测试状态。
- 检查屏幕录制权限状态，并解释截图翻译为什么需要该权限。
- 展示 Quick Text、Screenshot Translation、Settings 的当前快捷键。
- 提供最短路径：配置 API Key、测试连接、查看快捷键、开始第一次翻译。
- 不强制用户授权屏幕录制；如果只使用 Quick Text，可以跳过。
- checklist 只在首次启动、缺关键配置或用户从菜单主动打开时出现，不应每次启动打断已配置用户。

验收标准：

- 缺 API Key 时启动后进入 onboarding/checklist，用户能从同一入口保存并测试 Provider。
- 未授予屏幕录制时，Quick Text 可继续使用，Screenshot Translation 明确标记不可用或需要授权。
- checklist 不保存 API Key 到 UserDefaults，不上传截图，不改变现有 Keychain 边界。

#### 6.1.2 翻译请求取消与窗口生命周期

当前 Quick Text 和 Screenshot Translation 使用流式请求，但缺少显式取消句柄。V2 应把取消作为可靠性基础设施。

能力要求：

- 建立统一的 `TranslationRequestCoordinator` 或等价请求状态层，用 request id 绑定窗口、Provider 请求、UI 回写和历史写入。
- 用户点击 Cancel、Close、Esc 或窗口关闭时取消正在进行的流式请求。
- 用户连续触发 Again/Retry 时，取消上一轮未完成请求。
- 请求取消后不写入历史记录。
- 请求取消后 UI 显示可理解状态，而不是错误栈或空白。
- 取消与网络失败、认证失败、超时失败区分展示。
- 取消后必须阻断旧请求回写，即使底层 URLSession 或流式回调稍后才返回。

验收标准：

- 慢响应 Provider 下，关闭窗口后不会继续追加译文或写历史。
- 连续两次翻译只保留最后一次请求结果。
- 取消状态不触发错误提示轰炸，用户可重新翻译。
- 用可控 fake streaming provider 覆盖：延迟 token、取消、重试、窗口关闭和旧 request id 回调晚到。

#### 6.1.3 Provider 兼容性与高级参数

OpenAI-compatible Provider 差异较大，V2 应补齐必要的高级参数，但不能把 Settings 变成复杂控制台。

能力要求：

- V2.0 必须支持请求超时设置，默认保持当前行为。
- 支持 Base URL 端点规范化：用户输入根路径、`/v1` 或完整 `/chat/completions` 时都给出正确行为或明确提示。
- 支持连接测试展示原始 HTTP 状态和清洗后的服务商错误摘要。
- V2.1 可支持 temperature 和 max tokens，放入 Advanced 区域，默认值不改变当前请求行为。
- 自定义 Header 暂缓到 V2.x。除非单独完成安全设计，否则不允许保存可能包含 secret 的 Header。

验收标准：

- 常见 Base URL 误填不会静默变成重复 `/chat/completions/chat/completions`。
- 超时设置能影响 Quick Text 和 Screenshot Translation 的真实请求。
- Provider 错误不泄漏 API Key 或 token-like 文本。
- 连接测试和真实翻译共用同一套 Base URL 规范化规则，避免“测试成功、翻译失败”的分叉。

### 6.2 P1：长文与更快入口

#### 6.2.1 长文本分段翻译

长文本不应一次性全部塞进请求导致超时或超 token。V2 支持按段落/长度分段翻译，并合并为可复制结果。

能力要求：

- 默认阈值建议为 2000-3000 字符；低于阈值保持当前单请求流式体验。
- 2000-8000 字符进入分段模式；超过 8000 字符先提示风险或要求用户手动确认，不能静默发起大量请求。
- 按段落优先切分；代码块、URL、变量名和 Markdown 结构尽量保持完整。
- 展示分段进度，例如 `Translating 2/6`。
- 支持取消剩余段落。
- 某一段失败时保留已完成段落，并允许重试失败段。
- 合并结果保留原有段落结构。
- 默认顺序执行分段请求，避免并发放大 Provider 费用、限流和取消复杂度；并发优化必须单独评估。

验收标准：

- 2000-8000 字符混合中英文、Markdown、代码块输入能完成翻译并复制完整结果。
- 分段翻译不会把截图图片、截图几何或 API Key 写入历史。
- 历史记录保存最终合并文本，并可在详情中查看完整内容。
- 取消第 N 段时，已完成段落可以保留在当前 UI，但不写入成功历史；重新开始时不会复用已取消请求的旧回调。

#### 6.2.2 选中文本翻译

用户在其他 App 已经选中文本时，应能直接触发翻译，减少复制粘贴步骤。

V2.0 不默认承诺该能力。它只有在剪贴板副作用、权限提示和跨 App smoke 通过后进入 V2.1。

推荐方案：

- 默认使用隐私更清晰的剪贴板保存/恢复策略：触发时模拟复制当前选区、读取剪贴板文本、恢复原剪贴板内容，再打开 Quick Text 或直接翻译。
- 如果系统权限或目标 App 阻止复制，则 fallback 到现有 Quick Text 输入窗口，并提示用户手动粘贴。
- 不默认使用不可控的全局 Accessibility 文本读取，除非后续验证稳定且隐私提示充分。
- 仅响应用户显式快捷键或菜单动作，不做后台监听，不记录来源 App、窗口标题或选区上下文。

能力要求：

- 新增 `Translate Selection` 菜单项和可配置快捷键。
- 选区文本读取成功时，直接进入 Quick Text 翻译流程并自动开始翻译。
- 读取失败时打开 Quick Text 并显示“未读取到选中文本，可粘贴后翻译”。
- 尽量恢复用户原剪贴板内容，避免破坏工作流。
- 剪贴板恢复仅允许使用内存中的临时快照，不写入日志、历史、UserDefaults 或诊断文件。

验收标准：

- 在 Safari/Chrome/文本编辑器/常见编辑器中至少覆盖 3 类 App 的选中文本翻译 smoke。
- 原剪贴板有文本时，触发后能恢复或清晰记录无法恢复的边界。
- 该功能不保存选区来源 App 名、窗口标题或上下文截图。
- 原剪贴板包含图片、文件或富文本时，要么完整恢复，要么不读取选区并 fallback，不能把复杂剪贴板降级成纯文本后覆盖用户数据。

#### 6.2.3 历史搜索、收藏与再翻译

V1 历史已可查看和清空，V2 可以让历史成为轻量复用入口，但不做完整知识库。

能力要求：

- 支持按原文/译文搜索历史。
- 支持按来源类型筛选：Quick Text、Screenshot、Selection。
- 支持收藏常用记录。
- 支持从历史记录一键再次翻译，使用当前语言、风格、Prompt 和术语设置。

验收标准：

- 长历史列表不会卡顿或布局溢出。
- 关闭历史保存后，不新增记录，但已有记录仍可搜索直到用户清空。
- 收藏只保存本地 text-only 数据。

### 6.3 P2：分发与工程可维护性

#### 6.3.1 正式分发准备

当前 release package 是 unsigned/unnotarized 内测能力。V2 如果要对外使用，应进入正式分发准备。

该项是 V2.x 决策门，不是 V2.0 默认交付项。只有当产品目标从个人/小范围内测切换为对外分发时才启动。

能力要求：

- 确认正式 bundle identifier，不再使用 `com.example.parrot`。
- 配置 Developer ID Application 签名。
- 增加 notarization 和 stapling 流程。
- 生成用户可读的隐私说明、首次权限说明和安装/升级说明。
- 验证从旧 unsigned 包升级到正式签名包时，Screen Recording TCC 和 Keychain 行为可解释。
- 正式 bundle identifier、签名团队、版本号和自动更新策略必须单独确认，不能作为普通功能 PR 顺手修改。

验收标准：

- `Scripts/package-release.sh` 支持正式签名/公证路径，仍保留本地 unsigned validation。
- 正式包通过 `spctl` 验证。
- release notes 清楚说明权限、Keychain、历史数据和截图不上传策略。

#### 6.3.2 工程拆分与测试体系

随着功能增多，V2 必须降低后续维护成本。

能力要求：

- 当前 `ProviderSettings.swift` 已超过 1800 行，`ScreenshotSelectionController.swift` 超过 1000 行，`ProviderSettingsView.swift` 超过 800 行。拆分应先建立测试 seam，再分阶段移动代码，避免一次性大搬迁。
- 第一阶段拆分 `ProviderSettings.swift`：Provider client、Keychain secrets、Translation preferences、Glossary、Prompt rendering、Window placement 分文件。
- 第二阶段拆分 `AppDelegate.swift` 的窗口协调、状态栏菜单和快捷键回调职责。
- 移除或明确标记已经边缘化的 scaffold `ContentView`。
- 建立 XCTest target 或稳定的脚本聚合入口，把现有 `Scripts/*-e2e.swift` 纳入可重复验证。
- 修复 SwiftUI `Settings` scene 与 AppDelegate 菜单 Settings 入口能力不一致的问题。
- 工程拆分不得改变 Provider 请求、Keychain、历史、OCR、窗口默认行为和快捷键语义。

验收标准：

- 拆分后功能行为不变，`./init.sh` 和现有 E2E 脚本通过。
- 新增至少一个自动化入口可一键运行核心纯逻辑测试。
- Settings 从系统入口和菜单栏入口打开时能力一致。
- 每次拆分 PR 必须说明移动了哪些职责、哪些行为未改变、运行了哪些回归。

## 7. 信息架构调整

### 7.1 菜单栏

新增或调整，按功能实际落地分批出现，不能提前展示不可用空壳入口：

- `Translate Selection`
- `Quick Text Translation`
- `Screenshot Translation`
- `Translation History`
- `Setup Checklist` 或 `Configuration Health`
- `Settings`
- `Pause/Resume Shortcuts`
- `Quit Parrot`

### 7.2 Settings

建议分区：

- `Model`：Provider、API Key、连接测试、高级参数。
- `Shortcuts`：Quick Text、Screenshot、Translate Selection、Open Settings。
- `Translation`：语言、风格、Prompt、术语表、长文分段策略。
- `History` 或 `Privacy`：历史保存、搜索/收藏说明、本地数据清理。
- `About`：版本、隐私说明、release channel、诊断信息导出。

注意：如果新增分区导致 Settings 变重，应优先保留当前左侧导航壳，不做多层复杂设置。
注意：V2.0 只展示已实现或即将配置生效的设置项。temperature、max tokens、自定义 Header、release channel 和诊断导出不能提前放入 UI 作为占位。

## 8. 数据与隐私

### 8.1 继续保持的边界

- API Key 只保存在 macOS Keychain。
- 默认不上传截图图片。
- 默认只发送待翻译文本、命中术语和 Prompt 给用户配置的 Provider。
- 不保存截图图片、截图几何、窗口标题、来源 App 名或完整屏幕上下文。
- 历史记录继续是本地 text-only JSON，并允许关闭和清空。
- 不把待翻译文本、剪贴板内容、Provider 响应或错误原文写入自动诊断日志。

### 8.2 新增本地数据

允许新增：

- 长文分段配置，例如自动分段阈值、每段最大字符数。
- 选中文本翻译快捷键配置。
- 历史收藏标记和本地搜索索引。
- Provider 高级参数：timeout、temperature、max tokens。
- 翻译请求本地状态：request id、分段序号、取消状态和 UI 进度。该状态只服务当前会话，不作为长期用户画像保存。

不允许新增：

- 明文 API Key。
- 截图图片缓存。
- 选区来源 App/窗口标题记录。
- 自动上传日志或诊断数据。
- 自定义 Header 中的 secret-like 内容，除非后续版本单独设计 Keychain 存储、脱敏展示和迁移策略。

## 9. 用户体验要求

- 保持“即用即走”：任何新增能力都不能让 Quick Text 和 Screenshot 默认路径变慢或变重。
- 保持键盘优先：Translate Selection、Cancel、Retry、Copy、Esc 都应有清晰键盘路径。
- 长文翻译必须可取消，不能把用户困在不可中断 loading 中。
- 错误提示要可行动：告诉用户是权限、Provider、网络、超时、取消还是内容为空。
- UI 遵循 `DESIGN.md` 的 disappearing utility：原生控件、系统字体、低装饰、清晰密度。
- 所有新增入口必须有失败 fallback：长文可回到单请求或手动缩短，选中文本可回到 Quick Text 手动粘贴，Provider 高级设置可恢复默认。

## 10. 风险与应对

| 风险 | 影响 | 应对 |
| --- | --- | --- |
| V2 范围膨胀 | 多条高风险主线同时开工，导致现有高频路径回归 | V2.0 只做可靠性、Provider 兼容、长文最小闭环和测试 seam；Selection、历史增强、正式分发进入后续版本 |
| 长文分段破坏上下文 | 译文前后不一致 | 按段落切分并在 Prompt 中提供段落序号和整体说明，必要时允许用户回退单请求 |
| 选中文本读取不稳定 | 不同 App 行为不一致 | 使用复制 fallback，失败时打开 Quick Text；先覆盖常见 App，不承诺所有 App |
| 剪贴板恢复失败 | 打断用户工作流或覆盖用户原剪贴板 | 复杂剪贴板无法安全恢复时直接 fallback；临时快照只在内存中存在，不写入持久化或日志 |
| Provider 高级参数过多 | Settings 复杂化 | 放入 Advanced 折叠区，默认值保持当前行为 |
| 正式签名切换影响 TCC/Keychain | 用户升级后重新授权 | 在 release notes 和 onboarding 中解释升级影响，并做升级 smoke |
| 工程拆分引入回归 | 已有功能被破坏 | 先补测试 seam，再小步拆分，每步运行 `./init.sh` 和核心 E2E |
| 取消实现只停 UI 不停网络 | 继续消耗 Provider 请求或旧 token 回写 | 用 request id、Task 取消和 fake streaming provider 验收旧请求不会回写或写历史 |

## 11. 版本拆分建议

### 11.1 V2.0 推荐必须做

1. 翻译请求取消与窗口生命周期。
2. Provider Base URL 规范化和超时设置。
3. 首次启动与配置健康检查。
4. 长文本分段翻译。
5. 工程拆分第一阶段和测试聚合入口。

V2.0 明确不默认包含：`Translate Selection`、历史搜索/收藏、temperature、max tokens、自定义 Header、Developer ID 签名、公证、自动更新和 release channel。

### 11.2 V2.1 推荐增强

1. 选中文本翻译。
2. 历史搜索、筛选、收藏和再翻译。
3. Provider temperature、max tokens 等高级参数。
4. Settings 系统入口与菜单栏入口一致性修复。

### 11.3 V2.x 视目标决定

1. Developer ID 签名和 notarization。
2. About、隐私说明和诊断导出。
3. 自动更新或 release channel。

## 12. 明确暂缓的方向

- 原位覆盖翻译：价值明确但实现复杂，且需要处理截图布局、字体、遮挡和多语言排版，暂不进入 V2 主线。
- 图片直接多模态翻译：会改变“默认不上传截图”的隐私承诺，除非用户显式开启并单独设计权限说明。
- 团队术语库和云同步：超出个人 macOS 菜单栏工具边界。
- 内置付费模型服务：涉及账号、计费、合规和支持成本，不适合当前下一版。

## 13. 待确认问题

1. V2.0 是否只按本文收敛后的可靠性版本推进，正式对外分发是否另开 V2.x 决策门？
2. `Translate Selection` 是否接受剪贴板临时读写方案，并允许在复杂剪贴板无法安全恢复时直接 fallback？
3. 长文分段默认阈值希望偏保守还是偏自动？建议初始阈值为 2000-3000 字符后进入分段确认或自动分段。
4. V2.1 的 temperature 和 max tokens 是否足够，还是仍需要自定义 Header？如果需要 Header，必须先确认 secret 存储和脱敏策略。
5. 工程测试层优先采用正式 XCTest target，还是先保留脚本聚合入口再逐步迁移到 XCTest？

## 14. 结论

V2 推荐主题是“产品化与长文效率”，但 V2.0 必须先是一个收敛的可靠性版本。最值得优先做的不是更多设置项，而是让已有高频路径更可靠：首次配置更清楚、请求可取消、Provider 更兼容、长文本可控、工程更可维护。`Translate Selection`、历史增强和正式分发都有价值，但应在 V2.0 稳定后按独立决策门推进，避免同时扩大权限、剪贴板、分发和工程风险。
