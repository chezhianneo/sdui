//
//  SDUIRouter.swift
//  sdui
//
//  The only place flow logic lives. The renderer hands every fired SDUIAction to
//  `handle(_:state:)`, which mutates `path` (the list of screen ids the
//  NavigationStack binds to) or raises `state.alert`. Components only *carry*
//  actions — they never navigate themselves.
//

import SwiftUI
import AuthenticationServices

@Observable
final class SDUIRouter {
    /// Screen ids pushed onto the NavigationStack, in order.
    var path: [String] = []

    /// Retains the in-flight Apple Sign In driver until it reports back.
    @ObservationIgnored private var appleSignIn: AppleSignInController?

    func handle(_ action: SDUIAction, state: SDUIState) {
        switch action.type {
        case .navigate:
            if let target = action.target { path.append(target) }

        case .submit:
            let missing = (action.validateFields ?? []).filter { state.value(for: $0).isEmpty }
            guard missing.isEmpty else {
                state.alert = SDUIAlert(
                    title: "Missing information",
                    message: "Please fill in all required fields before continuing."
                )
                return
            }
            if let target = action.target { path.append(target) }

        case .verifyOTP:
            let fieldId = action.params?["fieldId"] ?? "otp"
            let expected = action.params?["expected"] ?? ""
            if state.value(for: fieldId) == expected {
                if let target = action.target { path.append(target) }
            } else {
                state.alert = SDUIAlert(
                    title: "Incorrect code",
                    message: "The code you entered doesn’t match. Please try again."
                )
            }

        case .appleSignIn:
            let controller = AppleSignInController()
            appleSignIn = controller
            controller.start { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let outcome):
                    state.fields["apple_user"] = outcome.userId
                    if let name = outcome.fullName { state.fields["name"] = name }
                    if let email = outcome.email { state.fields["email"] = email }
                    if let target = action.target { self.path.append(target) }
                case .failure(let error):
                    // Ignore an explicit user cancellation; surface anything else.
                    if (error as? ASAuthorizationError)?.code != .canceled {
                        state.alert = SDUIAlert(
                            title: "Apple Sign In failed",
                            message: error.localizedDescription
                        )
                    }
                }
                self.appleSignIn = nil
            }

        case .back:
            if !path.isEmpty { path.removeLast() }

        case .openURL:
            if let target = action.target, let url = URL(string: target) {
                UIApplication.shared.open(url)
            }

        case .log:
            print("[SDUI] log \(action.target ?? "") \(action.params ?? [:])")

        case .unknown:
            break   // forward-compat: ignore actions this client doesn't understand
        }
    }
}
