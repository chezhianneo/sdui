//
//  SDUIComponentView.swift
//  sdui
//
//  The recursive renderer. Switches over the SDUIComponent enum and recurses into
//  children. Each kind has a private @ViewBuilder builder. Shared state is read
//  from the environment (`state`, `router`); flow logic is delegated to the
//  router — components only carry actions.
//

import SwiftUI

struct SDUIComponentView: View {
    let component: SDUIComponent

    @Environment(SDUIState.self) private var state
    @Environment(SDUIRouter.self) private var router

    var body: some View {
        switch component {
        case let .vstack(props): verticalStack(props)
        case let .hstack(props): horizontalStack(props)
        case let .zstack(props): depthStack(props)
        case let .spacer(props): Spacer(minLength: props.minLength)
        case let .text(props): textView(props)
        case let .image(props): imageView(props)
        case let .logo(props): logoView(props)
        case let .textField(props): textFieldView(props)
        case let .button(props): buttonView(props)
        case let .divider(props): dividerView(props)
        case .unknown: EmptyView()
        }
    }

    // MARK: Containers

    @ViewBuilder
    private func verticalStack(_ props: ContainerProps) -> some View {
        VStack(alignment: (props.horizontalAlignment ?? .center).alignment, spacing: props.spacing) {
            childViews(props)
        }
        .modifier(ContainerStyle(props: props))
    }

    @ViewBuilder
    private func horizontalStack(_ props: ContainerProps) -> some View {
        HStack(alignment: (props.verticalAlignment ?? .center).alignment, spacing: props.spacing) {
            childViews(props)
        }
        .modifier(ContainerStyle(props: props))
    }

    @ViewBuilder
    private func depthStack(_ props: ContainerProps) -> some View {
        ZStack(alignment: (props.horizontalAlignment ?? .center).frameAlignment) {
            childViews(props)
        }
        .modifier(ContainerStyle(props: props))
    }

    @ViewBuilder
    private func childViews(_ props: ContainerProps) -> some View {
        ForEach(Array(props.children.enumerated()), id: \.offset) { _, child in
            SDUIComponentView(component: child)
        }
    }

    // MARK: Leaves

    @ViewBuilder
    private func textView(_ props: TextProps) -> some View {
        let resolved = (props.interpolatesFields ?? false) ? state.interpolate(props.text) : props.text
        Text(resolved)
            .font((props.style?.font ?? .body).weight(props.weight?.weight ?? .regular))
            .foregroundStyle((props.color ?? SDUIColor("label")).color)
            .multilineTextAlignment((props.alignment ?? .leading).textAlignment)
    }

    @ViewBuilder
    private func imageView(_ props: ImageProps) -> some View {
        let image = Image(systemName: props.systemName).font(.system(size: props.size ?? 24))
        if props.renderingMode == "multicolor" {
            image.symbolRenderingMode(.multicolor)
        } else {
            image.foregroundStyle((props.color ?? SDUIColor("label")).color)
        }
    }

    @ViewBuilder
    private func logoView(_ props: LogoProps) -> some View {
        let size = props.size ?? 64
        Text(props.text)
            .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
            .foregroundStyle((props.foreground ?? SDUIColor("white")).color)
            .frame(width: size, height: size)
            .background((props.background ?? SDUIColor("tint")).color)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
    }

    @ViewBuilder
    private func textFieldView(_ props: TextFieldProps) -> some View {
        HStack(spacing: 10) {
            if let leading = props.leading {
                SDUIComponentView(component: leading)
            }
            TextField(props.placeholder ?? "", text: state.binding(for: props.fieldId))
                .keyboardType(keyboardType(props.keyboardType))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if let icon = props.trailingIcon {
                Image(systemName: icon).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(SDUIColor("secondaryBackground").color)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func buttonView(_ props: ButtonProps) -> some View {
        Button {
            if let action = props.action { router.handle(action, state: state) }
        } label: {
            HStack(spacing: 8) {
                if let icon = props.leadingIcon {
                    if props.iconRenderingMode == "multicolor" {
                        Image(systemName: icon).symbolRenderingMode(.multicolor)
                    } else {
                        Image(systemName: icon)
                    }
                }
                Text(props.title)
            }
            .frame(maxWidth: .infinity)
        }
        .modifier(ButtonChrome(style: props.style ?? "primary"))
    }

    @ViewBuilder
    private func dividerView(_ props: DividerProps) -> some View {
        if let label = props.label {
            HStack(spacing: 12) {
                rule(props.color)
                Text(label).font(.footnote).foregroundStyle(.secondary).fixedSize()
                rule(props.color)
            }
        } else {
            rule(props.color)
        }
    }

    @ViewBuilder
    private func rule(_ color: SDUIColor?) -> some View {
        Rectangle()
            .fill((color ?? SDUIColor("secondaryLabel")).color.opacity(0.3))
            .frame(height: 1)
    }

    private func keyboardType(_ name: String?) -> UIKeyboardType {
        switch name {
        case "phonePad": .phonePad
        case "numberPad": .numberPad
        case "emailAddress": .emailAddress
        case "decimalPad": .decimalPad
        default: .default
        }
    }
}

// MARK: - Shared chrome

/// Layout chrome shared by every container: width, padding, background, corners.
private struct ContainerStyle: ViewModifier {
    let props: ContainerProps

    func body(content: Content) -> some View {
        content
            .frame(
                maxWidth: (props.fillWidth ?? false) ? .infinity : nil,
                alignment: (props.horizontalAlignment ?? .center).frameAlignment
            )
            .padding(props.padding?.edgeInsets ?? EdgeInsets())
            .background((props.background ?? SDUIColor("clear")).color)
            .clipShape(RoundedRectangle(cornerRadius: props.cornerRadius ?? 0, style: .continuous))
    }
}

/// Visual styling for the three button styles: primary, secondary, link.
private struct ButtonChrome: ViewModifier {
    let style: String

    func body(content: Content) -> some View {
        switch style {
        case "secondary":
            content
                .font(.headline)
                .padding(.vertical, 14)
                .foregroundStyle(Color.primary)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(UIColor.separator), lineWidth: 1)
                )
        case "link":
            content
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.vertical, 4)
        default:   // primary
            content
                .font(.headline)
                .padding(.vertical, 14)
                .foregroundStyle(Color.white)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}
