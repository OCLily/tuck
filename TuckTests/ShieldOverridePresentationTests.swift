import Testing
@testable import Tuck

// Guards the read side of the App-Group handover: ShieldOverrideRequest.take() consumes the
// request, so a read at a moment where no sheet can be presented loses the user's tap for good.
struct ShieldOverridePresentationTests {
    @Test func anIdleMorningScreenAnswersTheRequest() {
        #expect(ShieldOverridePresentation.mayConsumeRequest(
            overrideFlowPresented: false,
            settingsPresented: false
        ))
    }

    @Test func anOpenOverrideSheetKeepsTheRequest() {
        #expect(!ShieldOverridePresentation.mayConsumeRequest(
            overrideFlowPresented: true,
            settingsPresented: false
        ))
    }

    // The case the guard was missing: SwiftUI presents no second sheet over the settings sheet, so
    // consuming here would delete the request and show nothing.
    @Test func anOpenSettingsSheetKeepsTheRequest() {
        #expect(!ShieldOverridePresentation.mayConsumeRequest(
            overrideFlowPresented: false,
            settingsPresented: true
        ))
    }
}
