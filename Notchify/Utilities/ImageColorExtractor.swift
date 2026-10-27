import Cocoa
import CoreImage
import SwiftUI

/// Samples an image into evenly spaced horizontal strips and returns each strip's average colour.
enum ImageColorExtractor {
    nonisolated static func gradientColors(from image: NSImage, samples: Int = 6) -> [Color] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return []
        }

        let ciImage = CIImage(cgImage: cgImage)
        let extent = ciImage.extent
        let context = CIContext()
        var colors: [Color] = []

        for i in 0..<samples {
            let stripWidth = extent.width / CGFloat(samples)
            let rect = CGRect(
                x: extent.minX + CGFloat(i) * stripWidth,
                y: extent.minY,
                width: stripWidth,
                height: extent.height
            )

            guard let filter = CIFilter(name: "CIAreaAverage") else { continue }

            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(CIVector(cgRect: rect), forKey: kCIInputExtentKey)

            guard let outputImage = filter.outputImage else { continue }

            var bitmap = [UInt8](repeating: 0, count: 4)
            context.render(
                outputImage,
                toBitmap: &bitmap,
                rowBytes: 4,
                bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                format: .RGBA8,
                colorSpace: CGColorSpaceCreateDeviceRGB()
            )

            colors.append(
                Color(
                    red: Double(bitmap[0]) / 255.0,
                    green: Double(bitmap[1]) / 255.0,
                    blue: Double(bitmap[2]) / 255.0
                )
            )
        }

        return colors
    }
}
