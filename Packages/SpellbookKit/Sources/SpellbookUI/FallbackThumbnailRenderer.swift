import SwiftUI

struct FallbackThumbnailRenderer {
    let composition: FallbackThumbnailComposition
    let palette: FallbackThumbnailPalette
    let seed: Int

    func draw(context: inout GraphicsContext, bounds: CGRect) {
        let cornerRadius = min(bounds.width, bounds.height) * 0.22
        context.clip(to: RoundedRectangle(cornerRadius: cornerRadius).path(in: bounds))
        context.fill(Path(bounds), with: .color(color(0)))

        switch composition {
        case .croppedGeometry:
            drawCroppedGeometry(context: &context, bounds: bounds)
        case .mosaicTiles:
            drawMosaicTiles(context: &context, bounds: bounds)
        case .concentricForms:
            drawConcentricForms(context: &context, bounds: bounds)
        case .radialFan:
            drawRadialFan(context: &context, bounds: bounds)
        case .wovenStrips:
            drawWovenStrips(context: &context, bounds: bounds)
        }
    }

    private func color(_ offset: Int) -> Color {
        let index = offset &+ seed
        let remainder = index % palette.colors.count
        let wrappedIndex = remainder >= 0 ? remainder : remainder + palette.colors.count
        return palette.colors[wrappedIndex]
    }

    private func drawCroppedGeometry(context: inout GraphicsContext, bounds: CGRect) {
        let width = bounds.width
        let height = bounds.height
        let mirrors = seed.isMultiple(of: 2)
        let circleRect = CGRect(
            x: mirrors ? width * 0.42 : width * -0.22,
            y: height * -0.18,
            width: width * 0.92,
            height: height * 0.92
        )
        context.fill(Path(ellipseIn: circleRect), with: .color(color(2)))

        var slab = Path()
        if mirrors {
            slab.move(to: CGPoint(x: width * -0.18, y: height * 0.58))
            slab.addLine(to: CGPoint(x: width * 0.67, y: height * 0.38))
            slab.addLine(to: CGPoint(x: width * 1.12, y: height * 0.78))
            slab.addLine(to: CGPoint(x: width * 0.14, y: height * 1.14))
        } else {
            slab.move(to: CGPoint(x: width * 1.18, y: height * 0.58))
            slab.addLine(to: CGPoint(x: width * 0.33, y: height * 0.38))
            slab.addLine(to: CGPoint(x: width * -0.12, y: height * 0.78))
            slab.addLine(to: CGPoint(x: width * 0.86, y: height * 1.14))
        }
        slab.closeSubpath()
        context.fill(slab, with: .color(color(4)))

        let dotSize = width * 0.19
        let dotRect = CGRect(
            x: mirrors ? width * 0.12 : width * 0.69,
            y: height * 0.15,
            width: dotSize,
            height: dotSize
        )
        context.fill(Path(ellipseIn: dotRect), with: .color(color(1)))
    }

    private func drawMosaicTiles(context: inout GraphicsContext, bounds: CGRect) {
        let width = bounds.width
        let height = bounds.height
        let splitX = seed.isMultiple(of: 2) ? 0.58 : 0.42
        let splitY = seed.isMultiple(of: 3) ? 0.46 : 0.56

        fill(
            CGRect(x: 0, y: 0, width: width * splitX, height: height * splitY),
            color: color(1),
            context: &context
        )
        fill(
            CGRect(x: width * splitX, y: 0, width: width * (1 - splitX), height: height * 0.34),
            color: color(3),
            context: &context
        )
        fill(
            CGRect(
                x: width * splitX,
                y: height * 0.34,
                width: width * (1 - splitX),
                height: height * (splitY - 0.34)
            ),
            color: color(2),
            context: &context
        )
        fill(
            CGRect(x: 0, y: height * splitY, width: width * 0.34, height: height * (1 - splitY)),
            color: color(4),
            context: &context
        )
        fill(
            CGRect(
                x: width * 0.34,
                y: height * splitY,
                width: width * 0.42,
                height: height * (1 - splitY)
            ),
            color: color(2),
            context: &context
        )
        fill(
            CGRect(
                x: width * 0.76,
                y: height * splitY,
                width: width * 0.24,
                height: height * (1 - splitY)
            ),
            color: color(1),
            context: &context
        )
    }

