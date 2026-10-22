import ManagedSettings

class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(Self.respond(to: action))
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(Self.respond(to: action))
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(Self.respond(to: action))
    }

    // FamilyActivityPicker lets the user block whole categories or web domains, not just
    // individual apps - all three token types must react to the override
    // mechanic the same way, not just applications.
    //
    // The write happens before the response is handed back: iOS opens the app off the return value,
    // and the app reads the request during its own launch.
    private static func respond(to action: ShieldAction) -> ShieldActionResponse {
        if ShieldActionRouting.routesToApp(action) {
            ShieldOverrideRequest.record(reason: ShieldActionRouting.reason(for: action))
        }
        return ShieldActionRouting.response(for: action)
    }
}
