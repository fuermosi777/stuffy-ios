import SwiftUI
import PhotosUI

private let edgeColorCache = NSCache<NSNumber, UIColor>()

/// Average colour of the image's outer pixel ring, so letterboxing blends with the photo's own backdrop.
func edgeColor(of data: Data?) -> Color {
    guard let data else { return Theme.chip }
    let key = NSNumber(value: data.hashValue)
    if let hit = edgeColorCache.object(forKey: key) { return Color(hit) }
    guard let cg = UIImage(data: data)?.cgImage else { return Theme.chip }
    let n = 16
    var px = [UInt8](repeating: 0, count: n * n * 4)
    let ok = px.withUnsafeMutableBytes { buf -> Bool in
        guard let ctx = CGContext(data: buf.baseAddress, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: n, height: n))
        return true
    }
    guard ok else { return Theme.chip }
    var sum = [Int](repeating: 0, count: 3), count = 0
    for y in 0..<n { for x in 0..<n where x == 0 || y == 0 || x == n - 1 || y == n - 1 {
        let i = (y * n + x) * 4
        for c in 0..<3 { sum[c] += Int(px[i + c]) }
        count += 1
    } }
    let ui = UIColor(red: CGFloat(sum[0]) / CGFloat(count * 255), green: CGFloat(sum[1]) / CGFloat(count * 255),
                     blue: CGFloat(sum[2]) / CGFloat(count * 255), alpha: 1)
    edgeColorCache.setObject(ui, forKey: key)
    return Color(ui)
}

/// Square thumbnail; falls back to the category symbol.
struct PhotoThumb: View {
    var data: Data?
    var symbol: String = "photo"
    var size: CGFloat = 64
    var radius: CGFloat = 14

    var body: some View {
        edgeColor(of: data)
            .frame(width: size, height: size)
            .overlay {
                if let data, let img = UIImage(data: data) {
                    Image(uiImage: img).resizable().scaledToFit()
                } else {
                    Image(systemName: symbol).font(.system(size: size * 0.34)).foregroundStyle(Theme.secondary)
                }
            }
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
            edgeColor(of: data)
                .frame(height: 190)
                .frame(maxWidth: .infinity)
                .overlay {
                    if let data, let img = UIImage(data: data) {
                        Image(uiImage: img).resizable().scaledToFit()
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "camera").font(.system(size: 20))
                                .frame(width: 48, height: 48).background(.white, in: Circle())
                            Text("Add photo").font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(Color(hex: 0x55524C))
                    }
                }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .onChange(of: pick) { _, new in
            Task { if let d = await loadPhoto(new) { data = d } }
        }
    }
}
