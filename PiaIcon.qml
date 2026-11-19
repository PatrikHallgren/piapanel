import QtQuick
import qs.Commons
import qs.Commons as Commons

// The PIA robot head, drawn natively (the Tailscale widget's approach):
// an antenna, a rounded head with ear dots, and two square eyes. At 12px it
// reads as the PIA mark; no SVG/effect quirks in the tiny bar slot.
Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Commons.Color.foreground
  property bool active: false

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  readonly property real u: root.iconSize / 12  // design unit

  // Antenna mast, with a dot on top; hidden when disconnected? No — the mark
  // stays whole; state is carried by color and the strike-through instead.
  Rectangle {
    x: root.width / 2 - root.u * 0.5
    y: 0
    width: root.u
    height: root.u * 2.6
    color: root.color
  }

  Rectangle {
    x: root.width / 2 - root.u * 1.3
    y: 0
    width: root.u * 2.6
    height: root.u * 1.1
    radius: height / 2
    color: root.color
  }

  // The head: rounded square spanning the lower three-quarters.
  Rectangle {
    id: head
    x: root.u * 0.5
    y: root.u * 3.1
    width: root.width - root.u
    height: root.height - y
    radius: Math.min(width, height) * 0.3
    color: "transparent"
    border.width: Math.max(1, Math.round(root.u * 0.9))
    border.color: root.color
  }

  // Ear dots on the head's sides.
  Rectangle {
    x: head.x - root.u * 0.35
    y: head.y + head.height * 0.28
    width: root.u * 1.2
    height: root.u * 1.2
    radius: width / 2
    color: root.color
  }

  Rectangle {
    x: head.x + head.width - root.u * 0.85
    y: head.y + head.height * 0.28
    width: root.u * 1.2
    height: root.u * 1.2
    radius: width / 2
    color: root.color
  }

  // Eyes: full opacity when connected, hollow (outline only) when not.
  Rectangle {
    x: head.x + head.width * 0.30
    y: head.y + head.height * 0.32
    width: root.u * 1.3
    height: root.u * 1.3
    radius: Math.max(1, root.u * 0.25)
    color: root.active ? root.color : "transparent"
    border.width: root.active ? 0 : Math.max(1, Math.round(root.u * 0.55))
    border.color: root.color
  }

  Rectangle {
    x: head.x + head.width * 0.70 - width
    y: head.y + head.height * 0.32
    width: root.u * 1.3
    height: root.u * 1.3
    radius: Math.max(1, root.u * 0.25)
    color: root.active ? root.color : "transparent"
    border.width: root.active ? 0 : Math.max(1, Math.round(root.u * 0.55))
    border.color: root.color
  }
}
