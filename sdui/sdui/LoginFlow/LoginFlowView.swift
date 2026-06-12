//
//  LoginFlowView.swift
//  sdui
//
//  The flow's entry view. It owns the NavigationStack and the SDUI engine's shared
//  state + router, injecting them into the environment for every server-driven
//  screen. The router's `path` (screen ids) drives navigation; each pushed id is
//  rendered by another SDUIScreenView — no per-screen Swift code.
//

import SwiftUI
import Combine

@MainActor
struct LoginFlowView: View {
    @State var viewModel: LoginFlowViewModel
    let navigationStream: NavigationStream<LoginFlowDestination>

    @State private var router = SDUIRouter()
    @State private var sduiState = SDUIState()

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            SDUIScreenView(screenId: viewModel.entryScreenId, loader: viewModel.loader)
                .navigationDestination(for: String.self) { screenId in
                    SDUIScreenView(screenId: screenId, loader: viewModel.loader)
                }
        }
        .environment(sduiState)
        .environment(router)
        .task { await viewModel.onLoad() }
    }
}
