import XCTest
@testable import ClipCanvasApp

@MainActor
final class LoginItemServiceTests: XCTestCase {
    func testEnabledStatusTurnsSwitchOn() {
        let controller = LoginItemControllerStub(status: .enabled)

        let service = LoginItemService(controller: controller)

        XCTAssertTrue(service.isEnabled)
        XCTAssertFalse(service.requiresApproval)
    }

    func testRequiresApprovalKeepsRequestedSwitchOn() {
        let controller = LoginItemControllerStub(status: .requiresApproval)

        let service = LoginItemService(controller: controller)

        XCTAssertTrue(service.isEnabled)
        XCTAssertTrue(service.requiresApproval)
    }

    func testEnablingRegistersAndRefreshesStatus() {
        let controller = LoginItemControllerStub(
            status: .notRegistered,
            statusAfterRegister: .enabled
        )
        let service = LoginItemService(controller: controller)

        service.setEnabled(true)

        XCTAssertEqual(controller.registerCallCount, 1)
        XCTAssertTrue(service.isEnabled)
        XCTAssertNil(service.errorMessage)
    }

    func testDisablingPendingApprovalUnregistersRequest() {
        let controller = LoginItemControllerStub(
            status: .requiresApproval,
            statusAfterUnregister: .notRegistered
        )
        let service = LoginItemService(controller: controller)

        service.setEnabled(false)

        XCTAssertEqual(controller.unregisterCallCount, 1)
        XCTAssertFalse(service.isEnabled)
        XCTAssertFalse(service.requiresApproval)
    }

    func testRegistrationFailureIsExposed() {
        let controller = LoginItemControllerStub(
            status: .notRegistered,
            registerError: LoginItemTestError.registrationFailed
        )
        let service = LoginItemService(controller: controller)

        service.setEnabled(true)

        XCTAssertEqual(
            service.errorMessage,
            LoginItemTestError.registrationFailed.localizedDescription
        )
        XCTAssertFalse(service.isEnabled)
    }

    func testOpenSystemSettingsUsesController() {
        let controller = LoginItemControllerStub(status: .requiresApproval)
        let service = LoginItemService(controller: controller)

        service.openSystemSettings()

        XCTAssertEqual(controller.openSystemSettingsCallCount, 1)
    }
}

@MainActor
private final class LoginItemControllerStub: LoginItemControlling {
    private(set) var status: LoginItemRegistrationStatus
    private let statusAfterRegister: LoginItemRegistrationStatus
    private let statusAfterUnregister: LoginItemRegistrationStatus
    private let registerError: Error?

    private(set) var registerCallCount = 0
    private(set) var unregisterCallCount = 0
    private(set) var openSystemSettingsCallCount = 0

    init(
        status: LoginItemRegistrationStatus,
        statusAfterRegister: LoginItemRegistrationStatus = .enabled,
        statusAfterUnregister: LoginItemRegistrationStatus = .notRegistered,
        registerError: Error? = nil
    ) {
        self.status = status
        self.statusAfterRegister = statusAfterRegister
        self.statusAfterUnregister = statusAfterUnregister
        self.registerError = registerError
    }

    func register() throws {
        registerCallCount += 1
        if let registerError {
            throw registerError
        }
        status = statusAfterRegister
    }

    func unregister() throws {
        unregisterCallCount += 1
        status = statusAfterUnregister
    }

    func openSystemSettings() {
        openSystemSettingsCallCount += 1
    }
}

private enum LoginItemTestError: LocalizedError {
    case registrationFailed

    var errorDescription: String? {
        "Registration failed"
    }
}
