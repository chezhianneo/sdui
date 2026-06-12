# CLAUDE.md — Movie Project

This file describes the architecture and coding patterns used in this project. Follow these rules when adding, modifying, or reviewing any feature screen.

---

## Screen Architecture

Every screen is composed of:
```
Coordinator (struct) → make() → ViewModel (class) + View (struct)
```

Dependencies flow **down** the Coordinator tree via `@Dependency` — never back up, never sideways.  
Navigation flows via `NavigationStream` — never via `@State` booleans or direct coordinator references.  
Coordinators are **one-shot wiring structs** — they live only long enough to call `make()`, then are released.

---

## Core Types (already exist — do not recreate)

```swift
// NavigationStream — CurrentValueSubject, starts nil
typealias NavigationStream<D: NavigationDestination> = CurrentValueSubject<D?, Never>

// NavigationDestination — each screen's destination enum conforms to this
public protocol NavigationDestination: Hashable {
    associatedtype Content: View
    @ViewBuilder var view: Content { get }
}

// ActionDispatcher — passed to ViewModel, callAsFunction sugar
public struct ActionDispatcher<Action> {
    let send: (Action) -> Void
    init(_ send: @escaping (Action) -> Void) { self.send = send }
    func callAsFunction(_ action: Action) { send(action) }
}

// @Dependency — non-mutating because Storage is a class
@propertyWrapper
struct Dependency<Value> {
    private let storage = Storage()
    var wrappedValue: Value {
        get { guard let v = storage.value else { fatalError("\(Value.self) not injected") }; return v }
        nonmutating set { storage.value = newValue }
    }
    final class Storage { var value: Value? }
}

// Coordinator protocol
public protocol Coordinator {
    associatedtype ActionType
    func buildDispatcher() -> ActionDispatcher<ActionType>
}

// add(_:) — propagates @Dependency values from parent to child by name matching
extension Coordinator {
    func add(_ child: inout some Coordinator) { /* Mirror-based name-matched propagation */ }
}
```

---

## Protocols

Every feature defines protocols for its Coordinator and ViewModel. These enable mock substitution in tests.

### Coordinator protocol

```swift
protocol {Feature}Coordinating: Coordinator {
    /// Wires the ViewModel and View together and returns the entry view for this screen.
    mutating func make() -> any View
}
```

### ViewModel protocol

```swift
protocol {Feature}ViewModeling {
    /// Observable state properties the View binds to.
    var items: [Item] { get set }
    var isLoading: Bool { get set }
    var error: Error? { get set }

    /// Called when the view appears; triggers data loading.
    func onLoad() async

    /// Called on user interaction; dispatches action to the coordinator.
    func onItemTapped(_ item: Item)
}
```

---

## Adding a New Feature Screen

For a feature named **{Feature}**, create these files:

### 1. `{Feature}/{Feature}Coordinator.swift`

```swift
import Foundation
import SwiftUI
import Combine

enum {Feature}Action {
    // TODO: add cases e.g. case showDetail(Item)
}

enum {Feature}Destination: NavigationDestination {
    // TODO: add cases e.g. case detail(any View)
    static func == (lhs: {Feature}Destination, rhs: {Feature}Destination) -> Bool { ... }
    func hash(into hasher: inout Hasher) { ... }
    var view: some View { ... }
}

protocol {Feature}Coordinating: Coordinator {
    /// Wires the ViewModel and View together and returns the entry view for this screen.
    mutating func make() -> any View
}

struct {Feature}Coordinator: {Feature}Coordinating {
    typealias ActionType = {Feature}Action

    // MARK: Dependency
    @Dependency var networkClient: NetworkingClient
    // MARK: Dependency tunneling (declare but don't use — forwarded to children)
    // @Dependency var someOtherDep: SomeType

    private let navigationStream = NavigationStream<{Feature}Destination>(nil)

    func buildDispatcher() -> ActionDispatcher<{Feature}Action> {
        let stream = navigationStream           // capture stream, not self
        return ActionDispatcher<{Feature}Action> { action in
            switch action {
            // case .showDetail(let item):
            //     var child = ChildCoordinator()
            //     self.add(&child)
            //     stream.send(.detail(AnyView(child.make(item: item))))
            }
        }
    }
}

extension {Feature}Coordinator {
    mutating func make() -> any View {
        let dispatcher = buildDispatcher()
        let viewModel = {Feature}ViewModel(
            actionDispatcher: dispatcher,
            service: {Feature}Service(client: networkClient)
        )
        return {Feature}View(viewModel: viewModel, navigationStream: navigationStream)
    }
}
```

### 2. `{Feature}/{Feature}ViewModel.swift`

