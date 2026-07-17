# ClipCanvas Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native, open-source macOS clipboard manager that matches Paste's core capture, horizontal history, Pinboard, privacy, shortcut, paste, and authorized MCP experience without iCloud or subscriptions.

**Architecture:** A Swift Package produces a menu-bar SwiftUI/AppKit app, a reusable `ClipCanvasCore` library, and a stdio MCP bridge. The app stores metadata in SQLite and large representations in a content-addressed blob directory, exposes an authenticated loopback MCP endpoint, and packages both executables into a runnable `.app`.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Carbon, ServiceManagement, SQLite3, Network, XCTest, Bash, GitHub Actions.

## Global Constraints

- Product name is `ClipCanvas`; bundle identifier is `dev.clipcanvas.app`.
- Deployment target is macOS 14.0.
- Do not enable App Sandbox.
- Do not add iCloud, CloudKit, subscriptions, paid gates, official Paste assets, or official private protocols.
- All clipboard history remains local; network access only occurs when link previews are enabled.
- MCP is disabled by default and follows stable protocol version `2025-11-25`.
- The HTTP MCP listener binds only to `127.0.0.1:49219`, validates Origin, and requires a bearer token.
- Every user-visible string has English and Simplified Chinese localization.
- Core behavior is implemented test-first.

---

## File Map

| Path | Responsibility |
|---|---|
| `Package.swift` | SwiftPM products, targets, resources and macOS floor |
| `Configuration/Info.plist` | Agent bundle metadata, URL scheme and usage strings |
| `Sources/ClipCanvasCore/Models/ClipboardModels.swift` | Immutable domain types |
| `Sources/ClipCanvasCore/Models/SettingsModels.swift` | Settings, shortcuts and MCP authorization types |
| `Sources/ClipCanvasCore/Storage/SQLiteDatabase.swift` | SQLite connection, migrations and transaction primitive |
| `Sources/ClipCanvasCore/Storage/BlobStore.swift` | Content-addressed file representations |
| `Sources/ClipCanvasCore/Storage/ClipboardRepository.swift` | History, search, Pinboard, client and audit persistence |
| `Sources/ClipCanvasCore/Services/PrivacyPolicy.swift` | Ignore-app, transient and confidential decisions |
| `Sources/ClipCanvasCore/Services/RetentionPolicy.swift` | Retention cutoffs and cleanup |
| `Sources/ClipCanvasCore/MCP/MCPProtocol.swift` | JSON-RPC and MCP request/response schemas |
| `Sources/ClipCanvasCore/MCP/MCPToolRouter.swift` | Tool catalog, scope enforcement and calls |
| `Sources/ClipCanvasApp/App/ClipCanvasApp.swift` | SwiftUI entry point and settings scenes |
| `Sources/ClipCanvasApp/App/AppDelegate.swift` | Menu-bar lifecycle and service wiring |
| `Sources/ClipCanvasApp/App/AppModel.swift` | Main-actor observable product state |
| `Sources/ClipCanvasApp/Clipboard/PasteboardSnapshot.swift` | NSPasteboard parsing and writing |
| `Sources/ClipCanvasApp/Clipboard/CaptureService.swift` | Change polling, source capture and repository ingestion |
| `Sources/ClipCanvasApp/Clipboard/PasteService.swift` | Clipboard-only and active-app paste strategies |
| `Sources/ClipCanvasApp/HotKeys/GlobalHotKeyService.swift` | Carbon registration and event dispatch |
| `Sources/ClipCanvasApp/Panel/PanelController.swift` | Bottom non-activating panel placement and visibility |
| `Sources/ClipCanvasApp/Views/HistoryPanelView.swift` | Search, tabs, keyboard routing and horizontal card flow |
| `Sources/ClipCanvasApp/Views/ClipboardCardView.swift` | Original card visual and previews |
| `Sources/ClipCanvasApp/Views/Settings/SettingsRootView.swift` | Settings navigation shell |
| `Sources/ClipCanvasApp/Views/Settings/GeneralSettingsView.swift` | Login, sound, paste and retention controls |
| `Sources/ClipCanvasApp/Views/Settings/PrivacySettingsView.swift` | Privacy controls and ignored apps |
| `Sources/ClipCanvasApp/Views/Settings/ShortcutsSettingsView.swift` | Recorder, conflicts and reset |
| `Sources/ClipCanvasApp/Views/Settings/MCPSettingsView.swift` | MCP state, clients, config and audit |
| `Sources/ClipCanvasApp/Views/Settings/AboutView.swift` | Version, license and privacy summary |
| `Sources/ClipCanvasApp/MCP/LocalMCPServer.swift` | Authenticated loopback HTTP MCP transport |
| `Sources/ClipCanvasMCPBridge/main.swift` | newline-delimited stdio to HTTP bridge |
| `Sources/ClipCanvasApp/Resources/*/Localizable.strings` | English and Simplified Chinese copy |
| `Tests/ClipCanvasCoreTests/*` | Storage, policy and MCP behavior tests |
| `Tests/ClipCanvasAppTests/*` | Snapshot parsing and view-model tests |
| `scripts/build-app.sh` | Build and assemble `build/ClipCanvas.app` |
| `scripts/run-tests.sh` | Deterministic local/CI test command |
| `docs/ACCEPTANCE.md` | Manual end-to-end checklist |
| `.github/workflows/ci.yml` | macOS build and tests |
| `README.md`, `LICENSE`, `CONTRIBUTING.md` | Open-source handoff |

