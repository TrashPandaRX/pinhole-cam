import CoreGraphics
import CoreVideo
import Foundation

struct FrameAnalyzer {
    func analyze(pixelBuffer: CVPixelBuffer, target: ColorTarget) -> [DetectedRegion] {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return []
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let step = max(target.samplingStride, 2)
        let gridWidth = max(width / step, 1)
        let gridHeight = max(height / step, 1)

        let bytes = baseAddress.assumingMemoryBound(to: UInt8.self)
        var mask = Array(repeating: false, count: gridWidth * gridHeight)
        var scores = Array(repeating: CGFloat.zero, count: gridWidth * gridHeight)

        for gridY in 0..<gridHeight {
            let pixelY = min((gridY * step) + (step / 2), height - 1)

            for gridX in 0..<gridWidth {
                let pixelX = min((gridX * step) + (step / 2), width - 1)
                let offset = (pixelY * bytesPerRow) + (pixelX * 4)

                let blue = CGFloat(bytes[offset]) / 255
                let green = CGFloat(bytes[offset + 1]) / 255
                let red = CGFloat(bytes[offset + 2]) / 255

                let hsv = Self.rgbToHSV(red: red, green: green, blue: blue)
                let index = (gridY * gridWidth) + gridX

                if target.matches(hsv) {
                    mask[index] = true
                    scores[index] = target.confidence(for: hsv)
                }
            }
        }

        return connectedRegions(
            mask: mask,
            scores: scores,
            gridWidth: gridWidth,
            gridHeight: gridHeight,
            step: step,
            imageWidth: width,
            imageHeight: height,
            target: target
        )
    }

    private func connectedRegions(
        mask: [Bool],
        scores: [CGFloat],
        gridWidth: Int,
        gridHeight: Int,
        step: Int,
        imageWidth: Int,
        imageHeight: Int,
        target: ColorTarget
    ) -> [DetectedRegion] {
        var visited = Array(repeating: false, count: mask.count)
        var regions: [DetectedRegion] = []
        let neighbors = [
            (-1, -1), (0, -1), (1, -1),
            (-1, 0),           (1, 0),
            (-1, 1),  (0, 1),  (1, 1)
        ]

        for startY in 0..<gridHeight {
            for startX in 0..<gridWidth {
                let startIndex = (startY * gridWidth) + startX
                guard mask[startIndex], !visited[startIndex] else {
                    continue
                }

                var queue = [(startX, startY)]
                var queueIndex = 0
                visited[startIndex] = true

                var minX = startX
                var maxX = startX
                var minY = startY
                var maxY = startY
                var cellCount = 0
                var confidenceSum: CGFloat = 0

                while queueIndex < queue.count {
                    let (currentX, currentY) = queue[queueIndex]
                    queueIndex += 1

                    let currentIndex = (currentY * gridWidth) + currentX
                    cellCount += 1
                    confidenceSum += scores[currentIndex]
                    minX = min(minX, currentX)
                    maxX = max(maxX, currentX)
                    minY = min(minY, currentY)
                    maxY = max(maxY, currentY)

                    for (offsetX, offsetY) in neighbors {
                        let nextX = currentX + offsetX
                        let nextY = currentY + offsetY

                        guard nextX >= 0, nextX < gridWidth, nextY >= 0, nextY < gridHeight else {
                            continue
                        }

                        let nextIndex = (nextY * gridWidth) + nextX
                        guard mask[nextIndex], !visited[nextIndex] else {
                            continue
                        }

                        visited[nextIndex] = true
                        queue.append((nextX, nextY))
                    }
                }

                guard cellCount >= target.minimumClusterCells else {
                    continue
                }

                let x = CGFloat(minX * step) / CGFloat(imageWidth)
                let y = CGFloat(minY * step) / CGFloat(imageHeight)
                let width = CGFloat(((maxX - minX) + 1) * step) / CGFloat(imageWidth)
                let height = CGFloat(((maxY - minY) + 1) * step) / CGFloat(imageHeight)
                let normalizedRect = CGRect(x: x, y: y, width: width, height: height)
                let center = CGPoint(x: normalizedRect.midX, y: normalizedRect.midY)

                regions.append(
                    DetectedRegion(
                        normalizedRect: normalizedRect,
                        center: center,
                        confidence: confidenceSum / CGFloat(cellCount),
                        label: target.hex,
                        displayColor: target.swiftUIColor
                    )
                )
            }
        }

        return regions.sorted {
            ($0.normalizedRect.width * $0.normalizedRect.height) > ($1.normalizedRect.width * $1.normalizedRect.height)
        }
    }

    private static func rgbToHSV(red: CGFloat, green: CGFloat, blue: CGFloat) -> HSVColor {
        let maximum = max(red, green, blue)
        let minimum = min(red, green, blue)
        let delta = maximum - minimum

        let hue: CGFloat
        if delta == 0 {
            hue = 0
        } else if maximum == red {
            hue = ((green - blue) / delta).truncatingRemainder(dividingBy: 6) / 6
        } else if maximum == green {
            hue = (((blue - red) / delta) + 2) / 6
        } else {
            hue = (((red - green) / delta) + 4) / 6
        }

        let normalizedHue = hue < 0 ? hue + 1 : hue
        let saturation = maximum == 0 ? 0 : delta / maximum

        return HSVColor(hue: normalizedHue, saturation: saturation, brightness: maximum)
    }
}
