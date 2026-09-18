import AppKit

struct ImageLoader {
    static func image(named name: String, size: NSSize) -> NSImage? {
        guard let path = Bundle.main.path(forResource: name, ofType: "png"),
              let source = NSImage(contentsOfFile: path),
              let cgImage = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let croppedImage = cropTransparentPixels(from: cgImage)
        let widthScale = size.width / CGFloat(croppedImage.width)
        let heightScale = size.height / CGFloat(croppedImage.height)
        let scale = min(widthScale, heightScale)
        let fittedSize = NSSize(
            width: CGFloat(croppedImage.width) * scale,
            height: CGFloat(croppedImage.height) * scale
        )
        let image = NSImage(cgImage: croppedImage, size: fittedSize)
        image.isTemplate = false
        return image
    }

    private static func cropTransparentPixels(from image: CGImage) -> CGImage {
        guard let provider = image.dataProvider,
              let data = provider.data,
              image.bitsPerPixel == 32,
              image.bitsPerComponent == 8 else {
            return image
        }

        let bytes = CFDataGetBytePtr(data)
        let bytesPerPixel = 4
        let alphaOffset: Int
        switch image.alphaInfo {
        case .first, .premultipliedFirst, .noneSkipFirst:
            alphaOffset = 0
        default:
            alphaOffset = 3
        }

        var minX = image.width
        var minY = image.height
        var maxX = 0
        var maxY = 0

        for y in 0..<image.height {
            for x in 0..<image.width {
                let offset = y * image.bytesPerRow + x * bytesPerPixel + alphaOffset
                if bytes?[offset] ?? 0 > 8 {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }

        guard minX <= maxX, minY <= maxY else { return image }
        let rect = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        return image.cropping(to: rect) ?? image
    }
}