---

### Task 1: Swift Package and runnable agent skeleton

**Files:**
- Create: `Package.swift`
- Create: `Configuration/Info.plist`
- Create: `Sources/ClipCanvasApp/App/ClipCanvasApp.swift`
- Create: `Sources/ClipCanvasApp/App/AppDelegate.swift`
- Create: `Sources/ClipCanvasApp/App/AppModel.swift`
- Create: `Sources/ClipCanvasApp/Views/HistoryPanelView.swift`
- Create: `Sources/ClipCanvasApp/Resources/en.lproj/Localizable.strings`
- Create: `Sources/ClipCanvasApp/Resources/zh-Hans.lproj/Localizable.strings`
- Create: `scripts/build-app.sh`
- Test: `Tests/ClipCanvasAppTests/AppModelTests.swift`

**Interfaces:**
- Produces: `@MainActor final class AppModel: ObservableObject`
- Produces: `@main struct ClipCanvasApp: App`
- Produces: `build/ClipCanvas.app`

- [ ] **Step 1: Write the failing observable-state test**

```swift
@MainActor
func testPanelStartsHiddenAndToggles() {
    let model = AppModel()
    XCTAssertFalse(model.isPanelPresented)
    model.togglePanel()
    XCTAssertTrue(model.isPanelPresented)
}
```

- [ ] **Step 2: Run the test and verify RED**

```bash
swift test --filter AppModelTests/testPanelStartsHiddenAndToggles
```

Expected: failure because the package and `AppModel` do not exist.

- [ ] **Step 3: Add package and minimal app**

```swift
// Required AppModel surface.
@MainActor
final class AppModel: ObservableObject {
    @Published var isPanelPresented = false
    func togglePanel() { isPanelPresented.toggle() }
}
```

`Info.plist` sets `LSUIElement=true`, `LSMinimumSystemVersion=14.0`, and `CFBundleIdentifier=dev.clipcanvas.app`. The SwiftUI app owns a `MenuBarExtra` and a Settings scene.

- [ ] **Step 4: Build the `.app` bundle**

```bash
./scripts/build-app.sh debug
test -x build/ClipCanvas.app/Contents/MacOS/ClipCanvas
```

Expected: both commands exit 0.

- [ ] **Step 5: Run all tests and commit**

```bash
swift test
git add Package.swift Configuration Sources Tests scripts
git commit -m "feat: bootstrap ClipCanvas macOS agent"
```

### Task 2: Domain models and SQLite migration

**Files:**
- Create: `Sources/ClipCanvasCore/Models/ClipboardModels.swift`
- Create: `Sources/ClipCanvasCore/Models/SettingsModels.swift`
- Create: `Sources/ClipCanvasCore/Storage/SQLiteDatabase.swift`
- Test: `Tests/ClipCanvasCoreTests/SQLiteDatabaseTests.swift`

**Interfaces:**
- Produces: `ClipboardItem`, `ClipboardKind`, `ClipboardRepresentation`, `Pinboard`
- Produces: `SQLiteDatabase.init(url:)`, `read`, `write`, `transaction`

- [ ] **Step 1: Write migration and model round-trip tests**

