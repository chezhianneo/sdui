//
//  SDUIScreenView.swift
//  sdui
//
//  Hosts one server-driven screen: drives the load state machine, shows
//  loading / error / content, and surfaces router-raised alerts. The shared
//  SDUIState and SDUIRouter come from the environment (injected once by the
//  hosting NavigationStack in LoginFlowView).
//

import SwiftUI

struct SDUIScreenView: View {
    let screenId: String

    @State private var viewModel: SDUIScreenViewModel
    @Environment(SDUIState.self) private var state

    init(screenId: String, loader: SDUIScreenLoader = BundleScreenLoader()) {
        self.screenId = screenId
        _viewModel = State(initialValue: SDUIScreenViewModel(screenId: screenId, loader: loader))
    }

    var body: some View {
        content
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if case .idle = viewModel.phase { viewModel.load() }
            }
            .alert(
                state.alert?.title ?? "",
                isPresented: alertBinding,
                presenting: state.alert
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { alert in
                if let message = alert.message { Text(message) }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded(let screen):
            ScrollView {
                SDUIComponentView(component: screen.root)
            }
            .scrollDismissesKeyboard(.interactively)

        case .failed(let message):
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Couldn’t load this screen").font(.headline)
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var navigationTitle: String {
        if case .loaded(let screen) = viewModel.phase { return screen.title ?? "" }
        return ""
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { state.alert != nil },
            set: { presented in if !presented { state.alert = nil } }
        )
    }
}
