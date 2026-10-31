import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "local.drawer"
  ipcTarget: "local.drawer"

  readonly property string script: Quickshell.env("HOME") + "/.config/omarchy/plugins/local.drawer/drawer"
  readonly property var unmanaged: ["local.drawer", "local.tray", "omarchy.tray"]
  readonly property bool expanded: setting("expanded", true) === true
  property bool revealing: false
  property var slotRow: null
  property var rowHover: null
  readonly property bool hasHidden: hiddenIds.length > 0 || trayHiddenIds.length > 0
  readonly property var widgetIcons: ({
    "local.media": "󰝚",
    "omarchy.agents": "󰚩",
    "omarchy.bluetooth": "󰂯",
    "omarchy.network": "󰖩",
    "local.apps": "󰀻",
    "local.headset": "󰋎",
    "omarchy.audio": "󰕾",
    "omarchy.monitor": "󰍹",
    "local.hwstats": "󰘚",
    "omarchy.power": "󰁹"
  })
  readonly property var pinnedIds: settings.pinned instanceof Array ? settings.pinned : []
  readonly property var hiddenIds: settings.hidden instanceof Array ? settings.hidden : []
  readonly property var itemIds: {
    var ids = []
    var stored = settings.items instanceof Array ? settings.items : []
    var layout = bar && bar.layoutConfig && bar.layoutConfig.right instanceof Array ? bar.layoutConfig.right : []
    var all = stored.concat(layout)
    for (var i = 0; i < all.length; i++) {
      var id = typeof all[i] === "string" ? all[i] : String(all[i].id || "")
      if (id && ids.indexOf(id) === -1 && unmanaged.indexOf(id) === -1) ids.push(id)
    }
    return ids
  }

  property var trayPinnedIds: []
  property var trayHiddenIds: []
  readonly property var trayItems: {
    var values = SystemTray.items.values
    var result = []
    for (var i = 0; i < values.length; i++) {
      if (values[i].status !== Status.Passive) result.push(values[i])
    }
    return result
  }

  function readTrayState(raw) {
    var right = []
    try { right = JSON.parse(raw).bar.layout.right } catch (e) {}
    for (var i = 0; i < right.length; i++) {
      var entry = right[i]
      if (entry && (entry.id === "local.tray" || entry.id === "omarchy.tray")) {
        trayPinnedIds = entry.pinned instanceof Array ? entry.pinned : []
        trayHiddenIds = entry.hidden instanceof Array ? entry.hidden : []
        return
      }
    }
  }

  function trayName(item) {
    return String(item.title || "").trim() || String(item.tooltipTitle || "").trim() || String(item.id || "Unknown")
  }

  property var queue: []
  property bool layoutDirty: false

  function runScript(args) {
    queue = queue.concat([args])
    if (!scriptProc.running) runNext()
  }

  function runNext() {
    if (queue.length === 0) return
    scriptProc.command = [script].concat(queue[0])
    queue = queue.slice(1)
    scriptProc.running = true
  }

  function displayName(id) {
    var name = id.substring(id.lastIndexOf(".") + 1)
    return name.charAt(0).toUpperCase() + name.slice(1)
  }

  function widgetIcon(id) {
    return widgetIcons[id] || "󰜬"
  }

  function findRow() {
    var item = root.parent
    while (item && !("entry" in item && "region" in item && "moduleName" in item)) item = item.parent
    return item ? item.parent : null
  }

  function applyVisibility() {
    if (!slotRow) return
    var slots = slotRow.children
    for (var i = 0; i < slots.length; i++) {
      var slot = slots[i]
      if (!slot || !("entry" in slot) || !("moduleName" in slot)) continue
      var id = slot.moduleName
      if (unmanaged.indexOf(id) !== -1) {
        if (slot.activeItem && "revealHidden" in slot.activeItem) slot.activeItem.revealHidden = expanded && revealing
        continue
      }
      var show = hiddenIds.indexOf(id) !== -1
        ? expanded && revealing
        : expanded || pinnedIds.indexOf(id) !== -1
      if (slot.visible !== show) slot.visible = show
    }
  }

  function attachRow() {
    slotRow = findRow()
    if (!slotRow) return
    rowHover = Qt.createQmlObject("import QtQuick; HoverHandler {}", slotRow)
    rowHover.hoveredChanged.connect(function() { if (!rowHover.hovered) collapseCheck.restart() })
    applyVisibility()
  }

  function changeItem(action, id) {
    layoutDirty = true
    runScript([action, id])
  }

  onOpenedChanged: {
    if (opened || !layoutDirty) return
    layoutDirty = false
    runScript(["apply"])
  }

  onExpandedChanged: { if (!expanded) revealing = false; applyVisibility() }
  onRevealingChanged: applyVisibility()
  onPinnedIdsChanged: applyVisibility()
  onHiddenIdsChanged: applyVisibility()
  Component.onCompleted: Qt.callLater(attachRow)
  Component.onDestruction: if (rowHover) rowHover.destroy()

  Connections {
    target: root.slotRow
    function onChildrenChanged() { Qt.callLater(root.applyVisibility) }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    watchChanges: true
    onLoaded: root.readTrayState(text())
    onFileChanged: reload()
  }

  Timer {
    id: collapseCheck
    interval: 250
    onTriggered: {
      if ((root.rowHover && root.rowHover.hovered) || (root.bar && root.bar.activePopout)) return
      root.revealing = false
    }
  }

  Connections {
    target: root.bar
    function onActivePopoutChanged() { if (root.revealing && !root.bar.activePopout) collapseCheck.restart() }
  }

  Timer {
    id: hoverDelay
    interval: 200
    onTriggered: root.revealing = true
  }

  Process {
    id: scriptProc
    onExited: root.runNext()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.expanded ? "\uf054" : "\uf053"
    tooltipText: "Click to expand or collapse, right click to manage"
    fontSize: 12
    horizontalMargin: 7.5
    onPressed: function(b) {
      hoverDelay.stop()
      root.revealing = false
      if (b === Qt.RightButton) root.toggle()
      else root.runScript(["toggle"])
    }

    HoverHandler {
      onHoveredChanged: {
        if (hovered && root.expanded && !root.revealing && root.hasHidden) hoverDelay.restart()
        else hoverDelay.stop()
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(320))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(8)

        PanelSectionHeader {
          text: "BAR WIDGETS"
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
        }

        Text {
          textFormat: Text.PlainText
          text: "Pinned widgets stay visible. Hidden widgets never show. Changes apply when this closes."
          color: Qt.darker(root.bar.foreground, 1.4)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
          width: parent.width
        }

        Repeater {
          model: root.itemIds

          Item {
            id: row
            required property string modelData
            readonly property bool isPinned: root.pinnedIds.indexOf(modelData) !== -1
            readonly property bool isHidden: root.hiddenIds.indexOf(modelData) !== -1
            width: column.width
            implicitHeight: 28

            Text {
              id: widgetIconText
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              width: 18
              textFormat: Text.PlainText
              text: root.widgetIcon(row.modelData)
              color: row.isHidden ? Qt.darker(root.bar.foreground, 1.6) : root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            Text {
              anchors.left: widgetIconText.right
              anchors.leftMargin: Style.space(6)
              anchors.right: hideButton.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: root.displayName(row.modelData)
              color: row.isHidden ? Qt.darker(root.bar.foreground, 1.6) : root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
            }

            Button {
              id: pinButton
              anchors.verticalCenter: parent.verticalCenter
              anchors.right: parent.right
              iconText: ""
              text: row.isPinned ? "Unpin" : "Pin"
              foreground: root.bar.foreground
              horizontalPadding: 8
              verticalPadding: 3
              iconSize: Style.font.bodySmall
              fontSize: Style.font.bodySmall
              onClicked: root.changeItem("pin", row.modelData)
            }

            Button {
              id: hideButton
              anchors.verticalCenter: parent.verticalCenter
              anchors.right: pinButton.left
              anchors.rightMargin: Style.space(6)
              iconText: ""
              text: row.isHidden ? "Show" : "Hide"
              foreground: root.bar.foreground
              horizontalPadding: 8
              verticalPadding: 3
              iconSize: Style.font.bodySmall
              fontSize: Style.font.bodySmall
              onClicked: root.changeItem("hide", row.modelData)
            }
          }
        }

        PanelSectionHeader {
          visible: root.trayItems.length > 0
          text: "TRAY ICONS"
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
        }

        Repeater {
          model: root.trayItems

          Item {
            id: trayRow
            required property var modelData
            readonly property string itemId: String(modelData.id || "")
            readonly property bool isPinned: root.trayPinnedIds.indexOf(itemId) !== -1
            readonly property bool isHidden: root.trayHiddenIds.indexOf(itemId) !== -1
            width: column.width
            implicitHeight: 28

            Image {
              id: trayIconImage
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              width: 16
              height: 16
              fillMode: Image.PreserveAspectFit
              sourceSize.width: Math.round(16 * Screen.devicePixelRatio)
              sourceSize.height: Math.round(16 * Screen.devicePixelRatio)
              source: String(trayRow.modelData.icon || "")
              opacity: trayRow.isHidden ? 0.5 : 1
            }

            Text {
              anchors.left: trayIconImage.right
              anchors.leftMargin: Style.space(8)
              anchors.right: trayHideButton.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: root.trayName(trayRow.modelData)
              color: trayRow.isHidden ? Qt.darker(root.bar.foreground, 1.6) : root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
            }

            Button {
              id: trayPinButton
              anchors.verticalCenter: parent.verticalCenter
              anchors.right: parent.right
              iconText: "\uf08d"
              text: trayRow.isPinned ? "Unpin" : "Pin"
              foreground: root.bar.foreground
              horizontalPadding: 8
              verticalPadding: 3
              iconSize: Style.font.bodySmall
              fontSize: Style.font.bodySmall
              onClicked: root.runScript(["tray-pin", trayRow.itemId])
            }

            Button {
              id: trayHideButton
              anchors.verticalCenter: parent.verticalCenter
              anchors.right: trayPinButton.left
              anchors.rightMargin: Style.space(6)
              iconText: "\uf06e"
              text: trayRow.isHidden ? "Show" : "Hide"
              foreground: root.bar.foreground
              horizontalPadding: 8
              verticalPadding: 3
              iconSize: Style.font.bodySmall
              fontSize: Style.font.bodySmall
              onClicked: root.runScript(["tray-hide", trayRow.itemId])
            }
          }
        }
      }
    }
  }
}