```swift
func testMigrationCreatesHistoryAndPinboardTables() throws {
    let database = try SQLiteDatabase(url: temporaryDatabaseURL())
    let names = try database.tableNames()
    XCTAssertTrue(names.contains("clipboard_items"))
    XCTAssertTrue(names.contains("item_representations"))
    XCTAssertTrue(names.contains("pinboards"))
    XCTAssertTrue(names.contains("authorized_clients"))
}
```

- [ ] **Step 2: Verify RED**

```bash
swift test --filter SQLiteDatabaseTests
```

Expected: missing types or missing tables.

- [ ] **Step 3: Implement schema version 1**

```sql
CREATE TABLE clipboard_items (...);
CREATE TABLE item_representations (...);
CREATE VIRTUAL TABLE clipboard_fts USING fts5(...);
CREATE TABLE pinboards (...);
CREATE TABLE pinboard_items (...);
CREATE TABLE authorized_clients (...);
CREATE TABLE audit_events (...);
PRAGMA user_version = 1;
```

The migration runs transactionally and creates the system `Useful Links` Pinboard with a stable UUID.

- [ ] **Step 4: Verify GREEN and commit**

```bash
swift test --filter SQLiteDatabaseTests
git add Sources/ClipCanvasCore Tests/ClipCanvasCoreTests
git commit -m "feat: add clipboard domain and SQLite schema"
```

### Task 3: Blob storage and history repository

**Files:**
- Create: `Sources/ClipCanvasCore/Storage/BlobStore.swift`
- Create: `Sources/ClipCanvasCore/Storage/ClipboardRepository.swift`
- Test: `Tests/ClipCanvasCoreTests/BlobStoreTests.swift`
- Test: `Tests/ClipCanvasCoreTests/ClipboardRepositoryTests.swift`

**Interfaces:**
- Produces: `BlobStore.put(data:fileExtension:) -> BlobReference`
- Produces: `ClipboardRepository.upsert(_:)`, `list(_:)`, `search(_:)`, `item(id:)`, `delete(id:)`, `eraseHistory`
- Produces: `ClipboardRepository.createPinboard`, `pin`, `unpin`, `listPinboards`

- [ ] **Step 1: Write failing content-addressed and dedupe tests**

```swift
func testRepeatedContentReusesItemAndIncrementsCopyCount() throws {
    let first = try repository.upsert(sampleText("same"))
    let second = try repository.upsert(sampleText("same"))
    XCTAssertEqual(first.id, second.id)
    XCTAssertEqual(second.copyCount, 2)
    XCTAssertEqual(try repository.list(.init(limit: 50)).items.count, 1)
}
```

- [ ] **Step 2: Verify RED**

```bash
swift test --filter BlobStoreTests
swift test --filter ClipboardRepositoryTests
```

- [ ] **Step 3: Implement atomic persistence**

The repository computes SHA-256 across normalized representations, writes external blobs before the DB transaction, upserts duplicates by hash, updates FTS rows, preserves Pinboard links, and uses stable `(lastCopiedAt, id)` pagination.

- [ ] **Step 4: Verify search, Pinboard and cleanup behavior**

```bash
swift test --filter BlobStoreTests
swift test --filter ClipboardRepositoryTests
```

Expected: all tests pass and temporary blob orphans are removed after failed writes.

- [ ] **Step 5: Commit**

```bash
git add Sources/ClipCanvasCore/Storage Tests/ClipCanvasCoreTests
git commit -m "feat: persist searchable clipboard history"
```

### Task 4: Privacy and retention policies

**Files:**
- Create: `Sources/ClipCanvasCore/Services/PrivacyPolicy.swift`
- Create: `Sources/ClipCanvasCore/Services/RetentionPolicy.swift`
- Test: `Tests/ClipCanvasCoreTests/PrivacyPolicyTests.swift`
- Test: `Tests/ClipCanvasCoreTests/RetentionPolicyTests.swift`

**Interfaces:**
- Produces: `PrivacyPolicy.evaluate(_:) -> CaptureDecision`
- Produces: `RetentionPeriod.cutoff(relativeTo:) -> Date?`

- [ ] **Step 1: Write one failing test per privacy reason**

```swift
func testConcealedTypeIsIgnored() {
    let input = CaptureCandidate(sourceBundleID: "com.apple.TextEdit",
                                 types: ["org.nspasteboard.ConcealedType"],
                                 plainText: "secret")
    XCTAssertEqual(policy.evaluate(input), .ignored(.concealed))
}
```

