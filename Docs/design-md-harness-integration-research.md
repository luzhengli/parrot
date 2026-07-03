# DESIGN.md 与 /Design 资产的 Parrot Agent Harness 集成方案

日期：2026-07-03
状态：可落地集成方案（本文件本身只是文档；不包含产品代码、Xcode 配置或签名变更）

> 修订说明（2026-07-04）：`Design/` 目录仍作为条件参考资产保留，但每个页面只以 `code.html` 作为高保真原型源。早前文档中关于静态导出图和原型配对的要求已作废。**当前仓库实际状态**：根目录已存在 `DESIGN.md`（Google `design.md` 格式，主题 “Invisible Utility”），且 `Design/` 目录存在，含 `quick_text_translation/`、`screenshot_translation/`、`settings/` 三个页面，每个页面各有一份 `code.html`（Tailwind 高保真原型）。原型 HTML 的 Tailwind 配置直接引用 `DESIGN.md` 的 tokens，说明 `/Design` 在事实上已经“遵循 `DESIGN.md`”。本文以该现状为准，给出可执行的 harness 集成方案。

---

## 0. 结论先行（核心摘要）

1. **两类资产、两种触发强度，必须分开对待：**
   - `DESIGN.md`（根目录）= Parrot 的**唯一强制设计语言来源**。**任何涉及 UI/UX 的新功能或重构都必须先读它并对齐**，属于“条件强制触发”（触发条件 = 涉及 UI）。
   - `/Design`（HTML 原型）= **仅供未来某一次一次性重构参考的视觉资产**。它**迭代频繁且滞后于真实代码**，因此在日常 feature 开发中**默认不触发、不得作为实现依据**，只有用户显式点名时才引用（“显式条件触发”）。

2. **冲突取舍固定优先级**（高→低）：用户显式指令 > 隐私/安全/macOS 权限/Keychain > PRD 产品行为（仅限“做什么/交互约束/隐私边界”，**不含视觉呈现**）> macOS 原生 HIG > `DESIGN.md` > 当前已实现代码的既定形态。**UI/视觉层面不参考 PRD**：PRD 同样滞后于代码，其界面描述可能过时，视觉一律以 `DESIGN.md` + 当前代码为准。而 **`/Design` 原型不参与日常裁决**；当它与当前代码或 `DESIGN.md` 冲突时，**一律以当前代码和 `DESIGN.md` 为准**。

3. **`/Design` 遵循 `DESIGN.md`，不是反过来。** `DESIGN.md` 是规范源（tokens + 理由），`/Design` 是该规范在特定重构目标下的一次性视觉演绎。规范变更以 `DESIGN.md` 为准，原型只能跟随。

4. **本轮只需 4 处 harness 改动即可落地**（详见第 3 节）：
   - `AGENTS.md` 新增 “Design Harness” 一节（路由 + 强制/条件触发 + 冲突原则）。
   - `feature_list.json` 新增 `foundation.design-system-harness` feature，并给 UI 类 feature 追加设计验收话术。
   - `parrot-progress.md` 记录设计 harness 的落地、版本、验证方式与已知例外。
   - `/Design/README.md`（新增）：作为原型资产索引，写明“未来重构参考、非当前状态、滞后于代码、遵循 DESIGN.md”。

5. **`DESIGN.md` 是团队级共享设计契约，不是临时 prompt 上下文**：它必须固定命名为根目录 `DESIGN.md`、纳入版本控制、保持稳定，不能每个 session 或每个 feature 随手调整。只有明确的品牌、视觉方向、token、组件原则变化才更新它。

6. **不把设计工具链塞进默认构建，但保留验收检查**：不把 `@google/design.md` 加入项目依赖，也不把 `npx @google/design.md lint` 放进 `./init.sh`。但当 `DESIGN.md` 发生变更、冻结某版 `/Design`、或验收 `foundation.design-system-harness` 时，必须手动运行一次 `npx @google/design.md lint DESIGN.md`，并把结果记录到 `feature_list.json` notes 或 `parrot-progress.md`。

---

## 1. 背景与目标

Parrot 已具备成熟的“工作可靠性”harness：`AGENTS.md`（工作规则与硬约束）、`feature_list.json`（机器可读功能验收）、`parrot-progress.md`（跨会话交接）、`init.sh`（构建/本地运行入口）、`Scripts/` 源码链接 E2E。

本轮要补齐的是**设计一致性子系统**，且需要精确处理两类新引入资产的关系与触发强度：

- `DESIGN.md`：agent 可读的设计系统（tokens + 设计理由），应成为所有 UI 工作的统一视觉基线。
- `/Design`：高保真 HTML 原型，用途受限。它是**未来一次性重构的视觉参考**，不代表当前代码，且**滞后于代码演进**。

核心风险与目标：

