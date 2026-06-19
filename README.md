# sdui

A **server-driven UI (SDUI)** login flow for iOS. Screens are described as JSON and
rendered into native SwiftUI at runtime — the client never hardcodes a screen's
layout, content, or actions. The engine is hosted through an **MVVM + Coordinator**
architecture.

> Built from two project skills: `skill_architecture.md` (the SDUI engine) and
> `screen_architecture.md` (the MVVM + Coordinator pattern).

| Login (`login.json`) | Verify (`otp.json`) |
|---|---|
| Logo, phone field, **Continue**, Google / Facebook social login | Code field, **Verify**, Resend, native **Sign in with Apple** |

## How it works

A JSON **screen definition** is loaded, decoded into a recursive component tree, and
rendered. The server (here, bundled JSON) decides everything.

```
<id>.json ──BundleScreenLoader──► SDUIScreen ──decode──► SDUIComponent (recursive tree)
                                                              │
                                                   SDUIComponentView (recursive switch)
                                                              │ reads / writes
                                         ┌────────────────────┴────────────────────┐
                                   SDUIState (fields, alert)        SDUIRouter (nav path + actions)
```

- **Decode** — `SDUIComponent` is an `indirect enum` with a custom decoder keyed on a
  `"type"` discriminator. Unknown types decode to `.unknown` and render `EmptyView()`,
  so a new server component never crashes an old client (forward compatibility).
- **Render** — `SDUIComponentView` switches over the enum and recurses into children.
- **State** — `SDUIState.fields` (`[String:String]`) is shared via the environment, so a
  value typed on one screen is readable on later screens. `interpolate(_:)` replaces
  `{fieldId}` tokens in text (e.g. `"code sent to {phone}"`).
- **Actions** — every fired `SDUIAction` is handed to `SDUIRouter.handle(_:state:)`, the
  only place flow logic lives. It mutates `path` (the screen ids the `NavigationStack`
  binds to) or raises `state.alert`.

Navigation between screens is data: `login` → `otp` → `home` is driven entirely by JSON
actions, with **no per-screen Swift code**.

## Architecture

The SDUI engine is hosted inside the MVVM + Coordinator pattern:

```
sduiApp → LoginFlowCoordinator.make() → LoginFlowViewModel + LoginFlowView
                                                                  │ owns NavigationStack(path:)
                                                                  └─ SDUIScreenView(screenId:) ── renders JSON
```

- **Coordinator** — a one-shot wiring `struct`. Injected with its `@Dependency` screen
  loader, it builds the ViewModel + View and is then released.
- **ViewModel** — `@Observable class` holding the entry screen id and loader.
- **View** — owns the `NavigationStack` and injects the shared `SDUIState` / `SDUIRouter`
  into the environment for the whole flow.

## Project layout

```
sdui/sdui/sdui/
├─ Core/CoordinatorKit.swift          # NavigationStream, ActionDispatcher, @Dependency, Coordinator
├─ LoginFlow/                         # Coordinator + ViewModel + View hosting the SDUI flow
├─ SDUI/
│  ├─ Models/                         # SDUIComponent, SDUIProps, SDUIAction, SDUIStyle, SDUIScreen
│  ├─ State/                          # SDUIState (fields) + SDUIRouter (actions/nav)
│  ├─ Service/                        # screen loader, screen view model, AppleSignInController
│  └─ Rendering/                      # SDUIScreenView (host) + SDUIComponentView (renderer)
└─ Resources/                         # login.json, otp.json, home.json
```

> The Xcode project uses **synchronized groups** (`objectVersion = 77`): any `.swift` or
> `.json` added under `sdui/sdui/sdui/` is auto-included in the target — no need to edit
> `project.pbxproj`.

## Build & run

```bash
cd sdui
xcodebuild -project sdui.xcodeproj -scheme sdui \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Or just open `sdui/sdui.xcodeproj` in Xcode and run (⌘R). Requires Xcode 26 / iOS 26.4.

## JSON component reference

Containers: `vstack` · `hstack` · `zstack` (take `children`, `spacing`, alignment,
`padding`, `background`, `cornerRadius`, `fillWidth`). Leaves: `text` · `image` (SF
Symbol) · `logo` · `textField` · `button` · `divider` · `spacer`.

**Actions** — `{ "type": ..., "target": "<screenId>", ... }`:

| type | behaviour |
|---|---|
| `navigate` | push `target` |
| `submit` | push `target` after `validateFields` are non-empty |
| `verifyOTP` | push `target` if field `params.fieldId` equals `params.expected` |
| `appleSignIn` | run native Sign in with Apple, store credentials, push `target` on success |
| `back` | pop |
| `openURL` / `log` | open a URL / debug log |

**Colors** accept hex (`#RRGGBB`, `#RGB`, `#RRGGBBAA`) or semantic names (`label`,
`secondaryLabel`, `tint`, `background`, `secondaryBackground`, `white`, `black`, `clear`).
Unknown tokens resolve to `.clear` — they never crash.

## Extending

- **New screen** — add `Resources/<id>.json` and point an action at `"target": "<id>"`.
  No Swift changes.
- **New component** — add a `…Props` struct, an enum case + decoder branch in
  `SDUIComponent`, and a `@ViewBuilder` in `SDUIComponentView` (keep `.unknown` last).
- **New action** — add a case to `ActionType` (keep `.unknown` last) and a branch in
  `SDUIRouter.handle(_:state:)`.

## Notes

- **Sign in with Apple** is wired via `ASAuthorizationController`, but full authorization
  needs the *Sign in with Apple* capability on the target (Xcode ▸ Signing &
  Capabilities ▸ **+ Capability**). Without it the system sheet still appears and the
  router surfaces the error gracefully.
- The OTP `expected` code is currently hardcoded (`123456`) in `otp.json`; real
  verification would call a backend.
- Social login buttons (Google / Facebook) currently fire `log` actions — they render
  and are tappable but aren't yet wired to provider SDKs.

## License

[MIT](LICENSE) © 2026 Elan
