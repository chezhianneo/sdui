---
name: sdui-architecture
description: >
  Architecture guide and extension recipes for the server-driven UI (SDUI) engine
  in this SwiftUI app. Use when adding or modifying an SDUI component type, adding a
  new server-driven screen (JSON), adding a new action, changing style tokens, or
  understanding how JSON screen definitions are decoded and rendered. Triggers:
  "add an SDUI component", "new SDUI screen", "render a ... from JSON", "SDUIComponent",
  "SDUIRouter", "server-driven UI", "extend the SDUI engine".
---

# SDUI Engine — Architecture & Extension Guide

A small interpreter that turns a JSON **screen definition** into native SwiftUI views
at runtime. The renderer never hardcodes screens; the server (here, bundled JSON)
decides layout, content, and actions.

## Data flow

```
<id>.json ──BundleScreenLoader──► SDUIScreen ──decode──► SDUIComponent (recursive tree)
                                                              │
                                                   SDUIComponentView (recursive switch)
                                                              │ reads / writes
                                         ┌────────────────────┴────────────────────┐
                                   SDUIState (fields, alert)        SDUIRouter (nav path + action dispatch)
```

- **Decode**: `SDUIComponent` is an `indirect enum` with a custom `init(from:)` that
  reads a `"type"` discriminator and decodes the matching props/children. Unknown
  types decode to `.unknown` and render `EmptyView()` — **forward compatibility**: a
  new server component never crashes an old client.
- **Render**: `SDUIComponentView` switches over the enum and recurses into children.
  Each component kind has a private `@ViewBuilder` builder in that file.
- **State**: `@Observable SDUIState.fields` (`[String:String]`) is shared via the
  environment, so a value typed on one screen is readable on later screens.
  `interpolate(_:)` replaces `{fieldId}` tokens in text.
- **Actions**: the renderer hands every tapped `SDUIAction` to `SDUIRouter.handle(_:state:)`,
  the *only* place flow logic lives. It mutates `path` (a `[String]` of screen ids the
  `NavigationStack` binds to) or raises `state.alert`.

## File map (all under `sdui/sdui/sdui/`)

| Path | Responsibility |
|---|---|
| `SDUI/Models/SDUIComponent.swift` | The recursive component enum + custom decoder + `.unknown` fallback |
| `SDUI/Models/SDUIProps.swift` | One `…Props` struct per component (Container, Text, Image, Logo, TextField, Button, Divider) |
| `SDUI/Models/SDUIAction.swift` | `SDUIAction` + `ActionType` discriminator |
| `SDUI/Models/SDUIStyle.swift` | Token decoding: `SDUIColor` (hex/semantic), font style/weight, alignment, padding |
| `SDUI/Models/SDUIScreen.swift` | `{ id, title?, root }` |
| `SDUI/State/SDUIState.swift` | `@Observable` field store, `binding(for:)`, `interpolate(_:)` |
| `SDUI/State/SDUIRouter.swift` | Nav path + `handle(_:state:)` action dispatch |
| `SDUI/Service/SDUIScreenLoader.swift` | `SDUIScreenLoader` protocol + `BundleScreenLoader` (swap for a remote loader) |
| `SDUI/Service/SDUIScreenViewModel.swift` | Async `idle/loading/loaded/failed` state machine |
| `SDUI/Rendering/SDUIScreenView.swift` | Hosts one screen: load + loading/error/content + alert |
| `SDUI/Rendering/SDUIComponentView.swift` | The recursive renderer + per-component builders + style modifiers |
| `Resources/*.json` | Bundled screen definitions (`get_started`, `verify`, `home`, `find_account`) |
| `ContentView.swift` / `sduiApp.swift` | `NavigationStack(path:)` wiring + environment injection |

> **Xcode 16 synchronized groups** (`objectVersion = 77`): any `.swift`/`.json` under
> `sdui/sdui/sdui/` is auto-added to the target. **Never edit `project.pbxproj`** to
> register files — just create them in the folder.

## Current component types

`vstack` · `hstack` · `zstack` (containers) · `spacer` · `text` · `image` (SF Symbol) ·
`logo` (branded mark drawn from tokens) · `textField` · `button` · `divider`.

Each container takes `children: [SDUIComponent]`. See the JSON schema section below.

---

## Recipe: add a new component type

The change touches **three files** in lockstep. Example: adding a `card` component.

1. **Props** — `SDUI/Models/SDUIProps.swift`: add a `Decodable` struct.
   ```swift
   struct CardProps: Decodable {
       var title: String
       var subtitle: String?
       var background: SDUIColor?
   }
   ```
   Reuse existing tokens (`SDUIColor`, `SDUIPadding`, `SDUIFontStyle`, …) — don't invent
   new color/size encodings.

