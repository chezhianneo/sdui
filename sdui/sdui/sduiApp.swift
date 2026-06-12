//
//  sduiApp.swift
//  sdui
//
//  Created by Elan Arulraj on 6/11/26.
//
//  App entry. Builds the server-driven login flow through the MVVM + Coordinator
//  pattern: a LoginFlowCoordinator is wired with its SDUI screen loader dependency,
//  then `make()` produces the root view.
//

import SwiftUI

@main
struct sduiApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

private struct RootView: View {
    @State private var content: AnyView = RootView.makeLoginFlow()

    var body: some View {
        content
    }

    /// One-shot coordinator wiring. The coordinator is a throwaway struct: inject
    /// its dependency, call `make()`, then let it go.
    private static func makeLoginFlow() -> AnyView {
        var coordinator = LoginFlowCoordinator()
        coordinator.screenLoader = BundleScreenLoader()
        return AnyView(coordinator.make())
    }
}
