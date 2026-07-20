# Pinboard Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在设置窗口新增全高双栏“分组”Tab，安全管理 Pinboard 元数据、顺序和候选内容关系。

**Architecture:** `ClipboardRepository` 负责事务化更新与排序；`AppModel` 暴露不会改变主面板选择的管理动作；`PinboardManagementState` 保存设置页独立选择、搜索和内容快照；`PinboardsSettingsView` 负责双栏交互。系统 Pinboard 在仓储层与 UI 层双重保护。

**Tech Stack:** Swift 6、SwiftUI、AppKit、SQLite、XCTest、Swift Package Manager

---

## 文件结构

| 文件 | 职责 |
|---|---|
| `Sources/ClipCanvasCore/Storage/ClipboardRepository.swift` | Pinboard 更新、排序、成员关系安全边界 |
| `Sources/ClipCanvasApp/App/AppModel.swift` | 设置页管理动作与主面板同步 |
| `Sources/ClipCanvasApp/Views/PinboardManagementState.swift` | 设置页独立选择、搜索与列表状态 |
| `Sources/ClipCanvasApp/Views/PinboardEditorView.swift` | 统一新增/编辑表单 |
| `Sources/ClipCanvasApp/Views/Settings/PinboardsSettingsView.swift` | 双栏分组管理 UI |
| `Sources/ClipCanvasApp/Views/Settings/SettingsRootView.swift` | 新 Tab 与全高详情容器 |
| `Sources/ClipCanvasApp/Resources/*/Localizable.strings` | 中英文文案 |
| `Tests/ClipCanvasCoreTests/ClipboardRepositoryTests.swift` | 仓储行为测试 |
| `Tests/ClipCanvasAppTests/PinboardViewModelTests.swift` | AppModel 管理动作测试 |
| `Tests/ClipCanvasAppTests/PinboardManagementStateTests.swift` | 设置页状态与搜索测试 |
| `Tests/ClipCanvasAppTests/SettingsNavigationTests.swift` | 设置侧边栏回归测试 |

### Task 1: 补齐 Pinboard 仓储能力

**Files:**
- Modify: `Sources/ClipCanvasCore/Storage/ClipboardRepository.swift`
- Test: `Tests/ClipCanvasCoreTests/ClipboardRepositoryTests.swift`

- [ ] **Step 1: 写更新、排序和数据保留失败测试**

```swift
func testUpdateAndReorderOrdinaryPinboards() throws {
    let first = try repository.createPinboard(name: " First ", color: "cyan", symbol: "pin.fill")
    let second = try repository.createPinboard(name: "Second", color: "blue", symbol: "link")

    try repository.updatePinboard(
        id: first.id,
        name: "Renamed",
        color: "purple",
        symbol: "star.fill"
    )
    try repository.reorderPinboards(ids: [second.id, first.id])

    let boards = try repository.listPinboards()
    XCTAssertEqual(boards.filter { !$0.isSystem }.map(\.id), [second.id, first.id])
    XCTAssertEqual(boards.first(where: { $0.id == first.id })?.name, "Renamed")
}

func testSystemPinboardCannotBeModified() throws {
    XCTAssertThrowsError(
        try repository.updatePinboard(
            id: Pinboard.usefulLinksID,
            name: "Changed",
            color: "pink",
            symbol: "heart.fill"
        )
    ) { error in
        XCTAssertEqual(error as? ClipboardRepositoryError, .systemPinboardCannotBeModified)
    }
}

func testDeletePinboardPreservesClipboardItem() throws {
    let item = try repository.upsert(textDraft("still in history"))
    let board = try repository.createPinboard(name: "Temporary")
    try repository.pin(itemID: item.id, to: board.id)

    try repository.deletePinboard(id: board.id)

    XCTAssertEqual(try repository.item(id: item.id).id, item.id)
}

func testUnpinDoesNotAffectOtherPinboards() throws {
    let item = try repository.upsert(textDraft("shared"))
    let first = try repository.createPinboard(name: "First")
    let second = try repository.createPinboard(name: "Second")
    try repository.pin(itemID: item.id, to: first.id)
    try repository.pin(itemID: item.id, to: second.id)

    try repository.unpin(itemID: item.id, from: first.id)

    XCTAssertTrue(try repository.items(in: first.id).items.isEmpty)
    XCTAssertEqual(try repository.items(in: second.id).items.map(\.id), [item.id])
}
```

