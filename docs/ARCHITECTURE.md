# ClipCanvas Architecture

## 总览

```mermaid
flowchart LR
    PB["NSPasteboard<br/>250 ms polling"] --> CP["CaptureService<br/>privacy gate"]
    CP --> REPO["ClipboardRepository"]
    REPO --> DB[("SQLite + FTS5")]
    REPO --> BLOBS[("SHA-256 blob store")]
    REPO --> MODEL["AppModel"]
    MODEL --> PANEL["Bottom NSPanel<br/>SwiftUI cards"]
    PANEL --> PASTE["PasteService"]
    PASTE --> PB
    PASTE --> AX["Accessibility<br/>Cmd+V"]

    CLIENT["Approved AI client"] --> BRIDGE["stdio bridge"]
    BRIDGE --> HTTP["127.0.0.1:49219/mcp"]
    HTTP --> AUTH["Token hash + scopes"]
    AUTH --> ROUTER["MCPToolRouter"]
    ROUTER --> REPO
    ROUTER --> AUDIT[("Audit events")]
```

## 模块

| 模块 | 职责 | 关键类型 |
|---|---|---|
| `ClipCanvasCore` | 数据模型、SQLite、blob、隐私、保留、MCP 协议与工具 | `ClipboardRepository`, `PrivacyPolicy`, `MCPToolRouter` |
| `ClipCanvasApp` | 菜单栏 Agent、捕获、粘贴、全局面板、设置、HTTP MCP | `AppDelegate`, `CaptureService`, `PanelController`, `LocalMCPServer` |
| `ClipCanvasMCPBridge` | newline-delimited stdio ↔ 本机 HTTP | `ClipCanvasMCPBridge` |

## 剪贴板写入流程

```mermaid
sequenceDiagram
    participant OS as NSPasteboard
    participant C as CaptureService
    participant P as PrivacyPolicy
    participant R as ClipboardRepository
    participant U as AppModel

    C->>OS: 检查 changeCount
    C->>P: 来源、类型、文本
    alt internal / ignored / confidential / transient
        P-->>C: 拒绝
    else 允许
        P-->>C: 允许
        C->>R: upsert(ClipboardDraft)
        R->>R: SHA-256 去重、FTS 更新、blob 分流
        R-->>U: ClipboardItem
        U->>U: 刷新卡片与选择
    end
```

## MCP 授权流程

```mermaid
sequenceDiagram
    participant U as 用户
    participant S as Settings
    participant C as AI Client
    participant H as LocalMCPServer
    participant R as MCPToolRouter

    U->>S: 创建客户端并选择 scopes
    S-->>U: 一次性 token / stdio 配置
    C->>H: POST /mcp + Bearer token
    H->>H: loopback、Origin、长度、token hash
    H->>R: JSON-RPC + authorization
    R->>R: tool scope + 参数校验
    R-->>C: content + structuredContent
    U->>S: 撤销客户端
    C->>H: 再次请求
    H-->>C: 401 Unauthorized
```

## 存储

| 数据 | 位置 | 策略 |
|---|---|---|
| 历史元数据 | `clipcanvas.sqlite3` | FTS5；按 `last_copied_at` 保留 |
| 小表示 | `item_representations.inline_data` | 默认阈值 64 KiB |
| 大表示 / 图片 | `blobs/<hash prefix>/…` | SHA-256 内容寻址 |
| MCP 客户端 | `authorized_clients` | 只存 token SHA-256 |
| MCP 审计 | `audit_events` | 方法、结果、条目 ID；无正文 |

## 线程与生命周期

- UI、设置和 AppKit 控制器在 `MainActor`。
- SQLite 使用 `FULLMUTEX` 与递归锁封装事务。
- 剪贴板轮询在主 RunLoop 的轻量 Timer 上，重数据进入 blob 文件。
- MCP listener 使用独立串行队列，每连接只处理一个有界 HTTP/1.1 请求后关闭。
