pragma Singleton
import QtQuick 2.15

// Colors and sizes shared by every screen.
QtObject {
    property int preset: 0

    readonly property var presets: [
        { "key": "themeCyber", "a": "#00E5FF", "b": "#FF2BD6" },
        { "key": "themeGalaxy", "a": "#A855F7", "b": "#FF3D9A" },
        { "key": "themeToxic", "a": "#39FF88", "b": "#00C8FF" },
        { "key": "themeLava", "a": "#FFB020", "b": "#FF3B5C" }
    ]
    readonly property var current: presets[Math.max(0, Math.min(preset, presets.length - 1))]

    readonly property color primary: current.a
    readonly property color secondary: current.b

    readonly property color bg: "#06060D"
    readonly property color bg2: "#0C0C19"
    readonly property color surface: "#12122A"
    readonly property color surfaceHover: "#191936"
    readonly property color surfaceRaised: "#1E1E40"
    readonly property color border: "#26264D"
    readonly property color text: "#EEEDFF"
    readonly property color textMuted: "#8C8AB8"
    readonly property color textOnNeon: "#07070F"
    readonly property color danger: "#FF4D6D"
    readonly property color success: "#39FF88"

    readonly property int radius: 14
    readonly property int radiusSmall: 10

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }
}
