//
//  SDUIState.swift
//  sdui
//
//  Shared, observable field store for a server-driven flow. A value typed on one
//  screen is readable on later screens because the same instance is injected into
//  the environment for the whole NavigationStack. `interpolate(_:)` replaces
//  `{fieldId}` tokens in text.
//

import SwiftUI

@Observable
final class SDUIState {
    /// Backing store for every `textField` keyed by its `fieldId`.
    var fields: [String: String] = [:]

    /// Raised by the router; surfaced as an alert by the hosting screen.
    var alert: SDUIAlert?

    func value(for id: String) -> String { fields[id] ?? "" }

    /// Two-way binding used by `textField`. The renderer must only mutate
    /// `fields` through this binding.
    func binding(for id: String) -> Binding<String> {
        Binding(
            get: { [weak self] in self?.fields[id] ?? "" },
            set: { [weak self] newValue in self?.fields[id] = newValue }
        )
    }

    /// Replaces `{fieldId}` tokens with their current values.
    func interpolate(_ text: String) -> String {
        var result = text
        for (key, value) in fields {
            result = result.replacingOccurrences(of: "{\(key)}", with: value)
        }
        return result
    }
}

struct SDUIAlert: Identifiable {
    let id = UUID()
    var title: String
    var message: String?
}
