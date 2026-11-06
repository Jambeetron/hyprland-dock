import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

Item {
  id: root

  required property string desktopId
  required property int itemIndex
  required property bool pinnedItem
  required property bool instancePopupActive
  required property int slotSize
  required property int iconSize
  required property real magnification
  required property real magnificationRadius
  required property real pointerPosition
  required property string clickAction
  required property bool autoHide
  required property string position
  required property bool vertical
  property real reorderOffset: 0
  property bool instancePopupRequested: false
  signal dragStarted(int itemIndex)
  signal dragMoved(real mainPosition)
  signal dragFinished()
  signal instanceHoverEntered(string desktopId)
  signal instanceHoverLeft(string desktopId)
  signal addApplicationRequested()
  signal removeRequested(string desktopId)
  signal autoHideToggled(bool enabled)
  signal contextMenuVisibilityChanged(bool visible)

  // Reading the model makes this binding update when Quickshell finishes its
  // asynchronous desktop-entry scan. Calling byId() alone is not reactive.
  readonly property var applications: DesktopEntries.applications.values || []
  readonly property var entry: {
    var modelRevision = applications.length
    return DesktopEntries.byId(desktopId)
  }
  readonly property var toplevels: ToplevelManager.toplevels.values || []
  readonly property var runningToplevel: {
    var modelRevision = toplevels.length
    return findRunningToplevel()
  }
  readonly property var runningWindows: {
    var modelRevision = toplevels.length
    var matches = []
    for (var i = 0; i < toplevels.length; ++i) {
      if (matchesEntry(toplevels[i])) matches.push(toplevels[i])
    }
    return matches
  }
  readonly property real dragOffset: dragHandler.active
    ? vertical ? dragHandler.activeTranslation.y : dragHandler.activeTranslation.x
    : 0
  readonly property real itemCenter: (vertical ? y + height / 2 : x + width / 2)
    + dragOffset + reorderOffset
  readonly property real distance: Math.abs(pointerPosition - itemCenter)
  readonly property real influence: pointerPosition < -1000
    ? 0
    : Math.exp(-(distance * distance) / (magnificationRadius * magnificationRadius))
  readonly property real iconScale: 1 + (magnification - 1) * influence

  function normalizedId(value) {
    return String(value || "").toLowerCase().replace(/\.desktop$/, "")
  }

  function webAppId() {
    if (!entry || !entry.command) return ""

    for (var i = 0; i < entry.command.length; ++i) {
      var match = String(entry.command[i]).match(/https?:\/\/[^?#\s]+/i)
      if (!match) continue

      var url = match[0].replace(/^https?:\/\//i, "").replace(/\/$/, "")
      try {
        url = decodeURIComponent(url)
      } catch (error) {
        // Keep the encoded URL; it can still match the generated app ID.
      }
      return url.toLowerCase().replace(/[^a-z0-9]/g, "")
    }
    return ""
  }

  function matchesEntry(toplevel) {
    if (!toplevel) return false
    var appId = normalizedId(toplevel.appId)
    if (!appId) return false

    var ids = [desktopId]
    if (entry) ids.push(entry.id, entry.startupClass)
    for (var i = 0; i < ids.length; ++i) {
      var id = normalizedId(ids[i])
      if (id && appId === id) return true
    }

    var generatedWebAppId = webAppId()
    return generatedWebAppId.length >= 6
      && appId.replace(/[^a-z0-9]/g, "").indexOf(generatedWebAppId) >= 0
  }

  function findRunningToplevel() {
    for (var i = 0; i < toplevels.length; ++i) {
      if (matchesEntry(toplevels[i])) return toplevels[i]
    }
    return null
  }

  function launch() {
    if (entry)
      entry.execute()
    else
      Quickshell.execDetached(["gtk-launch", desktopId + ".desktop"])
  }

  function activateOrLaunch() {
    if (clickAction === "focus-or-launch" && runningToplevel) {
      runningToplevel.activate()
      return
    }
    launch()
  }

  function closeRunning() {
    if (runningToplevel)
      runningToplevel.close()
  }

  width: vertical ? slotSize + 6 : slotSize
  height: vertical ? slotSize : slotSize + 6
  z: dragHandler.active ? 2 : 0
  transform: Translate {
    x: root.vertical ? 0 : root.dragOffset + root.reorderOffset
    y: root.vertical ? root.dragOffset + root.reorderOffset : 0
  }

  Behavior on reorderOffset {
    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
  }

  Item {
    id: iconContainer

    x: root.vertical
      ? root.position === "left" ? 6 : root.width - root.iconSize - 6
      : (root.width - root.iconSize) / 2
    y: root.vertical
      ? (root.height - root.iconSize) / 2
      : root.position === "top" ? 6 : root.height - root.iconSize - 6
    width: root.iconSize
    height: root.iconSize
    transformOrigin: root.position === "top"
      ? Item.Top
      : root.position === "left"
        ? Item.Left
        : root.position === "right" ? Item.Right : Item.Bottom
    scale: root.iconScale

    Behavior on scale {
      NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
    }

    Rectangle {
      anchors.fill: parent
      anchors.margins: -4
      radius: 14
      color: mouse.hovered ? Qt.rgba(1, 1, 1, 0.10) : "transparent"

      Behavior on color { ColorAnimation { duration: 100 } }
    }

    IconImage {
      anchors.fill: parent
      source: root.entry && root.entry.icon
        ? Quickshell.iconPath(root.entry.icon, true)
        : Quickshell.iconPath("application-x-executable", true)
      asynchronous: true
    }

    Rectangle {
      width: 4
      height: 4
      radius: 2
      x: root.position === "left"
        ? iconContainer.width + 2
        : root.position === "right"
          ? -6
          : (iconContainer.width - width) / 2
      y: root.position === "top"
        ? -6
        : root.position === "bottom"
          ? iconContainer.height + 2
          : (iconContainer.height - height) / 2
      color: root.runningToplevel ? "#f5f5f5" : "transparent"
    }
  }

  Rectangle {
    id: tooltip

    visible: mouse.hovered && !contextMenu.visible
    x: root.position === "left"
      ? iconContainer.x + iconContainer.width + 12
      : root.position === "right"
        ? iconContainer.x - width - 12
        : (root.width - width) / 2
    y: root.position === "top"
      ? iconContainer.y + iconContainer.height + 12
      : root.position === "bottom"
        ? iconContainer.y - height - 12
        : (root.height - height) / 2
    width: tooltipText.implicitWidth + 18
    height: tooltipText.implicitHeight + 10
    radius: 8
    color: Qt.rgba(0.08, 0.09, 0.11, 0.96)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.16)
    z: 10

    Text {
      id: tooltipText
      anchors.centerIn: parent
      text: root.entry ? root.entry.name : root.desktopId
      color: "#f5f5f5"
      font.pixelSize: 13
    }
  }

  HoverHandler {
    id: mouse
    cursorShape: Qt.PointingHandCursor
    onHoveredChanged: {
      if (hovered) {
        popupCloseTimer.stop()
        root.instancePopupRequested = root.runningWindows.length > 0
        root.instanceHoverEntered(root.desktopId)
      } else {
        popupCloseTimer.restart()
      }
    }
  }

  Timer {
    id: popupCloseTimer
    interval: 250
    onTriggered: {
      if (!popupHover.hovered) {
        root.instancePopupRequested = false
        root.instanceHoverLeft(root.desktopId)
      }
    }
  }

  PopupWindow {
    id: instancesPopup

    visible: root.instancePopupRequested && root.instancePopupActive && root.runningWindows.length > 0
    color: "transparent"
    implicitWidth: 260
    implicitHeight: Math.min(root.runningWindows.length, 8) * 38 + 12

    anchor {
      window: root.QsWindow ? root.QsWindow.window : null
      adjustment: PopupAdjustment.Slide
      edges: Edges.Top | Edges.Left
      gravity: Edges.Top | Edges.Right

      onAnchoring: {
        if (!root.QsWindow || !instancesPopup.anchor.window) return
        var x = (root.width - instancesPopup.implicitWidth) / 2
        var y = root.height + 8
        if (root.position === "bottom") y = -instancesPopup.implicitHeight - 8
        else if (root.position === "left") {
          x = root.width + 8
          y = (root.height - instancesPopup.implicitHeight) / 2
        } else if (root.position === "right") {
          x = -instancesPopup.implicitWidth - 8
          y = (root.height - instancesPopup.implicitHeight) / 2
        }
        var point = instancesPopup.anchor.window.contentItem.mapFromItem(root, x, y)
        point.x = Math.max(8, Math.min(point.x, instancesPopup.anchor.window.width - instancesPopup.implicitWidth - 8))
        point.y = Math.max(8, Math.min(point.y, instancesPopup.anchor.window.height - instancesPopup.implicitHeight - 8))
        instancesPopup.anchor.rect.x = Math.round(point.x)
        instancesPopup.anchor.rect.y = Math.round(point.y)
      }
    }

    Rectangle {
      anchors.fill: parent
      radius: 12
      color: Qt.rgba(0.08, 0.09, 0.11, 0.97)
      border.width: 1
      border.color: Qt.rgba(1, 1, 1, 0.18)

      HoverHandler {
        id: popupHover
        onHoveredChanged: {
          if (hovered) popupCloseTimer.stop()
          else popupCloseTimer.restart()
        }
      }

      Column {
        anchors.fill: parent
        anchors.margins: 6

        Repeater {
          model: root.runningWindows.slice(0, 8)

          Rectangle {
            required property var modelData
            width: parent.width
            height: 38
            radius: 7
            color: rowHover.hovered ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

            Text {
              anchors.fill: parent
              anchors.leftMargin: 10
              anchors.rightMargin: 10
              verticalAlignment: Text.AlignVCenter
              text: modelData.title || root.entry?.name || root.desktopId
              color: "#f5f5f5"
              font.pixelSize: 13
              elide: Text.ElideRight
            }

            HoverHandler {
              id: rowHover
              cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
              acceptedButtons: Qt.LeftButton
              onTapped: {
                modelData.activate()
                root.instancePopupRequested = false
                root.instanceHoverLeft(root.desktopId)
              }
            }
          }
        }
      }
    }
  }

  TapHandler {
    acceptedButtons: Qt.LeftButton
    onTapped: root.activateOrLaunch()
  }

  TapHandler {
    acceptedButtons: Qt.RightButton
    onTapped: contextMenu.open()
  }

  DragHandler {
    id: dragHandler

    target: null
    enabled: root.pinnedItem
    acceptedButtons: Qt.LeftButton
    xAxis.enabled: !root.vertical
    yAxis.enabled: root.vertical
    onActiveChanged: {
      if (active)
        root.dragStarted(root.itemIndex)
      else
        root.dragFinished()
    }
    onActiveTranslationChanged: {
      if (active)
        root.dragMoved((root.vertical ? root.y + root.height / 2 : root.x + root.width / 2)
          + (root.vertical ? activeTranslation.y : activeTranslation.x))
    }
  }

  DockContextMenu {
    id: contextMenu

    anchorItem: root
    position: root.position
    canClose: root.runningToplevel !== null
    autoHide: root.autoHide
    pinnedItem: root.pinnedItem
    onVisibleChanged: root.contextMenuVisibilityChanged(visible)
    onOpenNewWindow: root.launch()
    onCloseWindow: root.closeRunning()
    onAddApplication: root.addApplicationRequested()
    onRemoveFromDock: root.removeRequested(root.desktopId)
    onToggleAutoHide: root.autoHideToggled(!root.autoHide)
  }
}