Add equivalent tests for transient, internal marker, ignored bundle ID, private-key text, ordinary code, and disabled confidential detection.

- [ ] **Step 2: Verify RED**

```bash
swift test --filter PrivacyPolicyTests
swift test --filter RetentionPolicyTests
```

- [ ] **Step 3: Implement ordered rules and exact cutoffs**

Use explicit pasteboard UTI sets plus bounded, high-confidence regular expressions. Retention maps Day/Week/Month/Year to calendar date arithmetic and Forever to `nil`.

- [ ] **Step 4: Verify GREEN and commit**

```bash
swift test --filter PrivacyPolicyTests
swift test --filter RetentionPolicyTests
git add Sources/ClipCanvasCore/Services Tests/ClipCanvasCoreTests
git commit -m "feat: enforce clipboard privacy and retention"
```

### Task 5: Pasteboard capture and active-app paste

**Files:**
- Create: `Sources/ClipCanvasApp/Clipboard/PasteboardSnapshot.swift`
- Create: `Sources/ClipCanvasApp/Clipboard/CaptureService.swift`
- Create: `Sources/ClipCanvasApp/Clipboard/PasteService.swift`
- Test: `Tests/ClipCanvasAppTests/PasteboardSnapshotTests.swift`
- Test: `Tests/ClipCanvasAppTests/CaptureServiceTests.swift`

**Interfaces:**
- Produces: `PasteboardSnapshotReader.read(from:source:) -> CaptureCandidate?`
- Produces: `CaptureService.start()`, `stop()`, `captureNow()`
- Produces: `PasteService.perform(item:strategy:plainText:) async throws`

- [ ] **Step 1: Write failing parser tests**

Use a unique named `NSPasteboard` in tests and cover plain text, URL, PNG image, HTML+plain fallback, and multiple file URLs.

```swift
func testMultipleFileURLsBecomeOneFilesItem() throws {
    pasteboard.writeObjects([firstURL as NSURL, secondURL as NSURL])
    let item = try XCTUnwrap(reader.read(from: pasteboard, source: source))
    XCTAssertEqual(item.kind, .files)
    XCTAssertEqual(item.metadata.fileCount, 2)
}
```

- [ ] **Step 2: Verify RED**

```bash
swift test --filter PasteboardSnapshotTests
```

- [ ] **Step 3: Implement capture polling**

Poll `NSPasteboard.general.changeCount` every 250ms on a utility task, snapshot `NSWorkspace.shared.frontmostApplication` when a change is observed, run `PrivacyPolicy`, and deliver repository/UI changes on `MainActor`.

- [ ] **Step 4: Implement paste strategies**

Write all safe representations plus `dev.clipcanvas.internal-write`; hide the panel; for `activeApp`, reactivate the saved target and emit Command-V via `CGEvent`. If accessibility is unavailable, throw `PasteError.accessibilityDenied` and retain clipboard content.

- [ ] **Step 5: Verify and commit**

```bash
swift test --filter PasteboardSnapshotTests
swift test --filter CaptureServiceTests
git add Sources/ClipCanvasApp/Clipboard Tests/ClipCanvasAppTests
git commit -m "feat: capture and replay macOS pasteboard content"
```

### Task 6: Hotkeys, panel controller and horizontal history UX

**Files:**
- Create: `Sources/ClipCanvasApp/HotKeys/GlobalHotKeyService.swift`
- Create: `Sources/ClipCanvasApp/Panel/PanelController.swift`
- Modify: `Sources/ClipCanvasApp/App/AppDelegate.swift`
- Modify: `Sources/ClipCanvasApp/App/AppModel.swift`
- Modify: `Sources/ClipCanvasApp/Views/HistoryPanelView.swift`
- Create: `Sources/ClipCanvasApp/Views/ClipboardCardView.swift`
- Test: `Tests/ClipCanvasAppTests/AppModelNavigationTests.swift`
- Test: `Tests/ClipCanvasAppTests/ShortcutValidationTests.swift`

**Interfaces:**
- Produces: `GlobalHotKeyService.register(action:shortcut:)`
- Produces: `PanelController.show(on:)`, `hide()`, `toggle()`
- Extends `AppModel` with `items`, `pinboards`, `selection`, `query`, `quickPaste(index:)`

- [ ] **Step 1: Write failing selection/navigation tests**

