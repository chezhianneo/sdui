//
//  CoordinatorKit.swift
//  sdui
//
//  Core types for the MVVM + Coordinator architecture (see screen_architecture.md):
//  Coordinator (struct) → make() → ViewModel (class) + View (struct).
//  Dependencies flow down the coordinator tree via @Dependency; navigation flows
//  via NavigationStream. Coordinators are one-shot wiring structs.
//

import SwiftUI
import Combine

// MARK: - Navigation

/// A per-feature navigation channel. Starts `nil`; views observe it with
/// `.compactMap { $0 }` and append emitted destinations to their NavigationPath.
typealias NavigationStream<D: NavigationDestination> = CurrentValueSubject<D?, Never>

/// Each screen's destination enum conforms to this; `view` builds the pushed screen.
public protocol NavigationDestination: Hashable {
    associatedtype Content: View
    @ViewBuilder var view: Content { get }
}

// MARK: - Actions

/// Passed to a ViewModel so it can dispatch user intent back to its Coordinator,
/// which is the only type that decides navigation. `callAsFunction` sugar lets you
/// write `dispatch(.someAction)`.
public struct ActionDispatcher<Action> {
    let send: (Action) -> Void
    init(_ send: @escaping (Action) -> Void) { self.send = send }
    func callAsFunction(_ action: Action) { send(action) }
}

// MARK: - Dependency injection

/// A dependency a Coordinator requires. Set by a parent Coordinator via
/// `add(&child)` (or directly on the root) before `make()` is called. Accessing
/// it before injection traps. `nonmutating set` because `Storage` is a class, so
/// the wrapper survives being copied across struct values.
@propertyWrapper
struct Dependency<Value> {
    private let storage = Storage()

    var wrappedValue: Value {
        get {
            guard let value = storage.value else {
                fatalError("\(Value.self) was not injected before use")
            }
            return value
        }
        nonmutating set { storage.value = newValue }
    }

    final class Storage { var value: Value? }
}

/// Type-erased access to a `Dependency`'s shared `Storage`, used by `add(_:)` to
/// copy values across coordinators by reflection without knowing `Value`.
private protocol AnyDependencyBox {
    func readDependencyValue() -> Any?
    func writeDependencyValue(_ value: Any?)
}

extension Dependency: AnyDependencyBox {
    func readDependencyValue() -> Any? { storage.value }
    func writeDependencyValue(_ value: Any?) { storage.value = value as? Value }
}

// MARK: - Coordinator

public protocol Coordinator {
    associatedtype ActionType
    func buildDispatcher() -> ActionDispatcher<ActionType>
}

extension Coordinator {
    /// Propagates this coordinator's `@Dependency` values into a child coordinator
    /// by matching the wrapper's stored-property label. Both wrappers share a class
    /// `Storage`, so writing through the child's box persists on the real child.
    func add(_ child: inout some Coordinator) {
        var parentBoxes: [String: AnyDependencyBox] = [:]
        for member in Mirror(reflecting: self).children {
            if let label = member.label, let box = member.value as? AnyDependencyBox {
                parentBoxes[label] = box
            }
        }
        for member in Mirror(reflecting: child).children {
            guard let label = member.label,
                  let childBox = member.value as? AnyDependencyBox,
                  let parentBox = parentBoxes[label],
                  let value = parentBox.readDependencyValue() else { continue }
            childBox.writeDependencyValue(value)
        }
    }
}