- [ ] **Step 2: 运行仓储测试并确认失败**

```bash
swift test --filter ClipboardRepositoryTests
```

Expected: FAIL，提示 `updatePinboard`、`reorderPinboards` 或错误枚举不存在。

- [ ] **Step 3: 实现最小仓储 API**

```swift
public enum ClipboardRepositoryError: Error, Equatable, Sendable {
    case itemNotFound
    case pinboardNotFound
    case systemPinboardCannotBeDeleted
    case systemPinboardCannotBeModified
    case invalidPinboardName
    case invalidPinboardOrder
    case invalidStoredData
    case invalidClientName
    case invalidScopes
}

public func updatePinboard(
    id: UUID,
    name: String,
    color: String,
    symbol: String
) throws {
    guard let board = try listPinboards().first(where: { $0.id == id }) else {
        throw ClipboardRepositoryError.pinboardNotFound
    }
    guard !board.isSystem else {
        throw ClipboardRepositoryError.systemPinboardCannotBeModified
    }
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty else {
        throw ClipboardRepositoryError.invalidPinboardName
    }
    try database.execute(
        "UPDATE pinboards SET name = ?, color = ?, symbol = ? WHERE id = ?",
        bindings: [.text(trimmedName), .text(color), .text(symbol), .text(id.uuidString)]
    )
}

public func reorderPinboards(ids: [UUID]) throws {
    let ordinary = try listPinboards().filter { !$0.isSystem }
    guard ids.count == ordinary.count, Set(ids) == Set(ordinary.map(\.id)) else {
        throw ClipboardRepositoryError.invalidPinboardOrder
    }
    try database.transaction {
        try database.execute("UPDATE pinboards SET sort_index = 0 WHERE is_system = 1")
        for (offset, id) in ids.enumerated() {
            try database.execute(
                "UPDATE pinboards SET sort_index = ? WHERE id = ? AND is_system = 0",
                bindings: [.integer(Int64(offset + 1)), .text(id.uuidString)]
            )
        }
    }
}
```

- [ ] **Step 4: 运行仓储测试并确认通过**

```bash
swift test --filter ClipboardRepositoryTests
```

Expected: `ClipboardRepositoryTests` 全部 PASS。

- [ ] **Step 5: 提交仓储层**

```bash
git add Sources/ClipCanvasCore/Storage/ClipboardRepository.swift
git add Tests/ClipCanvasCoreTests/ClipboardRepositoryTests.swift
git commit -m "feat(core): 补齐分组管理能力"
```

### Task 2: 暴露独立于主面板的 AppModel 管理动作

**Files:**
- Modify: `Sources/ClipCanvasApp/App/AppModel.swift`
- Test: `Tests/ClipCanvasAppTests/PinboardViewModelTests.swift`

- [ ] **Step 1: 写独立读取、更新、排序和移出测试**

```swift
func testSettingsActionsDoNotChangePanelSelection() throws {
    let context = try makeContext()
    defer { try? FileManager.default.removeItem(at: context.root) }
    let first = try context.repository.createPinboard(name: "First")
    let second = try context.repository.createPinboard(name: "Second")
    let item = try context.repository.upsert(textDraft("candidate"))
    try context.repository.pin(itemID: item.id, to: second.id)
    context.model.reload()
    context.model.selectPinboard(first.id)

    let created = context.model.createPinboard(
        name: "Created in Settings",
        color: "cyan",
        symbol: "pin.fill",
        selecting: false
    )
    XCTAssertNotNil(created)
    XCTAssertEqual(context.model.selectedPinboardID, first.id)

    XCTAssertEqual(context.model.pinboardItems(in: second.id).map(\.id), [item.id])
    XCTAssertEqual(context.model.selectedPinboardID, first.id)

    context.model.updatePinboard(id: second.id, name: "Renamed", color: "green", symbol: "star.fill")
    context.model.reorderPinboards(ids: [second.id, first.id, created!.id])
    XCTAssertTrue(context.model.unpin(itemID: item.id, from: second.id))

    XCTAssertEqual(context.model.selectedPinboardID, first.id)
    XCTAssertTrue(context.model.pinboardItems(in: second.id).isEmpty)
    XCTAssertEqual(
        context.model.pinboards.filter { !$0.isSystem }.map(\.id),
        [second.id, first.id, created!.id]
    )
}

private func textDraft(_ text: String) -> ClipboardDraft {
    ClipboardDraft(
        kind: .text,
        plainText: text,
        source: .init(bundleID: "com.apple.TextEdit", name: "TextEdit"),
        representations: [
            .init(uti: "public.utf8-plain-text", data: Data(text.utf8))
        ]
    )
}
```

