import SwiftUI

struct Toast: Equatable {
    var title: String
    var subtitle: String
}

extension View {
    /// Top banner that auto-dismisses.
    func toast(_ toast: Binding<Toast?>) -> some View {
        overlay(alignment: .top) {
            if let t = toast.wrappedValue {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill").font(.title3).foregroundStyle(.white)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(t.title).font(.system(size: 15, weight: .semibold))
                        Text(t.subtitle).font(.system(size: 13)).opacity(0.75).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Theme.ink, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .padding(.horizontal, 16).padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: t) {
                    try? await Task.sleep(for: .seconds(2.3))
                    withAnimation { toast.wrappedValue = nil }
                }
            }
        }
        .animation(.spring(duration: 0.4), value: toast.wrappedValue)
    }
}
