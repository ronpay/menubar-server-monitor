import SwiftUI

struct Sparkline: View {
    let values: [Double]
    let tint: Color
    /// If set, fixes the y-axis to this range (e.g. 0...100 for percentages).
    /// Otherwise auto-scales to the values' min/max with a small padding.
    var range: ClosedRange<Double>? = nil
    var filled: Bool = true

    var body: some View {
        Canvas { ctx, size in
            guard values.count >= 2 else {
                if let v = values.first {
                    let (lo, hi) = effectiveRange()
                    let y = yFor(v, lo: lo, hi: hi, height: size.height)
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    ctx.stroke(path, with: .color(tint), lineWidth: 1.5)
                }
                return
            }

            let (lo, hi) = effectiveRange()
            let stepX = size.width / CGFloat(values.count - 1)

            var line = Path()
            for (i, v) in values.enumerated() {
                let x = CGFloat(i) * stepX
                let y = yFor(v, lo: lo, hi: hi, height: size.height)
                if i == 0 { line.move(to: CGPoint(x: x, y: y)) }
                else { line.addLine(to: CGPoint(x: x, y: y)) }
            }

            if filled {
                var area = line
                area.addLine(to: CGPoint(x: size.width, y: size.height))
                area.addLine(to: CGPoint(x: 0, y: size.height))
                area.closeSubpath()
                ctx.fill(area, with: .color(tint.opacity(0.18)))
            }

            ctx.stroke(line, with: .color(tint), lineWidth: 1.5)

            // Trailing dot at current value.
            if let last = values.last {
                let x = size.width
                let y = yFor(last, lo: lo, hi: hi, height: size.height)
                let dot = Path(ellipseIn: CGRect(x: x - 2.5, y: y - 2.5, width: 5, height: 5))
                ctx.fill(dot, with: .color(tint))
            }
        }
    }

    private func effectiveRange() -> (Double, Double) {
        if let r = range { return (r.lowerBound, r.upperBound) }
        let lo = values.min() ?? 0
        let hi = values.max() ?? 1
        if hi - lo < 0.0001 {
            return (lo - 1, hi + 1)
        }
        let pad = (hi - lo) * 0.1
        return (lo - pad, hi + pad)
    }

    private func yFor(_ v: Double, lo: Double, hi: Double, height: CGFloat) -> CGFloat {
        let denom = max(0.0001, hi - lo)
        let t = (v - lo) / denom
        return height - CGFloat(t) * height
    }
}