- 若 harness 全局强制引用 `/Design`，agent 会把过期的原型布局/控件带回真实代码，误导实现方向。→ 目标：`/Design` 必须**条件触发**，默认不参与日常开发。
- 若 UI 工作不强制对齐 `DESIGN.md`，界面密度、控件选择、状态处理会随会话漂移。→ 目标：`DESIGN.md` 对 UI 工作**强制触发**。
- 两份资产的规范关系必须单向明确：`/Design` 遵循 `DESIGN.md`。
- 若 `DESIGN.md` 未作为团队级共享契约维护，只存在于某次 prompt 或某个 agent 规则里，后续不同工具仍会漂移。→ 目标：根目录 `DESIGN.md` 是唯一稳定入口，所有 agent 规则文件都引用同一份设计契约。

## 2. 目录与文件规范

### 2.1 `DESIGN.md` 的放置与地位

- **位置**：仓库根目录 `DESIGN.md`（已存在，保持不动）。根目录符合 Google `design.md` 生态的默认查找约定，也便于 agent 与人共同维护。
- **地位**：Parrot 的**规范源（normative source）**。承载视觉主题、语义色策略、Typography、窗口密度、控件选择、布局、状态、动效、禁用模式。
- **固定命名**：唯一入口必须叫 `DESIGN.md`，使用大写文件名并放在仓库根目录。不接受 `design.md`、`design-system.md`、`tokens.md` 或 `Docs/DESIGN.md` 作为替代入口，避免多源漂移。
- **版本控制与稳定性**：`DESIGN.md` 必须纳入 git，不得加入 `.gitignore`。它是团队共享设计契约，不是个人笔记，也不是某次 prompt 的临时上下文。日常 feature 只消费 `DESIGN.md`，不顺手改它；只有明确设计方向变化（品牌、核心 tokens、组件原则、状态/动效规则）时才更新，并通过 commit 留下历史。
- **token 与正文的优先级**：按 Google `design.md` 规范，YAML front matter 中的 tokens 是精确值和规范值，Markdown 正文提供应用语境和设计理由。若两者冲突，不允许让 agent 自行猜测；先修正 `DESIGN.md`，再让 agent 参考。当前仓库的 `DESIGN.md` 已存在 token/prose 可能不一致的风险（例如 YAML surface/primary 与正文描述值不完全一致），应在正式接入 harness 前完成一次 reconciliation。
- **与 `/Design` 的引用方向**：**单向，`/Design` 遵循 `DESIGN.md`**。
  - `DESIGN.md` 是 tokens + 理由的唯一权威；`/Design` 的每个 `code.html` 应基于 `DESIGN.md` 的 tokens 渲染（当前原型 HTML 的 Tailwind 配置已经这么做）。
  - 当二者不一致时，**修正原型或标注原型过期**，而不是反向修改 `DESIGN.md`（除非本意就是升级规范，此时先改 `DESIGN.md`，再让原型跟随）。
- **格式兼容性**：保留 YAML front matter（tokens）+ Markdown 正文（理由/规则）双层结构，便于 `@google/design.md` lint、diff、export。YAML 中的颜色保留 CSS 兼容 hex 作为 review fallback；正文需明确：SwiftUI/AppKit 实现优先使用 **macOS 语义色和系统字体**，hex/Inter 等只是 Web 侧校准与 lint 的回退值。
- **完整性检查**：`DESIGN.md` 至少应覆盖 colors、typography、spacing、rounded、components 或 native component mapping、states（hover/pressed/focus/disabled/error/loading/empty）、motion/reduced-motion、elevation/shadow。缺失项不一定阻塞开发，但需要在 harness 验收 notes 中记录，并避免 agent 因上下文不足回落到通用 Tailwind 或“平均 UI”模式。

### 2.2 `/Design` 目录结构约定

当前实际结构（扁平、按页面）：

```text
Design/
├── quick_text_translation/
│   └── code.html
├── screenshot_translation/
│   └── code.html
└── settings/
    └── code.html
```

**推荐演进为“版本 / 页面”两级结构**，以支持“未来一次性重构里程碑”的版本标注与漂移管理：

```text
Design/
├── README.md                      # 资产索引 + 用途/滞后/遵循 DESIGN.md 声明（见 2.4）
└── <version>/                     # 例如 v1-refactor、2026-07-03、milestone-v1
    ├── manifest.json              # 版本元数据（见 5.1）
    ├── quick_text_translation/
    │   └── quick_text_translation.html
    ├── screenshot_translation/
    │   └── screenshot_translation.html
    └── settings/
        └── settings.html
```

约定细则：

