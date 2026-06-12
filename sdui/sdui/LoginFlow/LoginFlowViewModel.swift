//
//  LoginFlowViewModel.swift
//  sdui
//
//  Owns the configuration the View needs to host the SDUI flow: which screen is
//  the entry point and the loader that fetches screen definitions. It dispatches
//  intent to the Coordinator and never holds the NavigationStream.
//

import Foundation

protocol LoginFlowViewModeling {
    var entryScreenId: String { get }
    var loader: any SDUIScreenLoader { get }
    func onLoad() async
}

@Observable
final class LoginFlowViewModel: LoginFlowViewModeling {
    let entryScreenId: String

    @ObservationIgnored let loader: any SDUIScreenLoader
    @ObservationIgnored private let dispatch: ActionDispatcher<LoginFlowAction>

    init(
        actionDispatcher: ActionDispatcher<LoginFlowAction>,
        loader: any SDUIScreenLoader,
        entryScreenId: String = "login"
    ) {
        self.dispatch = actionDispatcher
        self.loader = loader
        self.entryScreenId = entryScreenId
    }

    func onLoad() async {}
}