- [ ] **Step 2: 运行 AppModel 测试并确认失败**

```bash
swift test --filter PinboardViewModelTests
```

Expected: FAIL，提示管理动作不存在。

- [ ] **Step 3: 实现 AppModel 管理动作**

```swift
func pinboardItems(in id: UUID) -> [ClipboardItem] {
    guard let repository else { return [] }
    do {
        let items = try repository.items(in: id, limit: 200).items
        errorMessage = nil
        return items
    } catch {
        errorMessage = error.localizedDescription
        return []
    }
}

@discardableResult
func createPinboard(
    name: String,
    color: String,
    symbol: String,
    selecting: Bool = true
) -> Pinboard? {
    guard let repository else { return nil }
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty else {
        errorMessage = String(localized: "pinboard.name_required")
        return nil
    }
    do {
        let pinboard = try repository.createPinboard(
            name: trimmedName,
            color: color,
            symbol: symbol
        )
        replacePinboards(try repository.listPinboards())
        if selecting { selectPinboard(pinboard.id) }
        isCreatePinboardPresented = false
        errorMessage = nil
        return pinboard
    } catch {
        errorMessage = error.localizedDescription
        return nil
    }
}

@discardableResult
func updatePinboard(id: UUID, name: String, color: String, symbol: String) -> Bool {
    guard let repository else { return false }
    do {
        try repository.updatePinboard(id: id, name: name, color: color, symbol: symbol)
        replacePinboards(try repository.listPinboards())
        errorMessage = nil
        return true
    } catch {
        errorMessage = error.localizedDescription
        return false
    }
}

@discardableResult
func reorderPinboards(ids: [UUID]) -> Bool {
    guard let repository else { return false }
    do {
        try repository.reorderPinboards(ids: ids)
        replacePinboards(try repository.listPinboards())
        errorMessage = nil
        return true
    } catch {
        errorMessage = error.localizedDescription
        return false
    }
}

@discardableResult
func unpin(itemID: UUID, from pinboardID: UUID) -> Bool {
    guard let repository else { return false }
    do {
        try repository.unpin(itemID: itemID, from: pinboardID)
        if selectedPinboardID == pinboardID { reload() }
        errorMessage = nil
        return true
    } catch {
        errorMessage = error.localizedDescription
        return false
    }
}
```

- [ ] **Step 4: 运行 AppModel 测试并确认通过**

```bash
swift test --filter PinboardViewModelTests
```

Expected: `PinboardViewModelTests` 全部 PASS。

- [ ] **Step 5: 提交状态入口**

```bash
git add Sources/ClipCanvasApp/App/AppModel.swift
git add Tests/ClipCanvasAppTests/PinboardViewModelTests.swift
git commit -m "feat(app): 接入分组维护动作"
```

### Task 3: 建立设置页独立状态与搜索

**Files:**
- Create: `Sources/ClipCanvasApp/Views/PinboardManagementState.swift`
- Create: `Tests/ClipCanvasAppTests/PinboardManagementStateTests.swift`

- [ ] **Step 1: 写选择回退和搜索测试**

```swift
func testReconcileSelectsFirstAndFallsBackAfterDeletion() {
    let first = Pinboard(name: "First", sortIndex: 1)
    let second = Pinboard(name: "Second", sortIndex: 2)
    var state = PinboardManagementState()

    state.reconcile(pinboards: [first, second])
    XCTAssertEqual(state.selectedPinboardID, first.id)

    state.selectedPinboardID = second.id
    state.reconcile(pinboards: [first])
    XCTAssertEqual(state.selectedPinboardID, first.id)
}

func testSearchMatchesTitleTextAndSourceIgnoringCase() {
    var state = PinboardManagementState()
    state.items = [
        makeItem(text: "Release note", title: "Launch", source: "Notes"),
        makeItem(text: "Other", title: nil, source: "Safari")
    ]
    state.query = "NOTES"

    XCTAssertEqual(state.filteredItems.map(\.plainText), ["Release note"])
}

private func makeItem(
    text: String,
    title: String?,
    source: String
) -> ClipboardItem {
    ClipboardItem(
        id: UUID(),
        kind: .text,
        plainText: text,
        title: title,
        source: .init(bundleID: nil, name: source),
        contentHash: UUID().uuidString,
        createdAt: Date(),
        lastCopiedAt: Date(),
        copyCount: 1,
        isSensitive: false,
        metadata: .init(),
        representations: []
    )
}
```