```swift
func testMoveSelectionDoesNotEscapeVisibleItems() {
    model.replaceItems([a, b, c])
    model.moveSelection(by: -1)
    XCTAssertEqual(model.selectedItemID, a.id)
    model.moveSelection(by: 10)
    XCTAssertEqual(model.selectedItemID, c.id)
}
```

- [ ] **Step 2: Verify RED**

```bash
swift test --filter AppModelNavigationTests
swift test --filter ShortcutValidationTests
```

- [ ] **Step 3: Implement Carbon hotkeys and AppKit panel**

The panel is a borderless, floating, full-space auxiliary `NSPanel` placed at the bottom of the screen that contained the mouse. It becomes key for search and keyboard navigation while remembering the prior active application.

- [ ] **Step 4: Build the original card UI**

Use a dark material background, 238×180 cards, type-color headers, app icons, lazy thumbnails, relative time, metadata footers, selected outline, Quick Paste badges, search field, Clipboard/Pinboard tabs, and empty states.

- [ ] **Step 5: Verify tests and launch smoke test**

```bash
swift test --filter AppModelNavigationTests
swift test --filter ShortcutValidationTests
./scripts/build-app.sh debug
open build/ClipCanvas.app
```

Expected: menu-bar item appears and `⇧⌘V` toggles the bottom panel.

- [ ] **Step 6: Commit**

```bash
git add Sources/ClipCanvasApp Tests/ClipCanvasAppTests
git commit -m "feat: add keyboard-first horizontal history panel"
```

### Task 7: Pinboards, search, preview and card actions

**Files:**
- Modify: `Sources/ClipCanvasApp/App/AppModel.swift`
- Modify: `Sources/ClipCanvasApp/Views/HistoryPanelView.swift`
- Modify: `Sources/ClipCanvasApp/Views/ClipboardCardView.swift`
- Create: `Sources/ClipCanvasApp/Views/ItemPreviewView.swift`
- Create: `Sources/ClipCanvasApp/Views/PinboardEditorView.swift`
- Test: `Tests/ClipCanvasAppTests/PinboardViewModelTests.swift`

**Interfaces:**
- Produces: `AppModel.selectPinboard`, `createPinboard`, `pinSelected`, `deleteSelected`, `eraseHistory`

- [ ] **Step 1: Write failing Pinboard state tests**

Test system Useful Links presence, creation order, switching, pin/unpin, search isolation, deletion of a custom board, and prohibition on deleting system boards.

- [ ] **Step 2: Verify RED**

```bash
swift test --filter PinboardViewModelTests
```

- [ ] **Step 3: Implement Pinboard and actions**

Add context menus, keyboard delete confirmation, card pin affordance, Pinboard editor sheet, top-tab switching, next/previous shortcuts, search debounce, and large preview presentation.

- [ ] **Step 4: Verify and commit**

```bash
swift test --filter PinboardViewModelTests
swift test
git add Sources/ClipCanvasApp Tests/ClipCanvasAppTests
git commit -m "feat: add Pinboards search and item actions"
```

### Task 8: Complete settings, login item and localization

**Files:**
- Create: `Sources/ClipCanvasApp/Views/Settings/SettingsRootView.swift`
- Create: `Sources/ClipCanvasApp/Views/Settings/GeneralSettingsView.swift`
- Create: `Sources/ClipCanvasApp/Views/Settings/PrivacySettingsView.swift`
- Create: `Sources/ClipCanvasApp/Views/Settings/ShortcutsSettingsView.swift`
- Create: `Sources/ClipCanvasApp/Views/Settings/AboutView.swift`
- Create: `Sources/ClipCanvasApp/Services/SettingsStore.swift`
- Create: `Sources/ClipCanvasApp/Services/LoginItemService.swift`
- Create: `Sources/ClipCanvasApp/Services/LinkPreviewService.swift`
- Modify: localization files
- Test: `Tests/ClipCanvasAppTests/SettingsStoreTests.swift`

**Interfaces:**
- Produces: `SettingsStore` backed by `UserDefaults`
- Produces: `LoginItemService.setEnabled(_:)`
- Produces: `LinkPreviewService.preview(for:) async`

- [ ] **Step 1: Write failing settings persistence tests**

```swift
func testPrivacyDefaultsAreConservative() {
    let store = SettingsStore(defaults: isolatedDefaults())
    XCTAssertTrue(store.ignoreConfidential)
    XCTAssertTrue(store.ignoreTransient)
    XCTAssertFalse(store.generateLinkPreviews)
    XCTAssertFalse(store.enableMCP)
}
```

