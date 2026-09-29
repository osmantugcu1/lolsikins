import QtQuick 2.15
import QtQuick.Controls 2.15
import lolsikins.theme 1.0

// Thin neon scroll bar, shown only when there is something to scroll.
ScrollBar {
    id: control
    padding: 2

    contentItem: Rectangle {
        implicitWidth: 5
        implicitHeight: 5
        radius: width / 2
        color: control.pressed ? Neon.primary : Neon.alpha(Neon.primary, control.hovered ? 0.75 : 0.4)
        opacity: control.size < 1.0 ? 1 : 0
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    background: Item { }
}