```swift
import Foundation

protocol {Feature}ViewModeling {
    var items: [Item] { get set }
    var isLoading: Bool { get set }
    var error: Error? { get set }
    func onLoad() async
    func onItemTapped(_ item: Item)
}

@Observable
final class {Feature}ViewModel: {Feature}ViewModeling {
    var items: [Item] = []
    var isLoading = false
    var error: Error?

    let dispatch: ActionDispatcher<{Feature}Action>

    @ObservationIgnored private let service: {Feature}Servicing
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    private var hasLoaded = false

    init(actionDispatcher: ActionDispatcher<{Feature}Action>, service: {Feature}Servicing) {
        self.dispatch = actionDispatcher
        self.service = service
    }

    func onLoad() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        isLoading = true
        defer { isLoading = false }
        do { items = try await service.fetch() }
        catch { self.error = error }
    }

    func onItemTapped(_ item: Item) {
        dispatch(.showDetail(item))
    }
}
```

### 3. `{Feature}/{Feature}View.swift`

```swift
import SwiftUI
import Combine

@MainActor
struct {Feature}View: View {
    @State var viewModel: {Feature}ViewModel
    @State private var path = NavigationPath()
    let navigationStream: NavigationStream<{Feature}Destination>

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationDestination(for: {Feature}Destination.self) { $0.view }
                .navigationTitle("{Feature}")
        }
        .onReceive(navigationStream.compactMap { $0 }) { path.append($0) }
        .task { await viewModel.onLoad() }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading { ProgressView() }
        else { List(viewModel.items) { item in /* render row */ } }
    }
}
```

### 4. Mocks (test target only)

```swift
// Mock ViewModel — conforms to protocol, tracks calls for assertions
@MainActor
final class Mock{Feature}ViewModel: {Feature}ViewModeling {
    var items: [Item] = []
    var isLoading = false
    var error: Error?
    var onLoadCalled = false
    var lastTappedItem: Item?

    func onLoad() async { onLoadCalled = true }
    func onItemTapped(_ item: Item) { lastTappedItem = item }
}

// Mock Coordinator — conforms to protocol, tracks make() calls
struct Mock{Feature}Coordinator: {Feature}Coordinating {
    typealias ActionType = {Feature}Action
    var makeCalled = false

    func buildDispatcher() -> ActionDispatcher<{Feature}Action> { ActionDispatcher { _ in } }
    mutating func make() -> any View { makeCalled = true; return EmptyView() }
}
```

---

## Rules

**Coordinator**
- Always a `struct`, never a `class`
- Declare all external dependencies with `@Dependency`
- Dependencies used only for tunneling to children — mark with `// MARK: Dependency tunneling`
- `buildDispatcher()` closure must capture `let stream = navigationStream` — never `self`
- `make()` is a `mutating` func in an extension, not part of the struct body
- No generic type parameters that shadow the `ActionType` enum
- No stored `AnyCancellable` or mutable state
- Released immediately after `make()` — do not store or pass around coordinators
- Conforms to a feature-specific `{Feature}Coordinating` protocol

**ViewModel**
- Always `class` with `@Observable`
- Conforms to a feature-specific `{Feature}ViewModeling` protocol
- Receives `ActionDispatcher` and services via `init` — never `@Dependency` directly
- All observable state is value types
- Mark services and tasks `@ObservationIgnored`
- Use `hasLoaded` guard in `onLoad()` — call via `.task`, not `.onAppear`
- Dispatches actions → Coordinator decides navigation; ViewModel never holds `NavigationStream`
- `[weak self]` only inside `Task` closures — never on struct captures

**View**
- Always `struct` with `@MainActor`
- Owns `NavigationPath` — ViewModel does not
- Observes stream via `.onReceive(navigationStream.compactMap { $0 })`
- Use `.task` for data loading, never `.onAppear`
- No business logic, no service calls

**NavigationStream**
- Created by the Coordinator, passed to both ViewModel and View
- Views use `.compactMap { $0 }` because stream starts as `nil`

**@Dependency**
- Set by parent Coordinator via `add(&child)` before `make()` is called
- `nonmutating set` because `Storage` is a class — safe to copy the struct
- Accessing before injection triggers `fatalError`
- Intermediate coordinators that tunnel a dependency must still declare it with `@Dependency`

---

## Common Mistakes to Avoid

- Coordinator is a `class` → must be `struct`
- Generic type parameter on Coordinator shadows Action enum → remove generic
- `buildDispatcher` captures `self` instead of stream → fix capture
- ViewModel holds `NavigationStream` directly → replace with `ActionDispatcher`
- View calls services directly → move to ViewModel
- `.onAppear` for data loading → replace with `.task` + `hasLoaded`
- Navigation via `@State` booleans → replace with `NavigationStream` destinations
- `AnyView` stored in destination enum → prefer `any View`; use `AnyView` only at call site
- Missing feature protocol → every Coordinator and ViewModel must conform to its protocol
- Mock missing from test target → add `Mock{Feature}ViewModel` and `Mock{Feature}Coordinator`