- [ ] **Step 2: 运行状态测试并确认失败**

```bash
swift test --filter PinboardManagementStateTests
```

Expected: FAIL，提示 `PinboardManagementState` 不存在。

- [ ] **Step 3: 实现纯状态结构**

```swift
import ClipCanvasCore
import Foundation
import SwiftUI

struct PinboardManagementState {
    var selectedPinboardID: UUID?
    var query = ""
    var items: [ClipboardItem] = []

    var filteredItems: [ClipboardItem] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return items }
        return items.filter { item in
            [item.title, item.plainText, item.source.name]
                .compactMap { $0 }
                .joined(separator: "\n")
                .localizedCaseInsensitiveContains(term)
        }
    }

    mutating func reconcile(pinboards: [Pinboard]) {
        guard !pinboards.isEmpty else {
            selectedPinboardID = nil
            items = []
            return
        }
        if let selectedPinboardID,
           pinboards.contains(where: { $0.id == selectedPinboardID }) {
            return
        }
        selectedPinboardID = pinboards.first?.id
        query = ""
        items = []
    }
}
```

- [ ] **Step 4: 运行状态测试并确认通过**

```bash
swift test --filter PinboardManagementStateTests
```

Expected: `PinboardManagementStateTests` 全部 PASS。

- [ ] **Step 5: 提交独立状态**

```bash
git add Sources/ClipCanvasApp/Views/PinboardManagementState.swift
git add Tests/ClipCanvasAppTests/PinboardManagementStateTests.swift
git commit -m "feat(settings): 新增分组维护状态"
```

### Task 4: 统一 Pinboard 新增与编辑表单

**Files:**
- Modify: `Sources/ClipCanvasApp/Views/PinboardEditorView.swift`
- Modify: `Sources/ClipCanvasApp/Views/HistoryPanelView.swift`
- Test: `Tests/ClipCanvasAppTests/PinboardManagementStateTests.swift`

- [ ] **Step 1: 写编辑初始值测试**

```swift
func testEditorDraftUsesExistingPinboardValues() {
    let board = Pinboard(name: "Code", color: "purple", symbol: "book.fill")
    let draft = PinboardEditorDraft(pinboard: board)

    XCTAssertEqual(draft.name, "Code")
    XCTAssertEqual(draft.color, "purple")
    XCTAssertEqual(draft.symbol, "book.fill")
    XCTAssertTrue(draft.canSave)
}
```

- [ ] **Step 2: 运行测试并确认失败**

```bash
swift test --filter PinboardManagementStateTests
```

Expected: FAIL，提示 `PinboardEditorDraft` 不存在。

- [ ] **Step 3: 实现可复用表单**

```swift
struct PinboardEditorDraft: Equatable {
    var name: String
    var color: String
    var symbol: String

    init(pinboard: Pinboard? = nil) {
        name = pinboard?.name ?? ""
        color = pinboard?.color ?? "cyan"
        symbol = pinboard?.symbol ?? "pin.fill"
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
```

将 `PinboardEditorView` 改为：

```swift
init(pinboard: Pinboard? = nil, onSave: @escaping (String, String, String) -> Void)
```

标题和主按钮分别使用 `pinboard.create` / `pinboard.edit`，现有主面板创建入口改为：

```swift
PinboardEditorView { name, color, symbol in
    model.createPinboard(name: name, color: color, symbol: symbol)
}
```

- [ ] **Step 4: 运行相关测试并确认通过**

```bash
swift test --filter PinboardManagementStateTests
swift test --filter PanelKeyboardRoutingTests
```

Expected: 两组测试全部 PASS。

- [ ] **Step 5: 提交编辑器复用**

