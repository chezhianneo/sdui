//
//  SDUIAction.swift
//  sdui
//
//  An action a component carries (e.g. a button tap). The renderer never acts on
//  these directly — it hands every fired action to SDUIRouter.handle(_:state:),
//  the only place flow logic lives. `ActionType` keeps `.unknown` last as the
//  decode fallback so a new server action never crashes an old client.
//

struct SDUIAction: Decodable {
    var type: ActionType
    var target: String?
    var validateFields: [String]?
    var params: [String: String]?
}

enum ActionType: String, Decodable {
    case navigate
    case submit
    case verifyOTP
    case appleSignIn
    case back
    case openURL
    case log
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ActionType(rawValue: raw) ?? .unknown
    }
}