2. **Enum case + decoder** — `SDUI/Models/SDUIComponent.swift`: add the case and a
   `switch` branch keyed on the `"type"` string. Containers decode children via
   `Self.children(c)`; leaf components decode props from `single` (the whole object).
   ```swift
   case card(CardProps)
   // …in init(from:)…
   case "card": self = .card(try CardProps(from: single))
   ```
   Do **not** add a `default` that throws — the existing `default: self = .unknown`
   must remain the catch-all.

3. **Renderer** — `SDUI/Rendering/SDUIComponentView.swift`: add a `case` to `body` and a
   private `@ViewBuilder` builder. Read shared state via the `@Environment` properties
   (`state`, `router`) already on the view; recurse with `SDUIComponentView(component:)`.
   ```swift
   case let .card(props): cardView(props)
   // …
   @ViewBuilder private func cardView(_ props: CardProps) -> some View { … }
   ```

4. **Use it** in a `Resources/*.json` screen and rebuild (see Verify).

Conventions: resolve optional tokens with sensible defaults at render time
(`(props.color ?? SDUIColor("label")).color`), apply shared chrome via the existing
`ContainerStyle` / `ButtonChrome` modifiers where it fits.

## Recipe: add a new screen

1. Create `Resources/<id>.json` with `{ "id": "<id>", "title": "...", "root": { … } }`.
2. Point an action at it: `{ "type": "navigate", "target": "<id>" }`. No Swift change —
   `ContentView`'s `.navigationDestination(for: String.self)` renders any pushed id.
3. Cross-screen data: bind inputs with `fieldId` and surface them elsewhere with
   `"interpolatesFields": true` text using `{fieldId}`.

## Recipe: add a new action type

1. `SDUI/Models/SDUIAction.swift`: add a case to `ActionType` (keep `unknown` last as the
   decode fallback).
2. `SDUI/State/SDUIRouter.swift`: add a `case` to `handle(_:state:)`. Mutate `path` to
   navigate or set `state.alert` to surface errors. Read inputs via `state.value(for:)`.

## JSON schema (quick reference)

Common: every node has `"type"`. Containers add `children`, `spacing`,
`horizontalAlignment`/`verticalAlignment` (`leading|center|trailing` / `top|center|bottom`),
`padding` (number or `{top,leading,bottom,trailing,horizontal,vertical,all}`),
`background`, `cornerRadius`, `fillWidth`.

- `text`: `text`, `style` (`largeTitle|title|title2|title3|headline|subheadline|body|callout|footnote|caption`), `weight`, `color`, `alignment`, `interpolatesFields`
- `image`: `systemName` (SF Symbol), `size`, `color`, `renderingMode` (`"multicolor"`)
- `logo`: `text`, `foreground`, `background`, `size`
- `textField`: `fieldId` (required), `placeholder`, `keyboardType` (`phonePad|numberPad|emailAddress|decimalPad|default`), `leading` (a nested component), `trailingIcon`
- `button`: `title`, `style` (`primary|secondary|link`), `leadingIcon`, `iconRenderingMode`, `action`
- `divider`: `label` (optional centered text), `color`
- `spacer`: `minLength`

**Colors** accept hex (`"#RRGGBB"`, `"#RGB"`, `"#RRGGBBAA"`) or semantic names
(`label`, `secondaryLabel`, `white`, `black`, `clear`, `background`, `secondaryBackground`,
`tint`). Unknown tokens resolve to `.clear` (never crash).

**Actions**: `{ "type": navigate|submit|verifyOTP|back|openURL|log, "target": "<screenId|url>", "validateFields": ["phone"], "params": { … } }`.
`submit` checks `validateFields` are non-empty before navigating; `verifyOTP` compares
field `params.fieldId` to `params.expected`.

## Verify changes

```bash
cd /Users/elan/Uber/sdui/sdui
xcodebuild -project sdui.xcodeproj -scheme sdui \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```
Then install/launch and screenshot to confirm rendering:
```bash
APP="$HOME/Library/Developer/Xcode/DerivedData/sdui-*/Build/Products/Debug-iphonesimulator/sdui.app"
xcrun simctl boot "iPhone 17"; open -a Simulator
xcrun simctl install "iPhone 17" $APP && xcrun simctl launch "iPhone 17" com.uber.sdui.sdui
xcrun simctl io "iPhone 17" screenshot /tmp/sdui.png
```
To prove a JSON-only change works, edit a `Resources/*.json` and relaunch — the UI must
change with **no Swift edits**.

## Gotchas

- Keep `.unknown` as the decoder/`ActionType` fallback — it's the forward-compat contract.
- The flag emoji `🇺🇸` renders as tofu in the **Simulator** (font fallback); fine on device.
- Flow logic belongs in `SDUIRouter`, not the renderer. Components only *carry* actions.
- Don't mutate `SDUIState.fields` from the renderer except through `binding(for:)`.
- New files: drop them in the folder (synchronized group). Do not touch `project.pbxproj`.