```bash
git add Sources/ClipCanvasApp/Views/PinboardEditorView.swift
git add Sources/ClipCanvasApp/Views/HistoryPanelView.swift
git add Tests/ClipCanvasAppTests/PinboardManagementStateTests.swift
git commit -m "refactor(pinboard): 复用分组编辑器"
```

### Task 5: 实现全高双栏分组管理页

**Files:**
- Create: `Sources/ClipCanvasApp/Views/Settings/PinboardsSettingsView.swift`
- Modify: `Sources/ClipCanvasApp/Views/PinboardManagementState.swift`
- Test: `Tests/ClipCanvasAppTests/PinboardManagementStateTests.swift`

- [ ] **Step 1: 写普通分组排序与移除本地快照测试**

```swift
func testMoveOrdinaryPinboardsKeepsSystemFirst() {
    let system = Pinboard(name: "Useful Links", sortIndex: 0, isSystem: true)
    let first = Pinboard(name: "First", sortIndex: 1)
    let second = Pinboard(name: "Second", sortIndex: 2)
    var state = PinboardManagementState()

    let ids = state.reorderedOrdinaryIDs(
        pinboards: [system, first, second],
        fromOffsets: IndexSet(integer: 1),
        toOffset: 0
    )

    XCTAssertEqual(ids, [second.id, first.id])
}

func testRemovingItemUpdatesSnapshot() {
    let item = makeItem(text: "Candidate", title: nil, source: "Notes")
    var state = PinboardManagementState(items: [item])

    state.remove(itemID: item.id)

    XCTAssertTrue(state.items.isEmpty)
}
```

- [ ] **Step 2: 运行状态测试并确认失败**

```bash
swift test --filter PinboardManagementStateTests
```

Expected: FAIL，提示排序或移除辅助方法不存在。

- [ ] **Step 3: 实现状态辅助方法**

```swift
mutating func remove(itemID: UUID) {
    items.removeAll { $0.id == itemID }
}

func reorderedOrdinaryIDs(
    pinboards: [Pinboard],
    fromOffsets: IndexSet,
    toOffset: Int
) -> [UUID] {
    var ordinary = pinboards.filter { !$0.isSystem }
    ordinary.move(fromOffsets: fromOffsets, toOffset: toOffset)
    return ordinary.map(\.id)
}
```

- [ ] **Step 4: 实现 `PinboardsSettingsView`**

视图根结构固定为：

```swift
struct PinboardsSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var state = PinboardManagementState()
    @State private var editorPinboard: Pinboard?
    @State private var isCreating = false
    @State private var deleteCandidate: Pinboard?

    var body: some View {
        HStack(spacing: 12) {
            pinboardList.frame(width: 190)
            contentPane.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear(perform: reconcileAndLoad)
        .onReceive(model.$pinboards) { _ in reconcileAndLoad() }
        .onChange(of: state.selectedPinboardID) { oldValue, newValue in
            guard oldValue != newValue else { return }
            state.query = ""
            loadSelected()
        }
        .sheet(isPresented: $isCreating) { createEditor }
        .sheet(item: $editorPinboard) { editEditor($0) }
        .alert(
            "pinboard.delete",
            isPresented: Binding(
                get: { deleteCandidate != nil },
                set: { if !$0 { deleteCandidate = nil } }
            ),
            presenting: deleteCandidate
        ) { board in
            Button("common.cancel", role: .cancel) {}
            Button("pinboard.delete", role: .destructive) {
                model.deletePinboard(board.id)
                deleteCandidate = nil
            }
        } message: { _ in
            Text("pinboard.delete_preserves_history")
        }
    }
}
```

左栏实现：

```swift
private var pinboardList: some View {
    VStack(spacing: 8) {
        HStack {
            Text("settings.pinboards").font(.headline)
            Spacer()
            Button {
                isCreating = true
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
        }
        List(selection: $state.selectedPinboardID) {
            ForEach(model.pinboards.filter(\.isSystem)) { pinboard in
                pinboardRow(pinboard).tag(pinboard.id)
            }
            ForEach(model.pinboards.filter { !$0.isSystem }) { pinboard in
                pinboardRow(pinboard).tag(pinboard.id)
            }
            .onMove { source, destination in
                model.reorderPinboards(
                    ids: state.reorderedOrdinaryIDs(
                        pinboards: model.pinboards,
                        fromOffsets: source,
                        toOffset: destination
                    )
                )
            }
        }
        .listStyle(.sidebar)
    }
    .padding(12)
    .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 14))
}

private func pinboardRow(_ pinboard: Pinboard) -> some View {
    HStack(spacing: 8) {
        Circle()
            .fill(PinboardColorPalette.color(for: pinboard.color))
            .frame(width: 8, height: 8)
        Image(systemName: pinboard.symbol)
        Text(pinboard.name).lineLimit(1)
        Spacer()
        if pinboard.isSystem {
            Image(systemName: "lock.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
```

