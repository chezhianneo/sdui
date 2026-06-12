//
//  SDUIScreenViewModel.swift
//  sdui
//
//  A tiny async state machine for one screen: idle → loading → loaded / failed.
//  The hosting SDUIScreenView renders the matching UI for each phase.
//

import SwiftUI

@MainActor
@Observable
final class SDUIScreenViewModel {
    enum Phase {
        case idle
        case loading
        case loaded(SDUIScreen)
        case failed(String)
    }

    private(set) var phase: Phase = .idle

    @ObservationIgnored let screenId: String
    @ObservationIgnored private let loader: SDUIScreenLoader

    init(screenId: String, loader: SDUIScreenLoader) {
        self.screenId = screenId
        self.loader = loader
    }

    func load() {
        phase = .loading
        do {
            phase = .loaded(try loader.load(id: screenId))
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