- **组织维度**：一级按“设计版本 / 目标重构里程碑”分目录；二级按“页面 / surface”分目录。**页面命名使用 `snake_case`，且与 Parrot 真实 surface 一一对应**（如 `quick_text_translation`、`screenshot_translation`、`settings`、未来的 `translation_history`、`permission_error` 等）。
- **模块 vs 页面**：Parrot 目前是小体量菜单栏工具，surface 数量少，**按“页面/surface”分目录即可，不引入额外“模块”层级**。若未来 surface 增多再按 `Design/<version>/<module>/<page>/` 扩展。
- **是否保留当前扁平结构**：可接受两种落地方式，推荐先采用轻量方案：
  - 轻量：保持现有扁平三目录，仅新增 `Design/README.md`。适合本轮最小改动。
  - 规范：迁移到 `Design/<version>/...`，并新增 `manifest.json`。适合正式承接“未来一次性重构”。
  - **推荐倾向**：先做轻量（新增 README，声明用途/滞后/遵循关系），在真正启动重构、需要冻结一版设计稿时再迁移到带 `<version>` 的结构。理由：避免为尚未开始的重构提前造目录层级。

### 2.3 HTML 原型命名规则

- **原型源**：每个页面目录内以 HTML 文件作为高保真原型源。当前扁平结构使用 `code.html`，资产清单由所在页面目录和 `Design/README.md` 声明。
- **命名一致性**：当前扁平结构允许统一命名为 `code.html`。迁移到版本结构后，建议改为同页面名：`<page>.html`（如 `settings.html`），便于脚本校验与 manifest 追踪。
- **禁止**：不放置未压缩的原始导出中间文件；不在 `/Design` 内写业务数据、密钥或真实用户内容。
- **比对要求**：需要视觉验证时，从对应 HTML 原型重新渲染可重复基线，而不是维护单独的静态导出资产。

### 2.4 `Design/README.md`（新增，索引 + 用途声明）

`Design/README.md` 是**原型资产索引**，不是规范文件。必须开宗明义写清四点，防止后续 agent 误用：

示例文案（可直接写入 `Design/README.md`）：

```markdown
# Parrot /Design 高保真设计资产

> 用途：本目录是**未来某一次一次性重构的视觉参考**，不代表当前代码状态。
> 滞后：原型迭代频繁，且**滞后于真实代码演进**，两者不保证同步。
> 遵循：本目录所有原型**遵循根目录 `DESIGN.md`**（tokens + 设计理由）；`DESIGN.md` 是规范源，本目录只是其视觉演绎。
> 触发：**日常 feature 开发不要引用本目录**。仅当用户显式要求“参考 /Design 原型/重构对照”时才使用。冲突时以当前代码和 `DESIGN.md` 为准。

## 资产清单

| 页面 (surface) | HTML 原型 | 对应真实 surface |
| --- | --- | --- |
| quick_text_translation | quick_text_translation/code.html | Quick Text Translation 窗口 |
| screenshot_translation | screenshot_translation/code.html | Screenshot Translation 结果窗口 |
| settings | settings/code.html | 统一 Settings 窗口 |

## 版本与里程碑

见各版本目录下的 `manifest.json`（若已迁移到版本结构）。当前为未版本化扁平资产，目标里程碑：待定的 V1 视觉重构。
```

## 3. Harness 集成方式

四处改动。每处标注写入哪个文件、哪一节、示例文案。

### 3.1 `AGENTS.md`：新增 “Design Harness” 一节

**写入位置**：`AGENTS.md` 的 `## Code Conventions` 与 `## Workflow` 之间，新增独立 `## Design Harness` 一节。同时**修订** `## Workflow` 中现有的这行：