右栏实现：

```swift
private var contentPane: some View {
    VStack(spacing: 12) {
        if let error = model.errorMessage {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        if let selectedPinboard {
            contentHeader(selectedPinboard)
            TextField("pinboard.search", text: $state.query)
                .textFieldStyle(.roundedBorder)
            if state.filteredItems.isEmpty {
                ContentUnavailableView(
                    state.query.isEmpty ? "pinboard.empty" : "pinboard.no_results",
                    systemImage: state.query.isEmpty ? "pin.slash" : "magnifyingglass"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(state.filteredItems) { item in
                            candidateRow(item, pinboardID: selectedPinboard.id)
                        }
                    }
                }
            }
        } else {
            ContentUnavailableView(
                "pinboard.empty_groups",
                systemImage: "square.grid.2x2"
            )
        }
    }
    .padding(16)
    .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 14))
}

private var selectedPinboard: Pinboard? {
    guard let id = state.selectedPinboardID else { return nil }
    return model.pinboards.first { $0.id == id }
}

private func contentHeader(_ pinboard: Pinboard) -> some View {
    HStack {
        VStack(alignment: .leading, spacing: 3) {
            Label(pinboard.name, systemImage: pinboard.symbol)
                .font(.headline)
            Text(String(
                format: String(localized: "pinboard.items_count"),
                state.items.count
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        if !pinboard.isSystem {
            Button("pinboard.edit") { editorPinboard = pinboard }
            Button("pinboard.delete", role: .destructive) {
                deleteCandidate = pinboard
            }
        }
    }
}

private func candidateRow(
    _ item: ClipboardItem,
    pinboardID: UUID
) -> some View {
    HStack(spacing: 12) {
        Image(systemName: "doc.on.clipboard")
            .frame(width: 22)
            .foregroundStyle(.secondary)
        VStack(alignment: .leading, spacing: 3) {
            Text(item.title ?? item.plainText ?? item.kind.rawValue)
                .lineLimit(2)
            Text(item.source.name)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Spacer()
        Button("pinboard.remove") {
            if model.unpin(itemID: item.id, from: pinboardID) {
                state.remove(itemID: item.id)
            }
        }
        .buttonStyle(.borderless)
    }
    .padding(10)
    .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
}

private var createEditor: some View {
    PinboardEditorView { name, color, symbol in
        guard let created = model.createPinboard(
            name: name,
            color: color,
            symbol: symbol,
            selecting: false
        ) else { return }
        state.selectedPinboardID = created.id
    }
}

private func editEditor(_ pinboard: Pinboard) -> some View {
    PinboardEditorView(pinboard: pinboard) { name, color, symbol in
        model.updatePinboard(
            id: pinboard.id,
            name: name,
            color: color,
            symbol: symbol
        )
    }
}

private func reconcileAndLoad() {
    let previousSelection = state.selectedPinboardID
    state.reconcile(pinboards: model.pinboards)
    if state.selectedPinboardID != previousSelection || state.items.isEmpty {
        loadSelected()
    }
}

private func loadSelected() {
    guard let id = state.selectedPinboardID else {
        state.items = []
        return
    }
    state.items = model.pinboardItems(in: id)
}
```

“移出”按钮顺序固定为：先调用 `model.unpin(itemID:from:)`，成功后调用 `state.remove(itemID:)`；系统分组也允许移出内容。编辑与删除按钮只在普通分组显示。

- [ ] **Step 5: 运行状态与构建测试**

```bash
swift test --filter PinboardManagementStateTests
swift build
```

Expected: 测试 PASS，Debug 构建完成。

- [ ] **Step 6: 提交双栏页面**