    private func drawConcentricForms(context: inout GraphicsContext, bounds: CGRect) {
        let width = bounds.width
        let height = bounds.height
        let center = CGPoint(
            x: seed.isMultiple(of: 2) ? width * 0.66 : width * 0.34,
            y: seed.isMultiple(of: 3) ? height * 0.36 : height * 0.66
        )
        let diameters: [Double] = [1.38, 0.98, 0.62, 0.28]

        for (index, multiplier) in diameters.enumerated() {
            let diameter = width * multiplier
            let rect = CGRect(
                x: center.x - diameter / 2,
                y: center.y - diameter / 2,
                width: diameter,
                height: diameter
            )
            context.fill(Path(ellipseIn: rect), with: .color(color(index + 1)))
        }
    }

    private func drawRadialFan(context: inout GraphicsContext, bounds: CGRect) {
        let width = bounds.width
        let height = bounds.height
        let mirrors = seed.isMultiple(of: 2)
        let anchor = CGPoint(
            x: mirrors ? width * -0.18 : width * 1.18,
            y: height * 1.14
        )
        let normalizedBoundary: [CGPoint] = [
            CGPoint(x: -0.24, y: -0.18),
            CGPoint(x: 0.14, y: -0.18),
            CGPoint(x: 0.52, y: -0.18),
            CGPoint(x: 0.9, y: -0.18),
            CGPoint(x: 1.18, y: 0.18),
            CGPoint(x: 1.18, y: 0.62),
            CGPoint(x: 1.18, y: 1.12)
        ]
        let boundary = normalizedBoundary.map { point in
            CGPoint(
                x: (mirrors ? point.x : 1 - point.x) * width,
                y: point.y * height
            )
        }

        for index in 0..<(boundary.count - 1) {
            var wedge = Path()
            wedge.move(to: anchor)
            wedge.addLine(to: boundary[index])
            wedge.addLine(to: boundary[index + 1])
            wedge.closeSubpath()
            context.fill(wedge, with: .color(color(index + 1)))
        }
    }

    private func drawWovenStrips(context: inout GraphicsContext, bounds: CGRect) {
        let width = bounds.width
        let height = bounds.height
        let verticalXs = seed.isMultiple(of: 2) ? [0.14, 0.58] : [0.2, 0.64]
        let horizontalYs = seed.isMultiple(of: 3) ? [0.16, 0.58] : [0.22, 0.64]
        let stripWidth = width * 0.22
        let stripHeight = height * 0.22

        for (index, x) in verticalXs.enumerated() {
            let rect = CGRect(x: width * x, y: -height * 0.08, width: stripWidth, height: height * 1.16)
            context.fill(
                RoundedRectangle(cornerRadius: stripWidth * 0.32).path(in: rect),
                with: .color(color(index + 1))
            )
        }

        for (index, y) in horizontalYs.enumerated() {
            let rect = CGRect(x: -width * 0.08, y: height * y, width: width * 1.16, height: stripHeight)
            context.fill(
                RoundedRectangle(cornerRadius: stripHeight * 0.32).path(in: rect),
                with: .color(color(index + 3))
            )
        }

        for index in 0..<verticalXs.count {
            let horizontalIndex = index % horizontalYs.count
            let patch = CGRect(
                x: width * verticalXs[index],
                y: height * horizontalYs[horizontalIndex],
                width: stripWidth,
                height: stripHeight
            )
            context.fill(Path(patch), with: .color(color(index + 1)))
        }
    }

    private func fill(_ rect: CGRect, color: Color, context: inout GraphicsContext) {
        context.fill(Path(rect), with: .color(color))
    }
}
