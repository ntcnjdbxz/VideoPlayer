
import WebKit

final class ContentBlocker {
    static func compile(
        completion: @escaping (WKContentRuleList?) -> Void
    ) {
        let rules = """
        [
          {
            "trigger": {
              "url-filter": ".*",
              "resource-type": ["popup"]
            },
            "action": {
              "type": "block"
            }
          }
        ]
        """

        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "StreamShelfBlocker",
            encodedContentRuleList: rules
        ) { ruleList, error in
            if let error = error {
                print("Content blocker error: \\(error)")
            }

            completion(ruleList)
        }
    }
}
