# Contributing to ClipCanvas

感谢参与 ClipCanvas。提交改动前，请确保行为、本地化和隐私边界同时完整。

## 开发流程

1. 从 `main` 创建短生命周期分支。
2. 行为变更先添加失败测试，再实现最小修复。
3. 用户可见字符串同时补齐 `en` 与 `zh-Hans`。
4. 运行：

```bash
./scripts/run-tests.sh
./scripts/build-app.sh debug
codesign --verify --deep --strict build/ClipCanvas.app
```

5. 在 Pull Request 中说明用户影响、隐私影响和手动验收结果。

## 设计约束

| 领域 | 约束 |
|---|---|
| 数据 | 默认仅本机；不得静默增加同步或遥测 |
| 敏感内容 | 不得削弱 confidential/transient、忽略应用和 MCP 授权 |
| UI | 保持键盘可达；不使用 Paste 品牌资源 |
| 依赖 | 优先系统框架；新增依赖需说明体积、许可与供应链风险 |
| 兼容性 | 最低 macOS 14；Apple Silicon 与 Intel |

## 提交信息

使用简短的命令式主题，例如：

```text
feat: add Pinboard export
fix: preserve rich text on plain fallback
test: cover revoked MCP client
```