现状（[AGENTS.md](file:///Users/bytedance/Documents/Project/parrot/AGENTS.md#L50)）：

> - For UI work, follow the PRDs, current app behavior, native macOS conventions, and `DESIGN.md` if/when that file is added.

改为：

> - For UI work, follow current app behavior, native macOS conventions, and `DESIGN.md`. Do NOT treat the PRDs as a visual reference (PRDs lag behind the code too); use them only for product behavior/interaction constraints/privacy. See the Design Harness section for mandatory vs conditional design references.

**新增 `## Design Harness` 示例文案**：

```markdown
## Design Harness

- `DESIGN.md` (repo root) is the single normative source for Parrot's visual language: color/typography/density/component/state/motion rules. It uses YAML tokens plus prose; the SwiftUI/AppKit implementation prefers macOS semantic colors and system fonts, and the hex/Inter values are review fallbacks only.
- `DESIGN.md` MUST be committed and version-controlled. It is the team-wide design contract, not a per-session note. Do not add it to `.gitignore`, and do not rename it to `design.md`, `design-system.md`, or `tokens.md`.
- Mandatory trigger: any UI/UX work MUST read and align with `DESIGN.md` first. This includes new UI features, UI refactors, changing windows/Settings sections/status or error copy, empty/loading/error states, or user-facing flow layout. Non-UI changes do not need `DESIGN.md`.
- Stability rule: day-to-day feature work consumes `DESIGN.md`; it must not opportunistically rewrite `DESIGN.md`. Update `DESIGN.md` only for deliberate design direction changes, then run `npx @google/design.md lint DESIGN.md` when available and record the result.
- Do not invent new design decisions without a reason: no new custom colors, typography, spacing, radius, shadows, or motion unless the change is explicitly justified and reflected in `DESIGN.md` or recorded as a local exception.
- Do NOT use the PRDs as a visual/UI reference: PRDs lag behind the code and their screen descriptions may be stale. Use PRDs only for product behavior, interaction constraints, and privacy boundaries. Visual decisions defer to `DESIGN.md` plus the current code.
- Conditional trigger for `/Design`: the `/Design` HTML prototypes are a reference for a FUTURE one-time refactor only. They iterate frequently and LAG behind the real code, so DO NOT use them as implementation references in day-to-day feature work. Open them ONLY when the user explicitly asks to reference the prototypes or compare against the planned refactor. When opened, use the relevant `code.html` file as the prototype source.
- `/Design` follows `DESIGN.md`, never the reverse. If a prototype disagrees with `DESIGN.md` or the current code, treat the prototype as stale.
- Conflict order (highest to lowest): explicit user instruction > privacy/security/macOS permission/Keychain constraints > PRD product behavior (behavior/interaction/privacy only, NOT visuals) > macOS native HIG > `DESIGN.md` > the current shipped code's established shape. PRDs are never a visual reference. `/Design` prototypes are NOT part of day-to-day arbitration; when they conflict with current code or `DESIGN.md`, defer to current code and `DESIGN.md`.

### Design trigger keywords

- Mandatory `DESIGN.md` triggers: "UI", "界面", "视觉", "样式", "布局", "设计", "重构 UI", "settings 页", "窗口", "错误态/空状态/loading 态", "配色/字体/间距/圆角/控件".
- Conditional `/Design` triggers (only with explicit user intent): "参考 /Design", "对照原型", "按设计稿", "reference the prototype", "match the mockup", "重构对照".
```

**多 Agent 规则文件策略**：

- 当前仓库只存在 `AGENTS.md`，所以本轮只要求修改 `AGENTS.md`。
- 不主动创建 `CLAUDE.md`、`.cursorrules`、`.windsurfrules` 等未使用工具的规则文件，避免增加维护面。
- 如果未来新增这些规则文件，必须同步一份短版 Design Harness 规则块，并保持 `/Design` 条件触发原则一致。

短版规则块示例：

```markdown
## Design System

This project uses `DESIGN.md` at the repository root as the shared design contract.
For UI work:
- Read `DESIGN.md` before changing UI.
- Use existing tokens and component rules; do not invent colors, typography, spacing, radius, shadows, or motion.
- Treat PRDs and `/Design` prototypes as non-visual references unless explicitly requested.
- Update `DESIGN.md` only for deliberate design direction changes, then lint and commit it.
```

### 3.2 `feature_list.json`：新增 feature + UI 验收话术

**改动 A：新增 foundation feature**（写入 `features` 数组）。示例条目：

```json
{
  "id": "foundation.design-system-harness",
  "priority": "P1",
  "category": "foundation",
  "description": "The harness routes UI work to DESIGN.md as the normative visual source, treats /Design prototypes as a conditional future-refactor reference only, and records design verification evidence.",
  "acceptance": [
    "DESIGN.md exists at repo root with YAML tokens plus prose sections.",
    "DESIGN.md is not ignored and is intended to be version controlled as the team's shared design contract.",
    "DESIGN.md update policy is documented: stable contract, not per-session or per-feature tuning.",
    "AGENTS.md has a Design Harness section defining mandatory DESIGN.md triggers and conditional /Design triggers.",
    "If other agent rule files are introduced later (CLAUDE.md, .cursorrules, .windsurfrules), they must reuse the short Design Harness block and preserve /Design conditional triggers.",
    "Design/README.md documents /Design as a future one-time-refactor reference that lags behind code and follows DESIGN.md.",
    "/Design HTML prototypes are declared in Design/README.md; future versioned assets use page-level HTML files.",
    "AGENTS.md does not list /Design as a required input for day-to-day UI work.",
    "DESIGN.md token/prose consistency has been reviewed; any known mismatch is fixed or recorded as a blocking follow-up.",
    "A manual `npx @google/design.md lint DESIGN.md` result is recorded in notes or parrot-progress.md when the environment can access npm.",
    "No product code, dependency, signing, privacy, or persistence changes are introduced by design harness setup."
  ],
  "passes": false,
  "last_verified": null,
  "notes": "Design harness integration. DESIGN.md is the normative source; /Design is conditional-only. Keep passes:false until DESIGN.md token/prose reconciliation, AGENTS Design Harness routing, Design/README.md, feature schema guidance, and one manual design.md lint result are all recorded. This feature does not require a separate product UI change."
}
```

**改动 B：UI 类 feature 的 acceptance 追加两条通用话术**（对 `translation-ui`、`settings`、`screenshot-translation` 等含 UI 的 feature，在其 `acceptance` 末尾追加）：

```text
"Verify the modified UI against DESIGN.md for native control choice, layout density, light/dark readability, loading/empty/error states, keyboard behavior, and long-text handling.",
"Record design verification evidence in notes: screenshot or manual review, real app smoke, or a documented environment limitation. Do not use /Design prototypes as the baseline unless the user explicitly requested prototype alignment."
```

> 说明：无需为每个 feature 复制整段设计规则，只需引用 `DESIGN.md` 并要求留验证证据，避免规则在多处漂移。

**改动 C：UI feature notes 模板**（不强制改 JSON schema；优先写进 notes，避免结构化字段大范围迁移）：

```text
design_verification:
  design_md_read: true/false
  touched_surfaces: [...]
  checked_against: "DESIGN.md tokens/prose + current code"
  design_prototype_used: false
  prototype_reason: "Only fill when user explicitly requested /Design alignment"
  verification_method: "screenshot/manual review/real app smoke/environment limitation"
```

> 说明：`foundation.design-system-harness` 只验收 harness 接入，不依赖“至少一个 UI feature 已完成设计验证”。首个真实 UI feature 的设计验证证据应记录在该 feature 自己的 notes 中。

**改动 D：`DESIGN.md` 变更 notes 模板**（当设计方向确实变化时使用）：

```text
design_md_change:
  reason: "brand/design-direction/token/component-rule change"
  changed_tokens: [...]
  changed_prose_sections: [...]
  lint_result: "errors=0 warnings=N info=N or environment limitation"
  committed: true/false
  downstream_design_assets_updated: "not needed/Design README updated/manifest updated"
```

> 说明：普通 UI feature 不应填写这个模板。只有真正修改 `DESIGN.md` 时才记录，防止它被日常调参污染。

### 3.3 `parrot-progress.md`：记录设计 harness 状态

**写入位置**：在“当前状态”日期块追加一条，并在需要时新增一节“设计 Harness”。示例追加文案：

```markdown
- 2026-07-03 最新补充：引入设计 Harness。根目录 `DESIGN.md` 为唯一强制设计语言来源，也是团队级共享设计契约，必须保持根目录固定命名、纳入版本控制、稳定更新，不能作为每次 feature 的临时调参文件。所有 UI/UX 新功能或重构必须先对齐它。`/Design` 目录（quick_text_translation / screenshot_translation / settings 三页，各含 code.html）定位为**未来一次性重构的视觉参考**，滞后于代码、遵循 `DESIGN.md`，日常开发默认不引用，仅在用户显式点名时使用。冲突时以当前代码和 `DESIGN.md` 为准。`AGENTS.md` 新增 Design Harness 路由；若未来新增 `CLAUDE.md`、`.cursorrules`、`.windsurfrules` 等 agent 规则文件，必须复用短版 Design Harness 规则块。`feature_list.json` 新增 `foundation.design-system-harness`，`Design/README.md` 新增资产索引与用途声明。不把 `@google/design.md` 加入默认构建依赖，但在 `DESIGN.md` 变更、设计版本冻结或 harness 验收时手动运行 `npx @google/design.md lint DESIGN.md` 并记录结果。
```

后续每次 UI 改动，应在会话记录中写明：是否读了 `DESIGN.md`、对齐了哪些 surface、验证方式（截图/真实 smoke/环境限制）、以及是否显式引用了 `/Design`。

### 3.4 触发方式总表

| 资产 | 触发强度 | 触发条件 | 默认行为 |
| --- | --- | --- | --- |
| `DESIGN.md` | 强制（条件强制） | 任务涉及 UI/UX：新界面、UI 重构、窗口/Settings/状态/错误文案、空/加载/错误态、用户流程布局 | 涉及 UI 必读并对齐；非 UI 任务可跳过 |
| `/Design` | 条件（显式） | 用户显式要求参考原型 / 重构对照 | 默认不读、不作为实现依据；仅显式点名时引用 |

## 4. 防误用护栏

### 4.1 冲突取舍原则

- **`/Design` 与当前代码冲突** → 以**当前代码**为准（原型滞后于代码）。
- **`/Design` 与 `DESIGN.md` 冲突** → 以 **`DESIGN.md`** 为准（原型遵循规范）。
- **PRD 不作为 UI/视觉依据** → PRD 同样滞后于代码，其界面/布局描述可能过时。PRD 仅用于产品行为、交互约束、隐私边界；**视觉呈现一律以 `DESIGN.md` + 当前代码为准**。
- **`DESIGN.md` 与 PRD 的产品行为 / macOS 权限 / 隐私冲突** → 以 PRD 的行为约束、隐私、权限为准（见第 0 节优先级）；但这只针对“做什么”，不针对“长什么样”。
- **`DESIGN.md` 与 macOS 原生 HIG 明显冲突** → 优先原生 HIG，并在 `DESIGN.md` 标注例外，而不是让 agent 绕开原生控件。
- **`/Design` 永不参与日常裁决**：非用户显式要求时，它不进入优先级链条。

一句话护栏（建议同时写进 `AGENTS.md` 与 `Design/README.md`）：

> “`/Design` 是未来重构的视觉草稿，不是当前事实。冲突时以当前代码和 `DESIGN.md` 为准；只有用户显式点名时才引用 `/Design`。”

### 4.2 防止“过期原型回流”

- agent 在 UI 任务中默认**不打开** `/Design`；即使打开（用户要求），也必须以“视觉参考”而非“像素复刻”方式使用，并尊重已有工程事实（`NSTextView` 首屏渲染、TCC、窗口定位、流式渲染等）。
- 禁止把 `/Design` 的 Web 模式（hero、marketing card、非系统字体、复杂动效、Tailwind 具体像素）直接迁入 SwiftUI/AppKit。
- 若 agent 发现 `/Design` 与代码/`DESIGN.md` 已明显不一致，应在 `parrot-progress.md` 记一条“原型漂移”，而不是据此改代码。

## 5. 版本与漂移管理

### 5.1 版本标注（`manifest.json` 或 README 表格）

当 `/Design` 迁移到 `Design/<version>/` 结构后，每个版本目录放一份 `manifest.json`。示例：

```json
{
  "design_version": "v1-refactor",
  "effective_date": "2026-07-03",
  "based_on_design_md": {
    "name": "Invisible Utility",
    "path": "DESIGN.md",
    "design_md_version": "alpha",
    "git_commit": "<commit-sha-or-null>",
    "sha256": "<sha256-of-DESIGN.md>",
    "lint_command": "npx @google/design.md lint DESIGN.md",
    "lint_summary": { "errors": 0, "warnings": 0, "info": 0 }
  },
  "target_milestone": "Parrot V1 视觉重构（尚未排期）",
  "status": "reference-only",
  "represents_current_code": false,
  "prototype_source": "html",
  "prototype_generated_at": "2026-07-03T00:00:00Z",
  "pages": [
    { "page": "quick_text_translation", "html": "quick_text_translation.html" },
    { "page": "screenshot_translation", "html": "screenshot_translation.html" },
    { "page": "settings", "html": "settings.html" }
  ],
  "notes": "Future one-time refactor reference. Lags behind code. Follows DESIGN.md. Not a current-state snapshot."
}
```

在扁平结构（尚未迁移）阶段，等价信息写入 `Design/README.md` 的“版本与里程碑”小节即可，至少标注：设计版本、生效日期、基于哪一版 `DESIGN.md`、`DESIGN.md` 的 git commit 或 sha256、lint 结果摘要、目标重构里程碑、`represents_current_code: false`。

### 5.2 漂移处理流程

设计与代码出现漂移时（这是**预期常态**，因为原型滞后）：

1. **不阻塞日常开发**：漂移不作为 feature 验收失败项。日常 UI 工作以 `DESIGN.md` + 当前代码为准。
2. **记录而非立即修复**：在 `parrot-progress.md` 追加一条“原型漂移”记录（哪个 surface、原型与代码差异点、判定以代码为准）。
3. **规范级变更走 `DESIGN.md`**：如果漂移反映的是**规范应当变化**（例如决定采用新的密度/控件），先更新 `DESIGN.md`（tokens/理由），再择机让 `/Design` 原型跟随。
4. **规范差异可比对**：当 `DESIGN.md` 版本发生变化，优先运行 `npx @google/design.md diff <old-design.md> DESIGN.md` 或在 notes 中人工记录 token/prose 变化，避免只用主题名追踪设计版本。
5. **重构里程碑冻结**：当真正启动那次一次性重构时，冻结一版 `Design/<version>/`，用 `manifest.json` 标注 `effective_date` 和 `target_milestone`，作为该次重构的对照基线；重构完成后，将该版本标为 `status: consumed` 或归档。
6. **过期版本处理**：旧版本目录保留但在 `README.md`/`manifest.json` 标注为过期/已消费，不删除历史，也不让其参与后续 UI 决策。

### 5.3 `DESIGN.md` 变更流程

`DESIGN.md` 的变更应比普通 UI feature 更克制。它是稳定契约，不是日常调参文件。推荐流程：

1. **确认触发条件**：只有品牌方向、核心 tokens、组件原则、状态规则、motion/reduced-motion、elevation/shadow 等设计方向变化，才修改 `DESIGN.md`。普通 UI bugfix、局部布局适配、文案调整不应顺手改它。
2. **修订 tokens 与 prose**：YAML tokens 和 Markdown 正文必须同步，避免 token/prose 冲突。
3. **运行结构检查**：环境允许时运行 `npx @google/design.md lint DESIGN.md`。若 npm 不可达，记录环境限制；若有 errors，先修复。
4. **记录差异**：在 `feature_list.json` notes 或 `parrot-progress.md` 写明变更原因、影响 tokens/章节、lint 结果、是否影响 `/Design`。
5. **提交历史**：`DESIGN.md` 必须作为版本控制文件提交。建议单独 commit 或至少在 commit message 中明确 `design-system` 范围，便于追溯设计方向变化。
6. **同步资产**：如果 `DESIGN.md` 变化会影响未来重构视觉资产，更新 `Design/README.md` 或对应 `manifest.json` 的 `based_on_design_md` 信息；不要求立即更新所有 `/Design` 原型，但必须记录漂移。

## 6. 取舍与不确定项（含推荐倾向）

1. **`/Design` 结构：保持扁平 vs 迁移到 `<version>/`。**
   - 推荐：**本轮保持扁平 + 新增 README**；待启动实际重构、需要冻结设计稿时再迁移到版本结构并加 `manifest.json`。理由：避免为尚未排期的重构提前造层级。

2. **`Design/README.md` 是否必须新增。**
   - 推荐：**必须新增**。它是防误用的关键锚点（声明用途/滞后/遵循/触发），成本极低，收益是杜绝“过期原型回流”。

3. **`foundation.design-system-harness` 的优先级与通过条件。**
   - 推荐：设为 **P1**。它不属于 P0 MVP 功能路径，但影响后续所有 UI 工作的一致性，值得尽早落地。通过条件应限定为 harness 接入本身：`DESIGN.md` token/prose reconciliation、`AGENTS.md` 路由、`Design/README.md`、`feature_list.json` 验收话术、手动 lint 结果记录。不要求同时完成一个真实 UI feature。

4. **是否引入 `npx @google/design.md lint`。**
   - 推荐：**不加入默认依赖，但作为条件验收命令保留**。不进 `./init.sh`，也不写入 `package.json`，避免给 Swift/macOS 项目增加 Node 工具链负担。但在 `DESIGN.md` 变更、`/Design` 冻结、harness 验收时手动运行并记录结果。理由：lint 能发现 broken refs、contrast、section order、缺失 typography 等结构问题，但不能判断 SwiftUI/AppKit 的原生控件实现质量。

5. **`Scripts/design-review-check.sh`（无依赖文本检查）。**
   - 推荐：**本轮不新增**，列为可选后续。若未来 UI review 规则变多，可加一个只判断“harness 是否被执行”（`DESIGN.md` 存在、必要 sections 存在、`AGENTS.md` 未把 `/Design` 列为 UI 必读输入、UI feature notes 有设计证据）的脚本，不判断审美。

6. **`DESIGN.md` 当前主题 “Invisible Utility” 的 Web token（Inter 字体、Tailwind 像素、CSS hex）与 macOS 原生的张力。**
   - 推荐：**保留 tokens 作为 lint/校准 fallback，但在正文明确 SwiftUI/AppKit 实现使用 macOS 语义色 + 系统字体（SF Pro/系统默认）**。避免 agent 在原生代码里硬编码 Inter/CSS hex。可在 `DESIGN.md` 正文补一段 “Platform / Implementation Notes” 说明该回退关系（可作为后续对 `DESIGN.md` 的小幅补充，不在本方案强制范围内）。

7. **当前 `DESIGN.md` token/prose 不一致。**
   - 推荐：**作为正式接入前置项处理**。先审计 YAML tokens 与正文描述是否一致，尤其是 surface、primary/accent、typography、spacing、radius；若不一致，优先修订正文或 tokens，使 agent 不需要猜测。冲突时以 tokens 为规范值，但理想状态是两层无冲突。

8. **是否新增 `CLAUDE.md`、`.cursorrules`、`.windsurfrules` 等多 Agent 规则文件。**
   - 推荐：**不主动创建未使用工具的规则文件**。当前仓库只存在 `AGENTS.md`，先在 `AGENTS.md` 落地。若未来团队引入 Claude Code、Cursor、Windsurf 等工具，再创建对应规则文件，并复制第 3.1 节的短版 Design Harness 规则块。这样能获得 setup 文章强调的“所有工具自动读取同一份 `DESIGN.md`”，同时避免现在提前维护无用文件。

9. **`DESIGN.md` 是否必须提交，`/Design` 是否必须提交。**
   - 推荐：`DESIGN.md` **必须提交且不得 ignore**，因为它是团队共享契约。`/Design` 可以提交，但必须有 `Design/README.md` 或未来 `manifest.json` 说明用途、版本和滞后关系；资产体积策略按 HTML 原型维护需要单独制定。

## 7. 落地行动清单（建议顺序）

1. 确认 `DESIGN.md` 位于仓库根目录、文件名大小写正确、未被 `.gitignore` 忽略，并计划作为版本控制文件提交。
2. 审计并修正当前 `DESIGN.md`：确认 YAML tokens 与 Markdown prose 不冲突，补齐或记录缺失的 components/states/motion/reduced-motion/elevation/shadow 语境。
3. 手动运行 `npx @google/design.md lint DESIGN.md`。若 npm 不可达，在 notes 中记录环境限制；若有 errors，先修复再继续。不要把该命令加入 `./init.sh`。
4. `AGENTS.md`：修订 `## Workflow` 中 `DESIGN.md` 那行，并新增 `## Design Harness` 一节（3.1 文案），包括版本控制、稳定性、多 Agent 规则文件策略和短版规则块。
5. 新增 `Design/README.md`：资产索引 + 用途/滞后/遵循/触发声明（2.4 文案），并声明当前扁平结构的 `code.html` 原型来源。
6. `feature_list.json`：新增 `foundation.design-system-harness`（3.2 改动 A），给 UI 类 feature 追加设计验收话术、UI notes 模板、`DESIGN.md` 变更 notes 模板（3.2 改动 B/C/D）。
7. `parrot-progress.md`：追加设计 harness 落地记录（3.3 文案），包含 `DESIGN.md` reconciliation、lint 结果、版本控制状态和多 Agent 规则文件策略。
8. 完成以上步骤后，`foundation.design-system-harness` 可按基础设施接入通过，不需要绑定一个真实 UI feature。
9. 后续首个 UI feature 按 `DESIGN.md` 做真实 review，并把验证证据写回该 feature notes 与 `parrot-progress.md`。
10. （可选/未来）若新增 `CLAUDE.md`、`.cursorrules`、`.windsurfrules` 等规则文件，复制短版 Design Harness 规则块，并保持 `/Design` 条件触发原则一致。
11. （可选/未来）需要冻结重构基线时，迁移 `/Design` 到 `Design/<version>/` 并加 `manifest.json`（5.1）。
12. （可选/未来）评估无依赖 `Scripts/design-review-check.sh` 的结构检查收益，再决定是否纳入。

## 8. 边界与职责总表

| 文件/目录 | 职责 | 触发/使用规则 |
| --- | --- | --- |
| `Docs/ai-translation-macos-prd.md` / `ai-translation-macos-v1-prd.md` | 产品行为、交互原则、隐私边界 | 功能行为的最高产品依据；**不作为 UI/视觉依据**（PRD 滞后于代码，视觉以 `DESIGN.md` + 代码为准） |
| `AGENTS.md` | agent 工作方式、硬约束、设计路由 | 每个非平凡任务先读；当前唯一强制落地的 agent 规则文件 |
| `CLAUDE.md` / `.cursorrules` / `.windsurfrules`（未来可选） | 其他 AI 工具的规则入口 | 当前不主动创建；若未来引入，必须复用短版 Design Harness 规则块 |
| `DESIGN.md` | 视觉语言、组件选择、布局密度、UI 状态（规范源、团队共享设计契约） | **UI 任务强制**；固定根目录命名；必须版本控制；稳定更新；`/Design` 遵循它 |
| `/Design`（+ `README.md` / `manifest.json`） | 未来一次性重构的高保真视觉参考（HTML） | **默认不用**；仅用户显式点名；滞后于代码 |
| `feature_list.json` | feature 级验收与证据 | UI feature 记录设计验证证据 |
| `parrot-progress.md` | 跨会话状态、设计漂移记录 | 记录设计 harness 落地与漂移 |

## 9. 核心结论

Parrot 应把 `DESIGN.md` 与 `/Design` 作为**两个强度不同的设计层**接入 harness：`DESIGN.md` 是 UI 工作的强制规范源，也是团队共享设计契约；`/Design` 是仅供未来一次性重构、且滞后于代码的条件参考。二者关系单向：`/Design` 遵循 `DESIGN.md`。日常开发不得被 `/Design` 误导，也不得把 `DESIGN.md` 当作每次 feature 的临时调参文件。落地重点不是增加依赖，而是确保根目录 `DESIGN.md` 固定命名、纳入版本控制、稳定更新，先修正 token/prose 一致性，再把 `@google/design.md lint` 作为条件验收命令记录结果，并通过 `AGENTS.md`、未来可选 agent 规则文件、`Design/README.md`、`feature_list.json`、`parrot-progress.md` 与未来版本化 `manifest.json` 管理设计上下文和资产漂移。