- [ ] **Step 2: Verify RED**

```bash
swift test --filter SettingsStoreTests
```

- [ ] **Step 3: Implement Paste-aligned settings**

Build the five-section sidebar, General behavior, Privacy toggles and app picker, shortcut recorder/reset, About copy, `SMAppService.mainApp`, link-preview timeout/cache, destructive history confirmation, and accessibility help.

- [ ] **Step 4: Complete en/zh-Hans localization**

Run a source-string inventory and ensure every user-visible string uses localization keys.

- [ ] **Step 5: Verify and commit**

```bash
swift test --filter SettingsStoreTests
./scripts/build-app.sh debug
git add Sources/ClipCanvasApp Tests/ClipCanvasAppTests
git commit -m "feat: complete privacy general and shortcut settings"
```

### Task 9: MCP protocol, scope router and authorization persistence

**Files:**
- Create: `Sources/ClipCanvasCore/MCP/MCPProtocol.swift`
- Create: `Sources/ClipCanvasCore/MCP/MCPToolRouter.swift`
- Modify: `Sources/ClipCanvasCore/Storage/ClipboardRepository.swift`
- Test: `Tests/ClipCanvasCoreTests/MCPProtocolTests.swift`
- Test: `Tests/ClipCanvasCoreTests/MCPToolRouterTests.swift`
- Test: `Tests/ClipCanvasCoreTests/AuthorizationTests.swift`

**Interfaces:**
- Produces: `MCPRequest`, `MCPResponse`, `MCPToolDefinition`
- Produces: `MCPToolRouter.handle(request:authorization:) async -> MCPResponse`
- Produces: client create/revoke/authorize and audit repository APIs

- [ ] **Step 1: Write failing MCP lifecycle and scope tests**

Cover `initialize`, deterministic `tools/list`, read tool success, write tool denial with read-only scope, invalid args, missing item, token hashing, and immediate revoke.

- [ ] **Step 2: Verify RED**

```bash
swift test --filter MCPProtocolTests
swift test --filter MCPToolRouterTests
swift test --filter AuthorizationTests
```

- [ ] **Step 3: Implement schemas and tool calls**

Return MCP text plus `structuredContent`; cap representation payloads at 2 MiB; validate UUIDs, pagination and enum values before repository access; audit every call without storing full content.

- [ ] **Step 4: Verify GREEN and commit**

```bash
swift test --filter MCP
swift test --filter Authorization
git add Sources/ClipCanvasCore Tests/ClipCanvasCoreTests
git commit -m "feat: add scoped MCP tools and authorization"
```

### Task 10: Loopback MCP server, stdio bridge and settings UI

**Files:**
- Create: `Sources/ClipCanvasApp/MCP/LocalMCPServer.swift`
- Create: `Sources/ClipCanvasMCPBridge/main.swift`
- Create: `Sources/ClipCanvasApp/Views/Settings/MCPSettingsView.swift`
- Modify: `Sources/ClipCanvasApp/Views/Settings/SettingsRootView.swift`
- Modify: `scripts/build-app.sh`
- Test: `Tests/ClipCanvasAppTests/LocalMCPServerTests.swift`

**Interfaces:**
- Produces: `LocalMCPServer.start()`, `stop()`, `status`
- Produces: `clipcanvas-mcp` newline-delimited stdio executable

- [ ] **Step 1: Write failing HTTP security tests**

Test loopback bind, `POST /mcp`, invalid Origin 403, missing token 401, revoked token 401, disabled server 503, initialize round trip, and tools call.

- [ ] **Step 2: Verify RED**

```bash
swift test --filter LocalMCPServerTests
```

- [ ] **Step 3: Implement Network.framework HTTP transport**

Parse one bounded HTTP/1.1 request per connection, require `Content-Length`, cap bodies at 2 MiB, accept only `/mcp`, support POST JSON-RPC and a health-oriented GET response, and close deterministically.

- [ ] **Step 4: Implement stdio bridge**

Read one JSON-RPC message per line, forward to `http://127.0.0.1:49219/mcp` with bearer token, write exactly one JSON-RPC line to stdout, and place diagnostics only on stderr.

- [ ] **Step 5: Implement authorization UI**

Add enable toggle, server status, Add Client sheet, read/write/manage scopes, one-time token/config presentation, config copy, authorized list, revoke and recent audit list.

