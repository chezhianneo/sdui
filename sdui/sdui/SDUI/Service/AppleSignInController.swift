//
//  AppleSignInController.swift
//  sdui
//
//  Drives the native Sign in with Apple flow (ASAuthorizationController) and
//  reports a simplified outcome back to SDUIRouter. Kept out of the renderer so
//  the `appleSignIn` action stays a flow concern, like every other action.
//
//  NOTE: full authorization requires the "Sign in with Apple" capability on the
//  target (Xcode ▸ Signing & Capabilities ▸ + Capability). Without it the system
//  sheet still appears but returns an error, which the router surfaces gracefully.
//

import AuthenticationServices
import UIKit

struct AppleSignInOutcome {
    let userId: String
    let fullName: String?
    let email: String?
}

@MainActor
final class AppleSignInController: NSObject {
    private var completion: ((Result<AppleSignInOutcome, Error>) -> Void)?

    func start(completion: @escaping (Result<AppleSignInOutcome, Error>) -> Void) {
        self.completion = completion
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    private func finish(_ result: Result<AppleSignInOutcome, Error>) {
        completion?(result)
        completion = nil
    }
}

extension AppleSignInController: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            finish(.failure(ASAuthorizationError(.failed)))
            return
        }
        let name = credential.fullName.flatMap { components in
            [components.givenName, components.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespaces)
        }
        finish(.success(AppleSignInOutcome(
            userId: credential.user,
            fullName: (name?.isEmpty == false) ? name : nil,
            email: credential.email
        )))
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        finish(.failure(error))
    }
}

extension AppleSignInController: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive } ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        return scene?.keyWindow ?? ASPresentationAnchor()
    }
}
