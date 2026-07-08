import UIKit

extension UIColor {
    convenience init?(hex: String) {
        let filtered = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: "#", with: "")

        guard filtered.count == 6, let value = Int(filtered, radix: 16) else {
            return nil
        }

        let red = CGFloat((value >> 16) & 0xFF) / 255
        let green = CGFloat((value >> 8) & 0xFF) / 255
        let blue = CGFloat(value & 0xFF) / 255

        self.init(red: red, green: green, blue: blue, alpha: 1)
    }

    var hexString: String {
        guard let components = cgColor.components else {
            return "#FF3B30"
        }

        let resolved: (CGFloat, CGFloat, CGFloat)
        switch components.count {
        case 2:
            resolved = (components[0], components[0], components[0])
        default:
            resolved = (components[0], components[1], components[2])
        }

        return String(
            format: "#%02X%02X%02X",
            Int(resolved.0 * 255),
            Int(resolved.1 * 255),
            Int(resolved.2 * 255)
        )
    }

    var hsv: HSVColor? {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        guard getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return nil
        }

        return HSVColor(hue: hue, saturation: saturation, brightness: brightness)
    }
}