- [ ] **Step 6: Verify bridge round trip and commit**

```bash
./scripts/build-app.sh debug
printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"smoke","version":"1"}}}' \
  | CLIPCANVAS_TOKEN="$TEST_TOKEN" build/ClipCanvas.app/Contents/Helpers/clipcanvas-mcp
git add Sources Tests scripts
git commit -m "feat: expose authorized local MCP server"
```

### Task 11: Open-source packaging and acceptance assets

**Files:**
- Create: `README.md`
- Create: `LICENSE`
- Create: `CONTRIBUTING.md`
- Create: `SECURITY.md`
- Create: `docs/ARCHITECTURE.md`
- Create: `docs/ACCEPTANCE.md`
- Create: `.github/workflows/ci.yml`
- Create: `.gitignore`
- Create: `scripts/run-tests.sh`

**Interfaces:**
- Produces: clean clone build/test instructions
- Produces: requirement-by-requirement manual checklist

- [ ] **Step 1: Write build and privacy documentation**

README covers requirements, build, launch, Accessibility, Gatekeeper-safe options, storage path, features, MCP setup, limitations, no iCloud/subscription, and screenshots.

- [ ] **Step 2: Add deterministic CI**

```yaml
- run: ./scripts/run-tests.sh
- run: ./scripts/build-app.sh release
- run: test -x build/ClipCanvas.app/Contents/MacOS/ClipCanvas
```

- [ ] **Step 3: Add acceptance matrix**

Include all Handoff acceptance items plus text/image/URL/files, both paste modes, Pinboard CRUD, shortcuts, conservative defaults, localization, MCP scopes, revoke, disabled MCP, and clean build.

- [ ] **Step 4: Verify docs and commit**

```bash
rg -n "iCloud|Subscription|MCP|Accessibility|macOS 14" README.md docs
./scripts/run-tests.sh
./scripts/build-app.sh release
git add README.md LICENSE CONTRIBUTING.md SECURITY.md docs .github .gitignore scripts
git commit -m "docs: prepare ClipCanvas for open-source release"
```

### Task 12: Full verification and live macOS acceptance

**Files:**
- Modify: `docs/ACCEPTANCE.md`
- Modify: implementation files only for defects discovered by verification

**Interfaces:**
- Consumes: all prior tasks
- Produces: verified `.app`, verified tests, recorded manual results

- [ ] **Step 1: Run clean automated verification**

```bash
rm -rf .build build
./scripts/run-tests.sh
./scripts/build-app.sh release
```

Expected: zero test failures, exit 0, and executable app/bridge.

- [ ] **Step 2: Inspect bundle**

```bash
plutil -lint build/ClipCanvas.app/Contents/Info.plist
codesign --verify --deep --strict build/ClipCanvas.app
find build/ClipCanvas.app -maxdepth 4 -type f | sort
```

- [ ] **Step 3: Run Computer Use acceptance**

Launch the built app and verify:

1. Menu-bar item and Settings sections.
2. Bottom horizontal card panel and original styling.
3. Copy text, URL, image and file into history within one second.
4. Search, keyboard selection, Clipboard-only paste and active-app paste.
5. Useful Links and custom Pinboard CRUD.
6. Privacy defaults, ignored applications and retention controls.
7. Shortcut reset and global panel activation.
8. MCP disabled rejection, authorized read, denied write for read-only client, revoke, and full disable.

- [ ] **Step 4: Record evidence and fix failures**

Mark each `docs/ACCEPTANCE.md` row with result, macOS version, test date and evidence. For any failure, add a regression test before changing production code.

- [ ] **Step 5: Final verification and commit**

```bash
./scripts/run-tests.sh
./scripts/build-app.sh release
git status --short
git add docs/ACCEPTANCE.md Sources Tests
git commit -m "test: verify ClipCanvas end-to-end experience"
```

Expected: full test pass, release app present, acceptance checklist complete, and only intentionally ignored build output untracked.

---

## Plan Self-Review

| Check | Result |
|---|---|
| Spec coverage | Every P0 requirement maps to Tasks 1–12 |
| Placeholder scan | No implementation placeholders or deferred feature steps |
| Type consistency | Repository, model, AppModel and MCP interfaces use stable names throughout |
| Test order | Every behavior task starts with a failing test and RED verification |
| Delivery | Each task ends in independently testable output and a commit |

