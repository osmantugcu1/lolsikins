import QtQuick 2.15
import lolsikins.theme 1.0

// Dark backdrop with two soft neon glows and a faint grid.
Rectangle {
    id: root
    gradient: Gradient {
        GradientStop { position: 0.0; color: Neon.bg2 }
        GradientStop { position: 1.0; color: Neon.bg }
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        property color a: Neon.primary
        property color b: Neon.secondary
        onAChanged: requestPaint()
        onBChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        function glow(ctx, x, y, r, c, strength) {
            let g = ctx.createRadialGradient(x, y, 0, x, y, r)
            g.addColorStop(0, Qt.rgba(c.r, c.g, c.b, strength))
            g.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0))
            ctx.fillStyle = g
            ctx.fillRect(0, 0, width, height)
        }

        onPaint: {
            let ctx = getContext("2d")
            ctx.reset()
            let r = Math.max(width, height) * 0.7
            glow(ctx, width * 0.05, height * 0.0, r, a, 0.16)
            glow(ctx, width * 0.95, height * 1.0, r, b, 0.14)

            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.025)
            ctx.lineWidth = 1
            ctx.beginPath()
            for (let x = 0; x < width; x += 48) {
                ctx.moveTo(x + 0.5, 0)
                ctx.lineTo(x + 0.5, height)
            }
            for (let y = 0; y < height; y += 48) {
                ctx.moveTo(0, y + 0.5)
                ctx.lineTo(width, y + 0.5)
            }
            ctx.stroke()
        }
    }
}
