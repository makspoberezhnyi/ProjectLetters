import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers
import PDFKit
#if canImport(LettersKit)
import LettersKit
#endif

// MARK: - Visual Publishing Guides & Interactive Horizontal Ruler
struct StudioHorizontalRulerView: View {
    let sheetWidth: CGFloat
    var zoomScale: CGFloat = 1.0
    @Binding var margins: PageMargins
    @Binding var hangingIndent: CGFloat
    var onMarginChanged: () -> Void = {}

    @AppStorage("letters_ruler_unit") private var rulerUnitString: String = "in"

    @State private var leftDragStart: CGFloat? = nil
    @State private var rightDragStart: CGFloat? = nil
    @State private var indentDragStart: CGFloat? = nil

    var isMetric: Bool {
        rulerUnitString == "cm"
    }

    // Conversion: 72 pt = 1 inch, 28.3464567 pt = 1 cm
    var ptPerUnit: CGFloat {
        isMetric ? 28.3464567 : 72.0
    }

    var subdivisions: Int {
        isMetric ? 2 : 4 // cm: 0.5 cm ticks; in: 1/4 in ticks
    }

    var minorStep: CGFloat {
        ptPerUnit / CGFloat(subdivisions)
    }

    func snapCoordinate(_ val: CGFloat, isShift: Bool) -> CGFloat {
        if isShift {
            // Snaps to exact whole unit (1.0 in or 1.0 cm)
            return round(val / ptPerUnit) * ptPerUnit
        }
        let nearestTick = round(val / minorStep) * minorStep
        if abs(val - nearestTick) < 5.0 {
            return nearestTick
        }
        return round(val)
    }

    func formatUnit(_ pt: CGFloat) -> String {
        if isMetric {
            let cm = Double(pt) / 28.3464567
            return String(format: "%.1f cm", cm)
        } else {
            let inch = Double(pt) / 72.0
            return String(format: "%.2f\"", inch)
        }
    }

