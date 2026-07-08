import CoreGraphics
import SwiftUI
import UIKit

struct HSVColor: Equatable {
    let hue: CGFloat
    let saturation: CGFloat
    let brightness: CGFloat
}

struct ColorTarget: Equatable {
    var hex: String = "#FF3B30"
    var hueTolerance: CGFloat = 0.035
    var saturationTolerance: CGFloat = 0.28
    var brightnessTolerance: CGFloat = 0.28
    var minimumClusterCells: Int = 20
    var samplingStride: Int = 6

    var uiColor: UIColor {
        UIColor(hex: hex) ?? .systemRed
    }

    var swiftUIColor: Color {
        Color(uiColor: uiColor)
    }

    var referenceHSV: HSVColor {
        uiColor.hsv ?? HSVColor(hue: 0, saturation: 1, brightness: 1)
    }

    func matches(_ sample: HSVColor) -> Bool {
        let reference = referenceHSV
        let hueDelta = abs(sample.hue - reference.hue)
        let wrappedHueDelta = min(hueDelta, 1 - hueDelta)

        guard sample.saturation > 0.05, sample.brightness > 0.05 else {
            return false
        }

        return wrappedHueDelta <= hueTolerance
            && abs(sample.saturation - reference.saturation) <= saturationTolerance
            && abs(sample.brightness - reference.brightness) <= brightnessTolerance
    }

    func confidence(for sample: HSVColor) -> CGFloat {
        let reference = referenceHSV
        let hueDelta = abs(sample.hue - reference.hue)
        let wrappedHueDelta = min(hueDelta, 1 - hueDelta)

        let hueScore = max(0, 1 - (wrappedHueDelta / max(hueTolerance, 0.001)))
        let saturationScore = max(0, 1 - (abs(sample.saturation - reference.saturation) / max(saturationTolerance, 0.001)))
        let brightnessScore = max(0, 1 - (abs(sample.brightness - reference.brightness) / max(brightnessTolerance, 0.001)))

        return (hueScore + saturationScore + brightnessScore) / 3
    }
}

struct DetectedRegion: Identifiable, Equatable {
    let id = UUID()
    let normalizedRect: CGRect
    let center: CGPoint
    let confidence: CGFloat
    let label: String
    let displayColor: Color
}
