import WebKit

enum ContentBlocker {
    static let json = """
    [
      {"trigger":{"url-filter":"(^|\\\\.)doubleclick\\\\.net$"},"action":{"type":"block"}},
      {"trigger":{"url-filter":"(^|\\\\.)googlesyndication\\\\.com$"},"action":{"type":"block"}},
      {"trigger":{"url-filter":"(^|\\\\.)googleadservices\\\\.com$"},"action":{"type":"block"}},
      {"trigger":{"url-filter":"(^|\\\\.)taboola\\\\.com$"},"action":{"type":"block"}},
      {"trigger":{"url-filter":"(^|\\\\.)outbrain\\\\.com$"},"action":{"type":"block"}},
      {"trigger":{"url-filter":"(^|\\\\.)popads\\\\.net$"},"action":{"type":"block"}},
      {"trigger":{"url-filter":"(^|\\\\.)propellerads\\\\.com$"},"action":{"type":"block"}},
      {"trigger":{"url-filter":"(^|\\\\.)exoclick\\\\.com$"},"action":{"type":"block"}}
    ]
    """

    static func compile(_ completion: @escaping (WKContentRuleList?) -> Void) {
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "StreamShelfAdBlock",
            encodedContentRuleList: json,
            completionHandler: completion
        )
    }
}
