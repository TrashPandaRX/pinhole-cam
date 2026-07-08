import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var camera = CameraPipeline()
    @State private var hexInput = "#FF3B30"

    var body: some View {
        ZStack(alignment: .top) {
            CameraPreviewView(session: camera.session)
                .ignoresSafeArea()
                .overlay {
                    DetectionOverlayView(
                        regions: camera.detectedRegions,
                        videoSize: camera.videoSize
                    )
                }

            VStack(spacing: 12) {
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                            camera.isPanelCollapsed.toggle()
                        }
                    } label: {
                        Label(camera.isPanelCollapsed ? "Show Controls" : "Hide Controls", systemImage: camera.isPanelCollapsed ? "slider.horizontal.3" : "xmark")
                            .font(.headline)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                if !camera.isPanelCollapsed {
                    controlsCard
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()
            }
        }
        .background(Color.black)
        .task {
            hexInput = camera.target.hex
            camera.start()
        }
        .onDisappear {
            camera.stop()
        }
    }

    private var controlsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Color Range Detector")
                .font(.headline)

            if let message = camera.lastError {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }

            ColorPicker("Target Color", selection: targetColorBinding, supportsOpacity: false)

            HStack(spacing: 12) {
                TextField("#RRGGBB", text: $hexInput)
                    .font(.system(.body, design: .monospaced))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .onSubmit(applyHexInput)

                Button("Apply", action: applyHexInput)
                    .buttonStyle(.borderedProminent)
            }

            SliderRow(
                title: "Hue Tolerance",
                value: targetBinding(\.hueTolerance),
                range: 0.005...0.15,
                display: { String(format: "%.3f", $0) }
            )

            SliderRow(
                title: "Saturation Tolerance",
                value: targetBinding(\.saturationTolerance),
                range: 0.05...1,
                display: { String(format: "%.2f", $0) }
            )

            SliderRow(
                title: "Brightness Tolerance",
                value: targetBinding(\.brightnessTolerance),
                range: 0.05...1,
                display: { String(format: "%.2f", $0) }
            )

            Stepper(
                "Minimum Cluster Size: \(camera.target.minimumClusterCells) cells",
                value: targetBinding(\.minimumClusterCells),
                in: 4...120
            )

            Stepper(
                "Sampling Step: \(camera.target.samplingStride) px",
                value: targetBinding(\.samplingStride),
                in: 2...12
            )

            Text("Pins mark the center of each matched region. The outlined box shows the sampled area that falls inside the current color range.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal)
    }

    private var targetColorBinding: Binding<Color> {
        Binding {
            Color(uiColor: camera.target.uiColor)
        } set: { newValue in
            var updated = camera.target
            updated.hex = UIColor(newValue).hexString
            camera.target = updated
            hexInput = updated.hex
        }
    }

    private func targetBinding<Value>(_ keyPath: WritableKeyPath<ColorTarget, Value>) -> Binding<Value> {
        Binding {
            camera.target[keyPath: keyPath]
        } set: { newValue in
            var updated = camera.target
            updated[keyPath: keyPath] = newValue
            camera.target = updated
        }
    }

    private func applyHexInput() {
        guard let color = UIColor(hex: hexInput) else {
            return
        }

        var updated = camera.target
        updated.hex = color.hexString
        camera.target = updated
        hexInput = updated.hex
    }
}

private struct SliderRow: View {
    let title: String
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    let display: (CGFloat) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text(display(value))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Slider(value: $value, in: range)
        }
    }
}

private struct DetectionOverlayView: View {
    let regions: [DetectedRegion]
    let videoSize: CGSize

    var body: some View {
        GeometryReader { geometry in
            let fittedRect = aspectFitRect(content: videoSize, in: geometry.size)

            ZStack {
                ForEach(regions) { region in
                    let rect = denormalizedRect(for: region.normalizedRect, in: fittedRect)

                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(region.displayColor, lineWidth: 2)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)

                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(region.displayColor)
                                .frame(width: 20, height: 20)

                            Circle()
                                .stroke(.white, lineWidth: 2)
                                .frame(width: 20, height: 20)
                        }

                        Text(region.label)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .position(
                        x: rect.midX,
                        y: max(rect.minY - 20, fittedRect.minY + 18)
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
    }

    private func aspectFitRect(content: CGSize, in container: CGSize) -> CGRect {
        guard content.width > 0, content.height > 0 else {
            return CGRect(origin: .zero, size: container)
        }

        let scale = min(container.width / content.width, container.height / content.height)
        let width = content.width * scale
        let height = content.height * scale
        let origin = CGPoint(
            x: (container.width - width) / 2,
            y: (container.height - height) / 2
        )

        return CGRect(origin: origin, size: CGSize(width: width, height: height))
    }

    private func denormalizedRect(for normalized: CGRect, in fittedRect: CGRect) -> CGRect {
        CGRect(
            x: fittedRect.minX + (normalized.minX * fittedRect.width),
            y: fittedRect.minY + (normalized.minY * fittedRect.height),
            width: normalized.width * fittedRect.width,
            height: normalized.height * fittedRect.height
        )
    }
}
