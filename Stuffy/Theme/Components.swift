import SwiftUI
import PhotosUI

/// Square thumbnail; falls back to the category symbol.
struct PhotoThumb: View {
    var data: Data?
    var symbol: String = "photo"
    var size: CGFloat = 64
    var radius: CGFloat = 14

    var body: some View {
        ZStack {
            Theme.chip
            if let data, let img = UIImage(data: data) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Image(systemName: symbol).font(.system(size: size * 0.34)).foregroundStyle(Theme.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

struct Pill: View {
    var text: String
    var background: Color
    var foreground: Color

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(foreground)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(background, in: Capsule())
            .fixedSize()
    }
}

struct CategoryChip: View {
    var label: String
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 15)
                .frame(height: 34)
                .foregroundStyle(selected ? Theme.background : Color(hex: 0x3A3935))
                .background(selected ? Theme.ink : Theme.chip, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color(hex: 0x3C3223).opacity(0.06), radius: 10, y: 4)
    }
}

/// Downsizes picked photos so they sync cheaply.
func loadPhoto(_ pick: PhotosPickerItem?) async -> Data? {
    guard let raw = try? await pick?.loadTransferable(type: Data.self), let img = UIImage(data: raw) else { return nil }
    let maxSide: CGFloat = 1200
    let scale = min(1, maxSide / max(img.size.width, img.size.height))
    let size = CGSize(width: img.size.width * scale, height: img.size.height * scale)
    let resized = UIGraphicsImageRenderer(size: size).image { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
    return resized.jpegData(compressionQuality: 0.8)
}

struct PhotoPickerField: View {
    @Binding var data: Data?
    @State private var pick: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $pick, matching: .images) {
            ZStack {
                Theme.chip
                if let data, let img = UIImage(data: data) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "camera").font(.system(size: 20))
                            .frame(width: 48, height: 48).background(.white, in: Circle())
                        Text("Add photo").font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(Color(hex: 0x55524C))
                }
            }
            .frame(height: 190)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .onChange(of: pick) { _, new in
            Task { if let d = await loadPhoto(new) { data = d } }
        }
    }
}
