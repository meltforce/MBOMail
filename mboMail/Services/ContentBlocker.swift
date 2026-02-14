import WebKit

@MainActor
final class ContentBlocker {

    static let shared = ContentBlocker()

    private var compiledRuleList: WKContentRuleList?

    func compile() async {
        guard let url = Bundle.main.url(forResource: "tracker-blocklist", withExtension: "json"),
              let jsonString = try? String(contentsOf: url, encoding: .utf8) else {
            print("[ContentBlocker] Failed to load tracker-blocklist.json")
            return
        }

        do {
            let ruleList = try await WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: "mbomail-tracker-blocklist",
                encodedContentRuleList: jsonString
            )
            compiledRuleList = ruleList
        } catch {
            print("[ContentBlocker] Compilation error: \(error)")
        }
    }

    func apply(to controller: WKUserContentController) {
        guard let ruleList = compiledRuleList else { return }
        controller.add(ruleList)
    }

    func remove(from controller: WKUserContentController) {
        guard let ruleList = compiledRuleList else { return }
        controller.remove(ruleList)
    }
}
