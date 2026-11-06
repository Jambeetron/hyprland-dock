import QtQuick
import Quickshell

PopupWindow {
  id: root

  required property Item anchorItem
  required property string position
  required property bool canClose
  required property bool autoHide
  required property bool pinnedItem
  signal openNewWindow()
  signal closeWindow()
  signal addApplication()
  signal removeFromDock()
  signal toggleAutoHide()

  function open() {
    visible = true
  }

  implicitWidth: 180
  implicitHeight: 212
  color: "transparent"
  grabFocus: true

  anchor {
    window: root.anchorItem ? root.anchorItem.QsWindow.window : null
    adjustment: PopupAdjustment.Slide
    edges: Edges.Top | Edges.Left
    gravity: Edges.Bottom | Edges.Right
    rect.width: 1
    rect.height: 1

    onAnchoring: {
      if (!root.anchorItem || !root.anchor.window) return

      var x = root.anchorItem.width / 2 - root.implicitWidth / 2
      var y = root.anchorItem.height + 8
      if (root.position === "bottom")
        y = -root.implicitHeight - 8
      else if (root.position === "left") {
        x = root.anchorItem.width + 8
        y = root.anchorItem.height / 2 - root.implicitHeight / 2
      } else if (root.position === "right") {
        x = -root.implicitWidth - 8
        y = root.anchorItem.height / 2 - root.implicitHeight / 2
      }

      var point = root.anchor.window.contentItem.mapFromItem(root.anchorItem, x, y)
      if (root.position === "top" || root.position === "bottom")
        point.x = Math.max(8, Math.min(point.x, root.anchor.window.width - root.implicitWidth - 8))
      else
        point.y = Math.max(8, Math.min(point.y, root.anchor.window.height - root.implicitHeight - 8))

      root.anchor.rect.x = Math.round(point.x)
      root.anchor.rect.y = Math.round(point.y)
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: 12
    color: Qt.rgba(0.08, 0.09, 0.11, 0.97)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.18)

    Column {
      anchors.centerIn: parent

      DockMenuAction {
        text: "Add Application"
        onTriggered: {
          root.visible = false
          root.addApplication()
        }
      }

      DockMenuAction {
        text: root.pinnedItem ? "Remove from Dock" : "Pin to Dock"
        onTriggered: {
          root.visible = false
          root.removeFromDock()
        }
      }

      DockMenuAction {
        text: root.autoHide ? "Disable Auto-Hide" : "Enable Auto-Hide"
        onTriggered: {
          root.toggleAutoHide()
          root.visible = false
        }
      }

      Item {
        width: 168
        height: 10

        Rectangle {
          anchors.centerIn: parent
          width: 144
          height: 1
          color: Qt.rgba(1, 1, 1, 0.16)
        }
      }

      DockMenuAction {
        text: "Open New Window"
        onTriggered: {
          root.visible = false
          root.openNewWindow()
        }
      }

      DockMenuAction {
        text: "Close"
        enabled: root.canClose
        onTriggered: {
          root.visible = false
          root.closeWindow()
        }
      }
    }
  }
}
