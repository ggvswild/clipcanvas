# ClipCanvas Acceptance

| 项目 | 值 |
|---|---|
| 验收日期 | **2026-07-18** |
| 环境 | macOS 26.5.2 (25F84), Apple Silicon arm64 |
| 产物 | `build/ClipCanvas.app`, 4.5 MiB, ad-hoc signed |
| 自动化 | **58 tests, 0 failures, 0 warnings** |
| UI 说明 | 主面板已在锁屏前通过 Computer Use 实机检查；最终轮设置窗口截图受 macOS 锁屏限制，设置行为由编译、状态测试和代码审计覆盖 |

## 自动化

| 场景 | 预期 | 状态 | 证据 |
|---|---|---|---|
| Swift 单元与集成测试 | 全部通过 | **通过** | 清洁构建；58 tests / 0 failures |
| Release 构建 | App 与 stdio bridge 均可执行 | **通过** | `ClipCanvas` 2.7 MiB；bridge 105 KiB |
| Bundle 元数据 | plist 有效、macOS 14+、Agent | **通过** | `plutil -lint`; `LSMinimumSystemVersion=14.0`; `LSUIElement=true` |
| 代码签名 | ad-hoc 深度签名有效 | **通过** | `codesign --verify --deep --strict`; Identifier `dev.clipcanvas.app` |

## 产品功能

| ID | 场景 | 验收标准 | 状态 | 证据 |
|---|---|---|---|---|
| C01 | 文本捕获 | 复制后 1 秒内显示，重复内容合并并增加次数 | **通过** | Release 进程实测；SQLite 出现验收文本；去重测试 |
| C02 | 富文本捕获 | 保留 HTML/RTF 表示与纯文本 fallback | **通过** | `PasteboardSnapshotTests`, `PasteServiceTests` |
| C03 | URL 捕获 | 识别为 Link；预览默认关闭、开启后可取标题 | **通过** | Release 进程实测 `example.com`; `LinkPreviewServiceTests` |
| C04 | 图片捕获 | PNG/TIFF 识别为 Image 并显示缩略图 | **通过** | Release 进程捕获 1024×1024 AppIcon；PNG test |
| C05 | 多文件捕获 | 一个历史条目保存多个 file URL 与数量 | **通过** | Release 进程实测 README + LICENSE；`fileCount=2` |
| C06 | 搜索 | 文本、标题、来源应用可全文检索 | **通过** | `ClipboardRepositoryTests.testSearchMatchesTextTitleAndSource` |
| C07 | 键盘 | ←/→、Space、Return、Delete、Escape、⌘1…9 工作 | **通过** | Panel key handler 审计；导航与 Quick Paste tests |
| C08 | Clipboard-only | 选择项写回剪贴板但不模拟粘贴 | **通过** | `PasteServiceTests.testClipboardOnlyPerformDoesNotRequireAccessibility` |
| C09 | Active app | 有 Accessibility 时粘贴回原前台应用 | **通过** | 激活/延迟/⌘V 注入路径测试；真实权限由用户首次授权 |
| C10 | Plain Text | 全局设置和按住 Shift 均强制纯文本 | **通过** | `PasteServiceTests.testPlainTextModeOmitsRichRepresentation`; key handler |
| P01 | Useful Links | 内置且不可删除，可固定条目 | **通过** | SQLite migration + repository + view-model tests |
| P02 | 自定义 Pinboard | 创建、选择、固定、浏览和删除完整 | **通过** | repository 与 `PinboardViewModelTests` |
| S01 | 快捷键 | 默认值、编辑、冲突检测与重置 | **通过** | `ShortcutValidationTests`; Carbon registration path audit |
| G01 | 设置 | 登录项、音效、粘贴策略、保留周期与清空历史 | **通过** | Settings persistence、retention、repository tests；Release 编译 |
| L01 | 本地化 | 英文与简体中文无裸 key | **通过** | en/zh-Hans key 集合 `comm -3` 为空 |

## 隐私与 MCP

| ID | 场景 | 验收标准 | 状态 | 证据 |
|---|---|---|---|---|
| R01 | 保守默认 | confidential/transient 开；链接预览、共享显示、MCP 关 | **通过** | `SettingsStoreTests.testPrivacyDefaultsAreConservative` |
| R02 | 忽略应用 | 默认 Passwords/Keychain；自选 bundle id 不入库 | **通过** | Settings default + `PrivacyPolicyTests.testIgnoredBundleIDWins` |
| R03 | 保留策略 | Day/Week/Month/Year/Forever 正确清理且可保留 pins | **通过** | `RetentionPolicyTests`; pinned cleanup repository test |
| R04 | 屏幕共享 | 检测到共享时默认隐藏，界面明确“尽力检测” | **通过（尽力）** | monitor + panel guard + 双语限制文案；公共 API 限制已记录 |
| M01 | MCP 默认关闭 | 请求被拒绝 | **通过** | Settings default + disabled server 503 test |
| M02 | 授权读取 | read 客户端可 list/search/read | **通过** | scoped router tests |
| M03 | 作用域拒绝 | read 客户端调用 write/manage 返回 forbidden | **通过** | read-only write denial test |
| M04 | 即时撤销 | 已撤销 token 下一次请求即 401 | **通过** | repository + HTTP revoked-token tests |
| M05 | 全局关闭 | 关闭 Enable MCP 后所有请求 503/无法连接 | **通过** | disabled server test；App binding start/stop 审计 |
| M06 | 传输安全 | 仅 127.0.0.1，拒绝恶意 Origin/远端 peer/超限 body | **通过** | HTTP security suite；2 MiB limits |
| M07 | stdio bridge | newline JSON-RPC 往返成功；诊断只写 stderr | **通过** | 真实 listener + 子进程 bridge round-trip integration test |

## 明确非目标

| 项目 | 验收 |
|---|---|
| iCloud / CloudKit | **通过**：源码扫描无框架或逻辑 |
| 订阅 / 付费墙 | **通过**：源码扫描无 StoreKit 或订阅逻辑 |
| 官方品牌资源 | **通过**：原创 ClipCanvas 名称、imagegen 图标与视觉 |
| 非 macOS 客户端 | **通过**：Package 仅声明 macOS 14+ |
