//
//  LoginFlowCoordinator.swift
//  sdui
//
//  Entry coordinator for the server-driven login flow. It wires the ViewModel and
//  View, injecting the SDUI screen loader as its only dependency. Screen-to-screen
//  navigation (login → otp → home) is owned by the SDUI engine's SDUIRouter inside
//  LoginFlowView, so this coordinator's NavigationStream stays idle — the SDUI tree
//  is the screen's content.
//

import SwiftUI
import Combine

enum LoginFlowAction {
    case finished
}

/// This flow navigates entirely inside the SDUI NavigationStack, so it needs no
/// native destinations — a single empty case satisfies the protocol.
enum LoginFlowDestination: NavigationDestination {
    case none

    static func == (lhs: LoginFlowDestination, rhs: LoginFlowDestination) -> Bool { true }
    func hash(into hasher: inout Hasher) {}
    var view: some View { EmptyView() }
}

protocol LoginFlowCoordinating: Coordinator {
    /// Wires the ViewModel and View together and returns the entry view for this flow.
    mutating func make() -> any View
}

struct LoginFlowCoordinator: LoginFlowCoordinating {
    typealias ActionType = LoginFlowAction

    // MARK: Dependency
    @Dependency var screenLoader: any SDUIScreenLoader

    private let navigationStream = NavigationStream<LoginFlowDestination>(nil)

    func buildDispatcher() -> ActionDispatcher<LoginFlowAction> {
        ActionDispatcher<LoginFlowAction> { action in
            switch action {
            case .finished:
                break   // flow completes inside the SDUI stack (lands on `home`)
            }
        }
    }
}

extension LoginFlowCoordinator {
    mutating func make() -> any View {
        let dispatcher = buildDispatcher()
        let viewModel = LoginFlowViewModel(
            actionDispatcher: dispatcher,
            loader: screenLoader
        )
        return LoginFlowView(viewModel: viewModel, navigationStream: navigationStream)
    }
}
