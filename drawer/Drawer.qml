import QtQuick
import Quickshell
import Quickshell.Bluetooth
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
  property bool revealing: false
  readonly property bool bluetoothConnected: Bluetooth.devices.values.some(function(device) { return device.connected })
  property var slotRow: null
  property var rowHover: null
  property var trayWidget: null
  property var rightSection: null
  property var centerContent: null
  readonly property real centerOverlap: {
    if (!centerContent) return 0
    var edge = 0
    var items = centerContent.children
    for (var i = 0; i < items.length; i++) {
      if ("region" in items[i] && items[i].visible) edge = Math.max(edge, items[i].x + items[i].width)
    }
    return Math.max(0, edge - rightSection.x)
  }
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
    "omarchy.power": "󰁹",
    "local.tray": "\uf0c9"
  })
  readonly property var hiddenIds: settings.hidden instanceof Array ? settings.hidden : []
  readonly property var itemIds: {
    var ids = []
    var stored = settings.items instanceof Array ? settings.items : []
    var layout = bar && bar.layoutConfig && bar.layoutConfig.right instanceof Array ? bar.layoutConfig.right : []
    var all = stored.concat(layout)
    for (var i = 0; i < all.length; i++) {
      var id = typeof all[i] === "string" ? all[i] : String(all[i].id || "")
      if (id && ids.indexOf(id) === -1 && id !== "local.drawer") ids.push(id)
    }
    return ids
  }

  property var trayHiddenIds: []
  property var trayOrderIds: []
  property var itemDraft: []
  property var trayDraft: []
  readonly property var itemRows: orderedIds(itemIds, itemDraft, hiddenIds)
  readonly property var trayItems: {
    var values = SystemTray.items.values
    var result = []
    for (var i = 0; i < values.length; i++) {
      if (values[i].status !== Status.Passive) result.push(values[i])
    }
    return result
  }

  readonly property var trayRowIds: orderedIds(
    trayItems.map(function(item) { return String(item.id || "") }),
    trayDraft.length > 0 ? trayDraft : trayOrderIds,
    trayHiddenIds)
  readonly property var trayRows: trayRowIds.map(function(id) {
    return trayItems.find(function(item) { return String(item.id || "") === id })
  })

  function orderedIds(ids, order, hidden) {
    var known = order.filter(function(id) { return ids.indexOf(id) !== -1 })
    var all = known.concat(ids.filter(function(id) { return known.indexOf(id) === -1 }))
    return all.filter(function(id) { return hidden.indexOf(id) !== -1 })
      .concat(all.filter(function(id) { return hidden.indexOf(id) === -1 }))
  }

  function canMove(rows, hidden, id, delta) {
    var target = rows.indexOf(id) + delta
    return target >= 0 && target < rows.length
      && (hidden.indexOf(rows[target]) !== -1) === (hidden.indexOf(id) !== -1)
  }

  function swapped(rows, id, delta) {
    var next = rows.slice()
    var index = next.indexOf(id)
    next[index] = next[index + delta]
    next[index + delta] = id
    return next
  }

  function moveItem(id, delta) {
    itemDraft = swapped(itemRows, id, delta)
    layoutDirty = true
  }

  function moveTrayItem(id, delta) {
    trayDraft = swapped(trayRowIds, id, delta)
  }

  function readTrayState(raw) {
    var right = []
    try { right = JSON.parse(raw).bar.layout.right } catch (e) {}
    for (var i = 0; i < right.length; i++) {
      var entry = right[i]
      if (entry && (entry.id === "local.tray" || entry.id === "omarchy.tray")) {
        trayHiddenIds = entry.hidden instanceof Array ? entry.hidden : []
        trayOrderIds = entry.order instanceof Array ? entry.order : []
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
        if (slot.activeItem && "itemDelegate" in slot.activeItem) trayWidget = slot.activeItem
        continue
      }
      var show = revealing || hiddenIds.indexOf(id) === -1 || (id === "omarchy.bluetooth" && bluetoothConnected)
      if (slot.visible !== show) slot.visible = show
    }
  }

  function attachCenter() {
    if (!bar || bar.vertical) return
    var sections = slotRow.parent.parent.children
    for (var i = 0; i < sections.length; i++) {
      if (!("hasAnchor" in sections[i])) continue
      rightSection = slotRow.parent
      centerContent = sections[i].children[0].item
      centerContent.transform = [centerShift]
      return
    }
  }

  function pointerOverIcons() {
    return rowHover.point.position.x >= root.mapToItem(slotRow, 0, 0).x
  }

  function updateReveal() {
    if (!rowHover.hovered) {
      revealDelay.stop()
      collapseCheck.restart()
    } else if (!pointerOverIcons()) {
      revealDelay.stop()
    } else if (!revealing && !revealDelay.running) {
      revealDelay.start()
    }
  }

  function attachRow() {
    slotRow = findRow()
    if (!slotRow) return
    rowHover = Qt.createQmlObject("import QtQuick; HoverHandler {}", slotRow)
    rowHover.hoveredChanged.connect(updateReveal)
    rowHover.pointChanged.connect(updateReveal)
    applyVisibility()
    attachCenter()
  }

  function changeItem(action, id) {
    layoutDirty = true
    runScript([action, id])
  }

  onOpenedChanged: {
    if (opened) return
    if (trayDraft.length > 0) runScript(["tray-order"].concat(trayDraft))
    trayDraft = []
    if (!layoutDirty) return
    layoutDirty = false
    runScript(["apply"].concat(itemDraft))
    itemDraft = []
  }

  onRevealingChanged: applyVisibility()
  onHiddenIdsChanged: applyVisibility()
  onBluetoothConnectedChanged: applyVisibility()
  Component.onCompleted: Qt.callLater(attachRow)
  Component.onDestruction: if (rowHover) rowHover.destroy()

  Connections {
    target: root.slotRow
    function onChildrenChanged() { Qt.callLater(root.applyVisibility) }
  }

  component MoveButton: Button {
    anchors.verticalCenter: parent.verticalCenter
    opacity: enabled ? 1 : 0.35
    horizontalPadding: 6
    verticalPadding: 3
    iconSize: Style.font.bodySmall
    fontSize: Style.font.bodySmall
  }

  component HiddenDivider: Rectangle {
    width: parent ? parent.width : 0
    height: 1
    y: -Style.space(4)
    opacity: 0.35
  }

  implicitWidth: button.width + hiddenTrayIcons.implicitWidth
  implicitHeight: button.implicitHeight

  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    watchChanges: true
    onLoaded: root.readTrayState(text())
    onFileChanged: reload()
  }

  Translate {
    id: centerShift
    x: -root.centerOverlap
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
    id: revealDelay
    interval: 200
    onTriggered: root.revealing = true
  }

  Process {
    id: scriptProc
    onExited: root.runNext()
  }

  WidgetButton {
    id: button
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: root.revealing ? implicitWidth : 0
    bar: root.bar
    text: "\uf013"
    tooltipText: "Bar widgets"
    concealed: !root.revealing
    fontSize: 12
    horizontalMargin: 7.5
    onPressed: root.toggle()
  }

  Row {
    id: hiddenTrayIcons
    anchors.left: button.right
    anchors.verticalCenter: parent.verticalCenter

    Repeater {
      model: root.revealing && root.trayWidget ? root.trayWidget.hiddenItems : []
      delegate: root.trayWidget ? root.trayWidget.itemDelegate : null
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
          text: "Use the arrows to set the order. Hidden items show while the mouse is over the icons on this side of the bar. Changes apply when this closes."
          color: Qt.darker(root.bar.foreground, 1.4)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
          width: parent.width
        }

        Repeater {
          model: root.itemRows

          Item {
            id: row
            required property string modelData
            required property int index
            readonly property bool isHidden: root.hiddenIds.indexOf(modelData) !== -1
            width: column.width
            implicitHeight: 28

            HiddenDivider {
              visible: !row.isHidden && row.index > 0 && root.hiddenIds.indexOf(root.itemRows[row.index - 1]) !== -1
              color: root.bar.foreground
            }

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
              id: hideButton
              visible: root.unmanaged.indexOf(row.modelData) === -1
              anchors.verticalCenter: parent.verticalCenter
              anchors.right: moveUpButton.left
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

            MoveButton {
              id: moveUpButton
              anchors.right: moveDownButton.left
              iconText: "\uf077"
              foreground: root.bar.foreground
              enabled: root.canMove(root.itemRows, root.hiddenIds, row.modelData, -1)
              onClicked: root.moveItem(row.modelData, -1)
            }

            MoveButton {
              id: moveDownButton
              anchors.right: parent.right
              iconText: "\uf078"
              foreground: root.bar.foreground
              enabled: root.canMove(root.itemRows, root.hiddenIds, row.modelData, 1)
              onClicked: root.moveItem(row.modelData, 1)
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
          model: root.trayRows

          Item {
            id: trayRow
            required property var modelData
            required property int index
            readonly property string itemId: String(modelData.id || "")
            readonly property bool isHidden: root.trayHiddenIds.indexOf(itemId) !== -1
            width: column.width
            implicitHeight: 28

            HiddenDivider {
              visible: !trayRow.isHidden && trayRow.index > 0 && root.trayHiddenIds.indexOf(root.trayRowIds[trayRow.index - 1]) !== -1
              color: root.bar.foreground
            }

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
              id: trayHideButton
              anchors.verticalCenter: parent.verticalCenter
              anchors.right: trayMoveUpButton.left
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

            MoveButton {
              id: trayMoveUpButton
              anchors.right: trayMoveDownButton.left
              iconText: "\uf077"
              foreground: root.bar.foreground
              enabled: root.canMove(root.trayRowIds, root.trayHiddenIds, trayRow.itemId, -1)
              onClicked: root.moveTrayItem(trayRow.itemId, -1)
            }

            MoveButton {
              id: trayMoveDownButton
              anchors.right: parent.right
              iconText: "\uf078"
              foreground: root.bar.foreground
              enabled: root.canMove(root.trayRowIds, root.trayHiddenIds, trayRow.itemId, 1)
              onClicked: root.moveTrayItem(trayRow.itemId, 1)
            }
          }
        }
      }
    }
  }
}
