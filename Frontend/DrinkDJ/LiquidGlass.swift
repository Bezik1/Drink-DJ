import SwiftUI

extension View {
    @ViewBuilder
    func glassButtonStyle(isProminent: Bool = false) -> some View {
        if #available(iOS 26, *) {
            if isProminent {
                buttonStyle(.glassProminent)
            } else {
                buttonStyle(.glass)
            }
        } else if isProminent {
            buttonStyle(.borderedProminent)
        } else {
            buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    func minimizesTabBarOnScroll() -> some View {
        if #available(iOS 26, *) {
            tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
    }
}

struct GlassActionButton: View {
    let title: String
    var isProminent = false
    let action: () -> Void

    init(_ title: String, isProminent: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isProminent = isProminent
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .glassButtonStyle(isProminent: isProminent)
    }
}

struct FloatingGlassActions<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        Group {
            if #available(iOS 26, *) {
                GlassEffectContainer(spacing: 10) {
                    stack
                }
            } else {
                stack
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private var stack: some View {
        VStack(spacing: 10) {
            content
        }
    }
}