```bash
git add Sources/ClipCanvasApp/Views/PinboardManagementState.swift
git add Sources/ClipCanvasApp/Views/Settings/PinboardsSettingsView.swift
git add Tests/ClipCanvasAppTests/PinboardManagementStateTests.swift
git commit -m "feat(settings): 新增分组管理页"
```

### Task 6: 接入设置导航与中英文文案

**Files:**
- Modify: `Sources/ClipCanvasApp/Views/Settings/SettingsRootView.swift`
- Modify: `Sources/ClipCanvasApp/Resources/en.lproj/Localizable.strings`
- Modify: `Sources/ClipCanvasApp/Resources/zh-Hans.lproj/Localizable.strings`
- Create: `Tests/ClipCanvasAppTests/SettingsNavigationTests.swift`

- [ ] **Step 1: 写设置导航顺序测试**

```swift
func testPinboardsSectionFollowsGeneral() {
    XCTAssertEqual(
        SettingsRootView.Section.allCases.map(\.rawValue),
        ["general", "pinboards", "privacy", "shortcuts", "mcp", "about"]
    )
    XCTAssertEqual(SettingsRootView.Section.pinboards.symbol, "square.grid.2x2")
}
```

- [ ] **Step 2: 运行导航测试并确认失败**

```bash
swift test --filter SettingsNavigationTests
```

Expected: FAIL，提示 `.pinboards` 不存在。

- [ ] **Step 3: 接入全高 Tab**

`Section` 新增：

```swift
case pinboards
```

标题与图标分支新增：

```swift
case .pinboards: "settings.pinboards"
case .pinboards: "square.grid.2x2"
```

详情容器改为：

```swift
Group {
    if selection == .pinboards {
        PinboardsSettingsView()
            .frame(
                maxWidth: SettingsLayoutMetrics.standard.contentWidth,
                maxHeight: .infinity,
                alignment: .topLeading
            )
            .padding(SettingsLayoutMetrics.standard.pagePadding)
    } else {
        ScrollView {
            settingsDetail
                .frame(
                    maxWidth: SettingsLayoutMetrics.standard.contentWidth,
                    alignment: .topLeading
                )
                .padding(SettingsLayoutMetrics.standard.pagePadding)
        }
    }
}
```

`settingsDetail` 保留 General、Privacy、Shortcuts、MCP、About 分支；`.pinboards` 分支返回 `EmptyView()`，因为全高页面已提前处理。

- [ ] **Step 4: 补齐中英文键值**

```text
settings.pinboards
pinboard.edit
pinboard.search
pinboard.empty
pinboard.no_results
pinboard.remove
pinboard.items_count
pinboard.delete_preserves_history
pinboard.system_locked
```

中文采用“分组、编辑分组、搜索当前分组、移出分组”等；英文采用 “Pinboards、Edit Pinboard、Search this Pinboard、Remove”等。

- [ ] **Step 5: 运行导航测试与完整测试**

```bash
swift test --filter SettingsNavigationTests
swift test
```

Expected: 所有测试 PASS。

- [ ] **Step 6: 提交导航与文案**

```bash
git add Sources/ClipCanvasApp/Views/Settings/SettingsRootView.swift
git add Sources/ClipCanvasApp/Resources/en.lproj/Localizable.strings
git add Sources/ClipCanvasApp/Resources/zh-Hans.lproj/Localizable.strings
git add Tests/ClipCanvasAppTests/SettingsNavigationTests.swift
git commit -m "feat(settings): 接入分组设置入口"
```

### Task 7: 完整验证并打开设置页

**Files:**
- Verify only

- [ ] **Step 1: 检查格式与未预期变更**

```bash
git diff --check
git status --short
```

Expected: 无空白错误；只有计划内文件或 `.superpowers/` 临时目录。

- [ ] **Step 2: 运行完整测试**

```bash
swift test
```

Expected: 全部测试 PASS，0 failures。

- [ ] **Step 3: 构建 Release**

```bash
swift build -c release
```

Expected: `Build complete!`。

- [ ] **Step 4: 启动应用并打开设置**

```bash
pkill -x ClipCanvasApp || true
.build/release/ClipCanvasApp --show-settings
```

Expected: 设置窗口可见，侧边栏包含“分组”，双栏内容可操作。

- [ ] **Step 5: 记录最终提交**

```bash
git log --oneline -8
git status --short
```

Expected: 功能提交完整，`.superpowers/` 未被提交。
