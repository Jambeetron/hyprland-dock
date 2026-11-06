pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
  id: root

  required property var settings
  signal reorderRequested(int from, int to)
  signal pinRequested(string desktopId)
  signal unpinRequested(string desktopId)
  signal autoHideRequested(bool enabled)

  property int dragSource: -1
  property int dragTarget: -1
  property int openMenuCount: 0
  property bool autoHideRevealed: false
  property string activeInstanceDesktopId: ""

  readonly property int iconSize: settings.iconSize || 52
  readonly property real magnification: settings.magnification || 1.65
  readonly property real magnificationRadius: settings.magnificationRadius || 110
  readonly property int edgeMargin: settings.margin === undefined ? 10 : settings.margin
  readonly property real backgroundOpacity: {
    var value = Number(settings.backgroundOpacity)
    return settings.backgroundOpacity === undefined || isNaN(value)
      ? 0.88
      : Math.max(0, Math.min(1, value))
  }
  readonly property bool reserveSpace: settings.reserveSpace === undefined ? true : settings.reserveSpace
  readonly property bool autoHide: settings.autoHide === undefined ? false : settings.autoHide
  readonly property string clickAction: settings.clickAction || "focus-or-launch"
  readonly property string requestedPosition: settings.position || "bottom"
  readonly property string position: ["top", "bottom", "left", "right"].indexOf(requestedPosition) >= 0
    ? requestedPosition
    : "bottom"
  readonly property bool vertical: position === "left" || position === "right"
  readonly property bool fullLength: settings.fullLength === undefined ? false : settings.fullLength
  readonly property var pinned: settings.pinned || []
  readonly property var toplevels: ToplevelManager.toplevels.values || []
  readonly property var applications: DesktopEntries.applications.values || []
  readonly property var dockItems: {
    var result = pinned.slice()
    var appRevision = applications.length
    var windowRevision = toplevels.length

    function normalized(value) {
      return String(value || "").toLowerCase().replace(/\.desktop$/, "")
    }

    for (var i = 0; i < toplevels.length; ++i) {
      var windowAppId = normalized(toplevels[i].appId)
      if (!windowAppId) continue

      var desktopId = ""
      for (var j = 0; j < applications.length; ++j) {
        var application = applications[j]
        if (normalized(application.id) === windowAppId
            || normalized(application.startupClass) === windowAppId) {
          desktopId = application.id
          break
        }
      }
      if (!desktopId) desktopId = windowAppId

      var alreadyRepresented = false
      for (var k = 0; k < pinned.length; ++k) {
        var pinnedId = normalized(pinned[k])
        var pinnedEntry = DesktopEntries.byId(pinned[k])
        if (pinnedId === windowAppId
            || pinnedId === normalized(desktopId)
            || (pinnedEntry && normalized(pinnedEntry.startupClass) === windowAppId)) {
          alreadyRepresented = true
          break
        }
      }
      if (!alreadyRepresented && result.indexOf(desktopId) < 0)
        result.push(desktopId)
    }

    return result
  }
  readonly property int itemSize: iconSize + 14
  readonly property int reservedSize: iconSize + 24 + edgeMargin
  readonly property int mainPadding: 10
  readonly property int revealThickness: 3
  readonly property int crossExtent: vertical
    ? Math.ceil(iconSize * magnification + 80) + edgeMargin
    : Math.ceil(iconSize * magnification + 48) + edgeMargin
  readonly property bool keepAutoHideOpen: windowPointer.hovered
    || appPicker.visible || openMenuCount > 0 || dragSource >= 0
  readonly property bool dockShown: !autoHide || autoHideRevealed
  readonly property real pointerPosition: !pointer.hovered
    ? -10000
    : vertical
      ? pointer.point.position.y - dockLayout.y
      : pointer.point.position.x - dockLayout.x

  function reorderOffset(index) {
    if (dragSource < dragTarget && index > dragSource && index <= dragTarget)
      return -itemSize
    if (dragSource > dragTarget && index >= dragTarget && index < dragSource)
      return itemSize
    return 0
  }

  function updateDragTarget(position) {
    dragTarget = Math.max(0, Math.min(pinned.length - 1, Math.floor(position / itemSize)))
  }

  function finishDrag() {
    var from = dragSource
    var to = dragTarget
    dragSource = -1
    dragTarget = -1
    if (from >= 0 && to >= 0 && from !== to)
      reorderRequested(from, to)
  }

  function updateAutoHideState() {
    if (!autoHide) {
      hideTimer.stop()
      autoHideRevealed = false
    } else if (keepAutoHideOpen) {
      hideTimer.stop()
      autoHideRevealed = true
    } else if (autoHideRevealed) {
      hideTimer.restart()
    }
  }

  onAutoHideChanged: updateAutoHideState()
  onKeepAutoHideOpenChanged: updateAutoHideState()

  anchors {
    top: position === "top" || (vertical && fullLength)
    bottom: position === "bottom" || (vertical && fullLength)
    left: position === "left" || (!vertical && fullLength)
    right: position === "right" || (!vertical && fullLength)
  }
  implicitWidth: vertical
    ? crossExtent
    : fullLength ? 0 : dockLayout.implicitWidth + mainPadding * 2
  implicitHeight: vertical
    ? fullLength ? 0 : dockLayout.implicitHeight + mainPadding * 2
    : crossExtent
  color: "transparent"
  exclusionMode: reserveSpace && !autoHide ? ExclusionMode.Normal : ExclusionMode.Ignore
  WlrLayershell.exclusiveZone: reserveSpace && !autoHide ? reservedSize : 0
  WlrLayershell.namespace: "hyprland-dock"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  mask: Region {
    item: root.dockShown ? interactionArea : revealStrip
  }

  Timer {
    id: hideTimer

    interval: 800
    onTriggered: if (root.autoHide && !root.keepAutoHideOpen)
      root.autoHideRevealed = false
  }

  Item {
    id: interactionArea

    anchors.fill: parent
  }

  Item {
    id: revealStrip

    x: root.position === "right" ? parent.width - width : 0
    y: root.position === "bottom" ? parent.height - height : 0
    width: root.vertical ? root.revealThickness : parent.width
    height: root.vertical ? parent.height : root.revealThickness
  }

  Rectangle {
    id: dockBackground

    x: root.vertical
      ? root.position === "left" ? root.edgeMargin : parent.width - width - root.edgeMargin
      : 0
    y: root.vertical
      ? 0
      : root.position === "top" ? root.edgeMargin : parent.height - height - root.edgeMargin
    width: root.vertical ? root.iconSize + 24 : parent.width
    height: root.vertical ? parent.height : root.iconSize + 24
    radius: 20
    color: Qt.rgba(0.08, 0.09, 0.11, root.backgroundOpacity)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.18)
    transform: Translate {
      x: !root.autoHide || root.dockShown
        ? 0
        : root.position === "left"
          ? -(dockBackground.width + root.edgeMargin)
          : root.position === "right" ? dockBackground.width + root.edgeMargin : 0
      y: !root.autoHide || root.dockShown
        ? 0
        : root.position === "top"
          ? -(dockBackground.height + root.edgeMargin)
          : root.position === "bottom" ? dockBackground.height + root.edgeMargin : 0

      Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
      Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    }

    Rectangle {
      anchors.fill: parent
      anchors.margins: 1
      radius: parent.radius - 1
      color: "transparent"
      border.width: 1
      border.color: Qt.rgba(0, 0, 0, 0.28)
    }

    Grid {
      id: dockLayout

      // Offset the layout toward the screen edge so the icon itself, rather
      // than the icon-plus-indicator slot, is centered in the background.
      x: root.vertical
        ? root.position === "left" ? 6 : parent.width - implicitWidth - 6
        : (parent.width - implicitWidth) / 2
      y: root.vertical
        ? (parent.height - implicitHeight) / 2
        : root.position === "top" ? 6 : parent.height - implicitHeight - 6

      // Keep one spare cell so a settings reload cannot transiently reduce the
      // grid capacity before the repeater updates its delegates.
      columns: root.vertical ? 1 : Math.max(1, root.dockItems.length + 1)
      rows: root.vertical ? Math.max(1, root.dockItems.length + 1) : 1

      Repeater {
        model: root.dockItems

        DockItem {
          required property string modelData
          required property int index

          desktopId: modelData
          itemIndex: index
          pinnedItem: root.pinned.indexOf(modelData) >= 0
          instancePopupActive: root.activeInstanceDesktopId === modelData
          slotSize: root.itemSize
          iconSize: root.iconSize
          magnification: root.magnification
          magnificationRadius: root.magnificationRadius
          pointerPosition: root.pointerPosition
          clickAction: root.clickAction
          autoHide: root.autoHide
          position: root.position
          vertical: root.vertical
          reorderOffset: root.reorderOffset(index)
          onDragStarted: itemIndex => {
            root.dragSource = itemIndex
            root.dragTarget = itemIndex
          }
          onDragMoved: mainPosition => root.updateDragTarget(mainPosition)
          onDragFinished: root.finishDrag()
          onInstanceHoverEntered: desktopId => root.activeInstanceDesktopId = desktopId
          onInstanceHoverLeft: desktopId => {
            if (root.activeInstanceDesktopId === desktopId)
              root.activeInstanceDesktopId = ""
          }
          onAddApplicationRequested: appPicker.open()
          onRemoveRequested: desktopId => {
            if (root.pinned.indexOf(desktopId) >= 0)
              root.unpinRequested(desktopId)
            else
              root.pinRequested(desktopId)
          }
          onAutoHideToggled: enabled => root.autoHideRequested(enabled)
          onContextMenuVisibilityChanged: visible => {
            root.openMenuCount = Math.max(0, root.openMenuCount + (visible ? 1 : -1))
          }
        }
      }

      Item {
        id: drawerButton
        width: root.itemSize
        height: root.itemSize

        readonly property real distance: Math.abs(root.pointerPosition
          - (root.vertical ? y + height / 2 : x + width / 2))
        readonly property real influence: root.pointerPosition < -1000
          ? 0
          : Math.exp(-(distance * distance) / (root.magnificationRadius * root.magnificationRadius))
        readonly property real iconScale: 1 + (root.magnification - 1) * influence

        Rectangle {
          id: drawerButtonVisual
          anchors.centerIn: parent
          anchors.verticalCenterOffset: root.position === "bottom" ? 7
            : root.position === "top" ? -1 : 0
          width: root.iconSize
          height: root.iconSize
          radius: 12
          color: drawerHover.hovered ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
          scale: drawerButton.iconScale
          transformOrigin: root.position === "top" ? Item.Top
            : root.position === "left" ? Item.Left
            : root.position === "right" ? Item.Right : Item.Bottom

          Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
          Behavior on color { ColorAnimation { duration: 100 } }

          Image {
            anchors.centerIn: parent
            width: parent.width * 0.78
            height: parent.height * 0.78
            source: Qt.resolvedUrl("app-grid.svg")
            fillMode: Image.PreserveAspectFit
            asynchronous: true
          }
        }

        HoverHandler {
          id: drawerHover
          cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
          acceptedButtons: Qt.LeftButton
          onTapped: Quickshell.execDetached(["nwg-drawer"])
        }
      }
    }

    HoverHandler {
      id: pointer
    }
  }

  DockAppPicker {
    id: appPicker

    anchorItem: dockBackground
    position: root.position
    pinned: root.pinned
    onApplicationSelected: desktopId => root.pinRequested(desktopId)
  }

  HoverHandler {
    id: windowPointer
  }
}
