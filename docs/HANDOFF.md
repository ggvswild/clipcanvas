# Paste 开源对齐项目 — AI 设计与开发 Handoff

> **文档用途**：把需求决策、对标产品能力、参考截图与约束一次性交给下游 AI，完成架构设计与落地实现。  
> **仓库路径**：`/Users/we/Documents/NetEase/paste-copy`（当前几乎为空，可从零脚手架）  
> **文档日期**：2026-07-17  
> **语言**：产品与代码注释可用中英；与用户沟通默认中文。

---

## 1. 一句话目标

做一个 **macOS 原生、开源、用于个人学习** 的剪贴板管理器，**功能上完全对齐** 商业产品 [Paste](https://pasteapp.io/)（以用户本机安装版 + 下方截图为准），**明确不做** iCloud 同步与付费订阅。

产品定位名可暂定为 **paste-copy**（仓库名）；正式开源名称可在实现阶段再定（注意商标：避免直接叫 “Paste” 上架/推广）。

---

## 2. 已确认决策（不可轻易改）

| 决策项 | 选择 | 说明 |
|--------|------|------|
| 对齐程度 | **完全对齐主功能** | 覆盖历史、Pinboard、搜索、粘贴策略、隐私、快捷键、MCP 等；不是「最小 MVP」 |
| 平台 | **仅 macOS** | 深度系统集成（剪贴板、全局快捷键、粘贴到前台 App、登录项、忽略 App 等） |
| 技术栈 | **Swift + SwiftUI 原生** | 不用 Electron / Tauri |
| iCloud 同步 | **不做** | 历史仅本机；设置里可不出现 iCloud 开关，或灰色注明「开源版不支持」 |
| MCP & AI Tools | **完整实现（方案 A）** | 本地 MCP Server + 授权管理 + 对历史/Pinboard 的能力暴露，设置页语义对齐官方 |
| 用途 | **个人学习 + 开源** | 无商业订阅；可有「赞助/Star」类非功能文案，不做付费墙 |
| 仓库状态 | **空仓起步** | 无历史代码约束，架构由实现方设计 |

### 2.1 对「完全对齐」的操作定义

- **要对齐**：能力、信息架构、主要交互、设置项语义、快捷键能力、MCP 产品意图。  
- **不必对齐**：像素级 UI 抄袭、官方品牌资源、闭源实现细节、App Store 付费/Pro 功能墙、官方后端。  
- **必须尊重**：开源许可、用户隐私（本地优先）、不诱导用户关闭系统安全机制以外的必要权限说明要清晰。

---

## 3. 对标产品与参考截图

对标对象：**Paste for Mac**（剪贴板历史 + Pinboard + 设置 + MCP）。

下列图片已上传图床，设计/实现时请直接引用外链查看。

### 3.1 主界面 — 剪贴板历史条（横向卡片）

![主界面：剪贴板历史横向卡片流](https://p1.music.126.net/EJlLzpEm0QqS9CaGrSU7Mg==/109951173580027681.jpg)

**可见信息架构：**

- 顶部栏：搜索、`Useful Links`、`Clipboard`、添加（`+`）等。
- 主体：水平滚动的 **卡片流**（从新到旧或可配置）。
- 单卡结构：
  - 类型标签：`Image` / `Text` / `Link` 等，带颜色区分。
  - 相对时间：`3 minutes ago` 等。
  - 来源 App 图标（Chrome、ChatGPT、自有应用等）。
  - 预览区：图片缩略图 / 文本摘要 / 链接标题。
  - 元信息：分辨率（如图片 `1931 × 1522`）、字符数、文件路径片段等。
- 内容类型示例：网页截图、纯文本、中文长文本、路径、URL、站点标题链接。

**实现时需覆盖的交互（从对标产品常识 + 截图推断，需在设计阶段写进 PRD/验收）：**

- 全局快捷键唤起 / 关闭面板。
- 方向键或快捷键在卡片间移动；数字键 Quick Paste。
- 回车/点击：按设置「粘贴到当前 App」或「仅写入剪贴板」。
- 搜索过滤历史。
- Pin / 多选 / 删除 / 预览大图（若官方有，应对齐；设计阶段用本机 Paste 再确认一遍）。
- Pinboard 与 Clipboard 切换（截图顶部有相关入口；下一节快捷键也印证存在 Pinboard）。

### 3.2 设置 — General

![设置 General](https://p1.music.126.net/7OV5vU6jCDOS6EoKqWOw2A==/109951173580025752.png)

**侧边导航（全设置通用）：**

- General  
- Privacy  
- Shortcuts  
- MCP & AI Tools  
- Subscription（开源版：**删除或改为 About / License / 致谢**，不做订阅）

**General 项：**

| 设置项 | 截图状态 | 开源对齐要求 |
|--------|----------|--------------|
| Open at login | ON | 支持登录启动（SMAppService / 登录项 API） |
| iCloud sync | ON + “Synced …” | **不做**；勿实现 CloudKit |
| Sound effects | ON | 粘贴/复制等可开关音效 |
| Paste Items → To active app | 选中 | 将选中条目直接粘贴到当前前台应用 |
| Paste Items → To clipboard | 未选中 | 仅写入系统剪贴板，由用户手动粘贴 |
| Always paste as Plain Text | 未勾选 | 可选强制纯文本粘贴 |
| Keep History | 滑块：Day / Week / Month / Year / Forever | 按保留策略自动清理；截图约在 Month |
| Erase History… | 按钮 | 一键清空历史（建议二次确认） |

### 3.3 设置 — Privacy

![设置 Privacy](https://p1.music.126.net/jnKriZp_98RU9CejJD6zpw==/109951173580031532.png)

| 设置项 | 说明（截图文案） | 对齐要求 |
|--------|------------------|----------|
| Show During Screen Sharing | 屏幕共享时是否允许 Paste 界面出现 | 检测屏幕共享/录制状态并控制可见性 |
| Generate Link Previews | 下载网页内容做预览；可能触发一次性/统计类链接 | 可开关；注意隐私与网络请求 |
| Ignore confidential content | 检测到密码等敏感数据则不保存 | 启发式：密码框、安全输入、常见 secret 模式等 |
| Ignore transient content | 不保存其他 App 产生的临时数据 | 对接系统「transient」剪贴板标记（若 API 可得） |
| Ignore Applications | 列表：Keychain Access、Passwords；可 + / − | 按 bundle id 黑名单，不记录这些 App 的复制 |

### 3.4 设置 — Shortcuts

![设置 Shortcuts](https://p1.music.126.net/M1Iq7XLEdGwo7tUtTAm5qA==/109951173580028159.png)

| 动作 | 截图默认快捷键 |
|------|----------------|
| Activate Paste | ⇧⌘V |
| Activate Paste Stack | ⇧⌘C |
| Show next Pinboard | ⌘→ |
| Show previous Pinboard | ⌘← |
| Quick Paste | ⌘ + 1…9 |
| Plain Text mode | 按住 ⇧（修饰键模式） |
| Reset shortcuts to default… | 恢复默认 |

要求：可自定义、冲突检测、与系统快捷键尽量协调；全局热键需合适权限/实现方式（如 `MASShortcut` 思路或 Carbon/CGEvent / `KeyboardShortcuts` 包等，由实现方选型）。

### 3.5 设置 — MCP & AI Tools

![设置 MCP & AI Tools](https://p1.music.126.net/ZlyXWhsIcSYJATarFmPIhQ==/109951173580023826.png)

**截图文案要点：**

- 开关：`Enable MCP`
- 说明：Allow AI apps to connect to Paste. Only apps you approve can access your clipboard items and pinboards.

**完整实现（已确认 A）必须包含：**

1. **本地 MCP Server**（stdio 和/或 本地端口/socket；优先遵循当前 MCP 生态惯例，便于 Cursor / Claude Desktop 等接入）。  
2. **授权模型**：仅用户批准的客户端可访问；可撤销。  
3. **工具/资源能力**（建议最小完整集，设计阶段可增）：  
   - 列出/搜索剪贴板历史  
   - 读取单条内容（文本/元数据；图片可返回路径或 base64 策略需谨慎）  
   - 列出/读取 Pinboard  
   - （完整对齐建议）写入新条目、置顶、删除——需权限分级（只读 vs 读写）  
4. **设置 UI**：开关、连接说明、已授权应用列表、复制配置片段（如 JSON 配置给 AI 客户端）。  
5. **安全**：默认拒绝；敏感内容可遵循 Privacy 中的 ignore 规则；审计日志可选。

---

## 4. 功能范围清单（对齐用）

### 4.1 必须实现（P0 — 产品可称为「对齐版」）

**剪贴板核心**

- [ ] 后台监听系统剪贴板变化并入库  
- [ ] 支持类型：纯文本、富文本（按策略）、图片、URL/链接、文件路径（尽量对齐官方能抓的类型）  
- [ ] 去重/合并策略（连续相同内容等，需设计）  
- [ ] 历史列表 UI（横向卡片流 + 键盘导航）  
- [ ] 搜索  
- [ ] 粘贴到前台 App / 仅进剪贴板  
- [ ] Always paste as plain text  
- [ ] 历史保留时长 + 清空历史  
- [ ] 开机启动、音效开关  

**Pinboard**

- [ ] 多个 Pinboard  
- [ ] 固定条目、在 Pinboard 间浏览（含 next/previous 快捷键）  
- [ ] 与 Clipboard 历史区分存储  

**隐私**

- [ ] 忽略指定 App  
- [ ] 忽略 confidential / transient（在系统能力允许范围内做到「尽力对齐」）  
- [ ] 链接预览开关  
- [ ] 屏幕共享时显示策略  

**快捷键**

- [ ] 上表全部动作 + 可配置 + 重置默认  

**MCP**

- [ ] Enable MCP 全链路 + 授权 + 工具集  

**工程**

- [ ] 菜单栏/Agent 形态（Paste 典型为常驻；具体用 Menu Bar extra 还是 LSUIElement 由设计定）  
- [ ] 权限说明（辅助功能、自动化等：粘贴到前台 App 通常需要）  
- [ ] 基础单元测试 + 关键路径手动验收清单  

### 4.2 明确不做（Out of Scope）

- ❌ iCloud / CloudKit / 多设备同步  
- ❌ 官方 Subscription / 付费解锁  
- ❌ 非 macOS 平台  
- ❌ 复刻官方品牌资产（图标、插画、文案商标）  
- ❌ 与官方服务器的任何闭源协议对接  

### 4.3 建议 P1（完全对齐体验但可第二迭代）

- Useful Links 或等价「钉选常用链接」能力（主界面顶部有入口，需对本机 Paste 再确认行为）  
- 链接预览的缓存、超时、安全策略打磨  
- 导入/导出历史（本地备份，部分替代「无 iCloud」）  
- 多语言（先 en + zh-Hans 即可）  
- Sparkle 或 GitHub Release 自动更新  

---

## 5. 技术约束与建议方向（供设计 AI 选型，非强制实现细节）

| 领域 | 建议方向 | 备注 |
|------|----------|------|
| UI | SwiftUI + 少量 AppKit 托管 | 全局面板、毛玻璃、收藏夹级动画可混用 AppKit |
| 最低系统 | 建议 macOS 14+（若要更低需论证） | 在 README 写明 |
| 存储 | SQLite（GRDB/SQLiteData）或 SwiftData | 图片用文件目录 + DB 元数据，避免 DB 膨胀 |
| 剪贴板 | `NSPasteboard` 轮询/监听最佳实践 | 注意性能与省电；避免丢事件 |
| 粘贴到前台 | Accessibility / CGEvent 模拟 ⌘V 等 | 需权限引导 UX |
| 全局热键 | 成熟开源封装或自研 | 设置页可改键 |
| 登录项 | `SMAppService` | 现代 macOS 推荐 |
| MCP | 官方 MCP Swift SDK 或自实现 JSON-RPC | 文档化客户端配置 |
| 架构 | 清晰分层：Capture / Store / Query / Paste / UI / MCP / Settings | 便于测试与开源协作 |
| 许可 | 建议 MIT 或 Apache-2.0 | 最终由用户定，写入 LICENSE |

**权限与安全（实现必做产品文案）：**

- 辅助功能（Accessibility）  
- 自动化（若用 AppleScript）  
- 网络（仅链接预览；可默认关）  
- MCP 开启时的本地端口/进程暴露说明  

---

## 6. 建议交付节奏（给实现 AI 拆阶段）

> 目标是「最终完全对齐」，但工程上仍应分阶段可运行。

1. **Phase 0 — 工程骨架**  
   Xcode 工程、菜单栏常驻、设置窗口壳、日志、权限引导页。

2. **Phase 1 — 剪贴板闭环**  
   监听 → 存储 → 历史 UI → 粘贴（先「到剪贴板」，再「到前台 App」）。

3. **Phase 2 — 产品完成度**  
   搜索、类型预览、保留策略、音效、登录启动、快捷键、Plain Text。

4. **Phase 3 — Pinboard + Privacy**  
   Pinboard CRUD/切换；忽略 App/敏感/transient；屏幕共享策略；链接预览。

5. **Phase 4 — MCP 完整**  
   Server、授权、工具、设置页、示例客户端配置、安全默认值。

6. **Phase 5 — 开源打磨**  
   README、截图、架构图、验收清单、CI（`xcodebuild`）、许可证、贡献指南。

每阶段结束应有：**可运行的 `.app` + 该阶段验收用例勾选**。

---

## 7. 验收标准（摘要）

下游 AI 设计文档中应把下列扩成可勾选 Test Plan：

1. 在 Safari/Notes/VS Code 等复制文本/图片后，1 秒内出现在历史中。  
2. ⇧⌘V 唤起面板，键盘选中条目后可粘贴进 Notes。  
3. 将 1Password/Passwords/Keychain 加入忽略后，从中复制不再入库。  
4. Keep History = Day 时，超时条目被清理。  
5. Enable MCP 后，用某 MCP 客户端能列出历史并读取一条文本；未授权客户端失败。  
6. 关闭 MCP 后客户端无法再访问。  
7. 无任何 iCloud/订阅相关已实现逻辑。  
8. 干净 macOS 上按 README 可从源码构建运行。

---

## 8. 下游 AI 工作指令（请严格按序）

你是接手的设计与开发 AI。请：

1. **先读完本文**与全部参考图外链，如有条件在 macOS 上打开官方 Paste 对照快捷键与 Pinboard/Useful Links 细节，把「推断」升级为「确认」，并在设计文档标注来源。  
2. **产出设计文档**（建议路径）：  
   - `docs/superpowers/specs/2026-07-17-paste-copy-design.md`（或等价）  
   内容至少包含：信息架构、模块图、数据模型、权限 UX、MCP 工具 schema、设置项对照表、风险与非目标。  
3. **产出实现计划**：分 Phase 的任务列表，含文件级改动预估与验收用例。  
4. **再开始写代码**；不要在设计未自洽时直接大面积脚手架后失控扩张。  
5. **UI** 可对标截图的信息架构与深色质感，但使用原创视觉（颜色 token、图标、命名）。  
6. **所有用户可见字符串** 建议 Localizable；默认英文 + 中文可选。  
7. 与用户确认后的新决策，写回 `docs/HANDOFF.md` 附录「决策日志」，避免多 AI 轮转丢上下文。

### 8.1 仍待下游确认/补全的细节（本文未拍板）

- 开源英文名/Bundle ID  
- 具体最低 macOS 版本  
- LICENSE 选择  
- Useful Links 是否等同某类特殊 Pinboard  
- 富文本、多文件、代码片段高亮等类型的边界  
- MCP 传输方式（stdio-only vs HTTP/SSE）与工具最终清单  
- 是否做 App Sandbox（沙盒会显著影响剪贴板/热键/粘贴能力，需论证）  

---

## 9. 决策日志

| 时间 | 决策 | 结论 |
|------|------|------|
| 2026-07-17 | v1 目标 | 完全对齐（非最小 MVP） |
| 2026-07-17 | 平台 | 仅 macOS |
| 2026-07-17 | 技术栈 | Swift + SwiftUI 原生 |
| 2026-07-17 | iCloud | 不做 |
| 2026-07-17 | MCP | 完整实现 |
| 2026-07-17 | 交付形式 | 本 Handoff 交另一 AI 设计开发 |
| 2026-07-17 | 实施授权 | 用户授权按推荐方案执行，中途不再逐项确认，完成产品落地后统一通知 |
| 2026-07-17 | 产品名 / Bundle ID | ClipCanvas / `dev.clipcanvas.app` |
| 2026-07-17 | 最低系统 | macOS 14+（与本机 Paste 6.6.3 对标信息一致） |
| 2026-07-17 | 许可证 | MIT |
| 2026-07-17 | App Sandbox | 不启用；采用本地签名或 Developer ID 分发 |
| 2026-07-17 | Useful Links | 作为内置系统 Pinboard 实现 |
| 2026-07-17 | 富文本与多文件 | 保存原表示并提供纯文本/元数据预览 |
| 2026-07-17 | MCP 传输 | MCP 2025-11-25；localhost Streamable HTTP + stdio bridge |

---

## 10. 参考图外链速查

| # | 内容 | URL |
|---|------|-----|
| 1 | 主界面历史卡片 | https://p1.music.126.net/EJlLzpEm0QqS9CaGrSU7Mg==/109951173580027681.jpg |
| 2 | General 设置 | https://p1.music.126.net/7OV5vU6jCDOS6EoKqWOw2A==/109951173580025752.png |
| 3 | Privacy 设置 | https://p1.music.126.net/jnKriZp_98RU9CejJD6zpw==/109951173580031532.png |
| 4 | Shortcuts 设置 | https://p1.music.126.net/M1Iq7XLEdGwo7tUtTAm5qA==/109951173580028159.png |
| 5 | MCP & AI Tools | https://p1.music.126.net/ZlyXWhsIcSYJATarFmPIhQ==/109951173580023826.png |

本地会话备份（若外链失效可再传）：

- `/Users/we/.grok/sessions/%2FUsers%2Fwe%2FDocuments%2FNetEase%2Fpaste-copy/019f6f4e-fadd-7eb1-85d4-53ea1bafc80f/assets/`

---

## 11. 给「产品负责人 / 用户」的一句话

> 要的是：**macOS 上原生、开源、可学习的 Paste 功能对齐版**；同步云与订阅不要；MCP 要做满。其余工程细节由接手 AI 设计并实现，有分歧时以「本机 Paste 行为 + 本 Handoff 决策表」为准。

---

*End of handoff.*
