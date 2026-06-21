# Parrot 进度交接

## 当前状态

- 日期：2026-06-21
- 项目形态：macOS SwiftUI App scaffold
- Xcode 工程：`Parrot.xcodeproj`
- Scheme：`Parrot`
- 产品依据：`Docs/ai-translation-macos-prd.md`
- 初始化入口：`./init.sh`
- 最新验证：`./init.sh` 已成功完成工程元数据检查和 Debug 构建。
- 设计参考：`Design/` 已保存 4 张产品高保真原型图，并通过 `Design/README.md` 建立索引。

## 启动就绪清单

- [x] 能启动：`./init.sh --open` 可打开 Xcode 工程。
- [x] 能验证：`./init.sh` 会列出工程元数据并执行 Debug 构建。
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

## 当前未实现

- 全局快捷键。
- 截图框选与本地 OCR。
- 快捷文本翻译小窗。
- OpenAI-compatible LLM 配置与请求。
- Keychain API Key 保存。
- 翻译结果对照浮窗。
- 权限、网络、认证、OCR 等错误提示。

## 已知约束

- MVP 仅面向 macOS。
- 默认使用本地 OCR，仅将识别后的文本发送给 LLM。
- API Key 只能保存到 macOS Keychain，不能写入配置文件、日志、fixture 或文档。
- 命令行构建使用 `CODE_SIGNING_ALLOWED=NO`，因为当前未配置 `DEVELOPMENT_TEAM`。
- 如 `xcodebuild` 使用 Command Line Tools 而非完整 Xcode，需要运行：

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

## 建议下一步

1. 运行 `./init.sh`，确认当前 scaffold 可构建。
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
