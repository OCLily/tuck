import UIKit
import Testing
@testable import Tuck

// The one destination outside this app. What the two dead ends promise is the Settings app's page
// for this app — not a sub-page and not some global root — so that is what the constant has to be.
struct SystemSettingsLinkTests {
    @Test func theLinkResolvesToTheAppsOwnPageInTheSettingsApp() throws {
        let url = try #require(SystemSettingsLink.url)

        #expect(url.scheme == "app-settings")
        // The two constants beside it in the runtime are `app-settings:notifications` and
        // `app-settings:default-applications`; the bare form is the page they hang off.
        #expect(url.host == nil)
        #expect(url.path.isEmpty)
        #expect(url.absoluteString != UIApplication.openNotificationSettingsURLString)
    }

    @Test func theLinkIsApplesConstantRatherThanAHandWrittenURL() {
        #expect(SystemSettingsLink.url?.absoluteString == UIApplication.openSettingsURLString)
    }
}