    var body: some View {
        let effectiveWidth = sheetWidth * zoomScale
        let scaledLeftMargin = margins.left * zoomScale
        let scaledRightMargin = margins.right * zoomScale
        let rightHandleX = effectiveWidth - scaledRightMargin

        ZStack(alignment: .topLeading) {
            // 1. Single Pixel-Aligned High-DPI CoreGraphics Canvas
            Canvas { context, size in
                let w = size.width
                let h = size.height

                // Transparent ruler track background with crisp 1px borders
                let trackRect = CGRect(x: 0, y: 0, width: w, height: h)
                context.fill(Path(trackRect), with: .color(Color(nsColor: .windowBackgroundColor).opacity(0.35)))

                let topPath = Path { p in
                    p.move(to: CGPoint(x: 0, y: 0.5))
                    p.addLine(to: CGPoint(x: w, y: 0.5))
                }
                let bottomPath = Path { p in
                    p.move(to: CGPoint(x: 0, y: h - 0.5))
                    p.addLine(to: CGPoint(x: w, y: h - 0.5))
                }
                context.stroke(topPath, with: .color(Color.primary.opacity(0.12)), lineWidth: 1)
                context.stroke(bottomPath, with: .color(Color.primary.opacity(0.12)), lineWidth: 1)

                // Transparent Active Printable Column with subtle accent tint (Never solid white)
                let activeLeft = floor(scaledLeftMargin) + 0.5
                let activeRight = floor(rightHandleX) + 0.5
                if activeRight > activeLeft {
                    let activeRect = CGRect(x: activeLeft, y: 1, width: activeRight - activeLeft, height: h - 2)
                    context.fill(Path(activeRect), with: .color(Color.accentColor.opacity(0.04)))

                    // Left & Right boundary guidelines
                    let leftLine = Path { p in
                        p.move(to: CGPoint(x: activeLeft, y: 0))
                        p.addLine(to: CGPoint(x: activeLeft, y: h))
                    }
                    let rightLine = Path { p in
                        p.move(to: CGPoint(x: activeRight, y: 0))
                        p.addLine(to: CGPoint(x: activeRight, y: h))
                    }
                    context.stroke(leftLine, with: .color(Color.accentColor.opacity(0.5)), lineWidth: 1)
                    context.stroke(rightLine, with: .color(Color.accentColor.opacity(0.5)), lineWidth: 1)
                }

                // Ticks & Numbers drawing
                let totalSteps = Int(ceil(sheetWidth / minorStep))
                for step in 0...totalSteps {
                    let rawX = CGFloat(step) * minorStep * zoomScale
                    if rawX > w { break }
                    let x = floor(rawX) + 0.5
                    let isMajor = (step % subdivisions == 0)
                    let isHalf = isMetric ? false : (step % 2 == 0)
                    let tickH: CGFloat = isMajor ? 7.5 : (isHalf ? 5.0 : 3.0)

                    let tickPath = Path { p in
                        p.move(to: CGPoint(x: x, y: h - tickH))
                        p.addLine(to: CGPoint(x: x, y: h))
                    }
                    context.stroke(tickPath, with: .color(Color(nsColor: .labelColor).opacity(isMajor ? 0.75 : 0.35)), lineWidth: 1)

                    if isMajor && step > 0 {
                        let unitValue = step / subdivisions
                        let labelText = Text("\(unitValue)")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(nsColor: .labelColor))
                        context.draw(labelText, at: CGPoint(x: x, y: 8), anchor: .center)
                    }
                }
            }
            .frame(width: effectiveWidth, height: 26)

            // Unit Switcher Tag (Click to toggle in / cm)
            Button {
                rulerUnitString = isMetric ? "in" : "cm"
            } label: {
                Text(isMetric ? "cm" : "in")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 3))
            }
            .buttonStyle(.plain)
            .position(x: min(effectiveWidth - 14, effectiveWidth - scaledRightMargin / 2), y: 8)
            .help("Click to switch ruler units (Inches / Centimeters)")

            // 3. Hanging / First-Line Indent Handle (Top downward triangle at y: 5)
            let indentX = (margins.left + hangingIndent) * zoomScale
            ZStack {
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 8))
                    .foregroundColor(Color.orange.opacity(0.95))
                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 0.5)
            }
            .frame(width: 16, height: 16)
            .contentShape(Rectangle())
            .position(x: indentX, y: 5)
            .help("First Line / Hanging Indent: \(formatUnit(hangingIndent)) (\(Int(hangingIndent)) pt) • Hold ⇧ to snap to 1 \(isMetric ? "cm" : "inch")")
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if indentDragStart == nil { indentDragStart = hangingIndent }
                        let base = indentDragStart ?? hangingIndent
                        let deltaDoc = value.translation.width / zoomScale
                        let proposedX = margins.left + base + deltaDoc
                        let isShift = NSEvent.modifierFlags.contains(.shift)
                        let snappedX = snapCoordinate(proposedX, isShift: isShift)
                        hangingIndent = max(0, min(144, snappedX - margins.left))
                    }
                    .onEnded { _ in
                        indentDragStart = nil
                    }
            )

            // 4. Left Margin Draggable Handle (Bottom upward triangle at y: 20)
            ZStack {
                Image(systemName: "arrowtriangle.up.fill")
                    .font(.system(size: 8.5))
                    .foregroundColor(.accentColor)
                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 0.5)
            }
            .frame(width: 16, height: 16)
            .contentShape(Rectangle())
            .position(x: scaledLeftMargin, y: 20)
            .help("Left Margin: \(formatUnit(margins.left)) (\(Int(margins.left)) pt) • Hold ⇧ to snap to 1 \(isMetric ? "cm" : "inch")")
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if leftDragStart == nil { leftDragStart = margins.left }
                        let base = leftDragStart ?? margins.left
                        let deltaDoc = value.translation.width / zoomScale
                        let proposed = min(max(18, base + deltaDoc), sheetWidth - margins.right - 72)
                        let isShift = NSEvent.modifierFlags.contains(.shift)
                        margins.left = snapCoordinate(proposed, isShift: isShift)
                        onMarginChanged()
                    }
                    .onEnded { _ in
                        leftDragStart = nil
                    }
            )

            // 5. Right Margin Draggable Handle (Bottom upward triangle at y: 20)
            ZStack {
                Image(systemName: "arrowtriangle.up.fill")
                    .font(.system(size: 8.5))
                    .foregroundColor(.accentColor)
                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 0.5)
            }
            .frame(width: 16, height: 16)
            .contentShape(Rectangle())
            .position(x: rightHandleX, y: 20)
            .help("Right Margin: \(formatUnit(margins.right)) (\(Int(margins.right)) pt) • Hold ⇧ to snap to 1 \(isMetric ? "cm" : "inch")")
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if rightDragStart == nil { rightDragStart = margins.right }
                        let base = rightDragStart ?? margins.right
                        let deltaDoc = value.translation.width / zoomScale
                        let proposedX = sheetWidth - (base - deltaDoc)
                        let isShift = NSEvent.modifierFlags.contains(.shift)
                        let snappedX = snapCoordinate(proposedX, isShift: isShift)
                        margins.right = max(18, min(sheetWidth - margins.left - 72, sheetWidth - snappedX))
                        onMarginChanged()
                    }
                    .onEnded { _ in
                        rightDragStart = nil
                    }
            )
        }
        .frame(width: effectiveWidth, height: 26, alignment: .topLeading)
    }
}
