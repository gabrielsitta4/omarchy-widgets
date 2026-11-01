import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
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
  property var itemDraft: []
  readonly property var trayItems: trayWidget ? trayWidget.allItems : []
  readonly property var trayIds: trayItems.map(function(item) { return String(item.id || "") })
  readonly property var allHiddenIds: hiddenIds.concat(trayHiddenIds)
  readonly property var orderIds: {
    var hiddenTray = trayIds.filter(function(id) { return trayHiddenIds.indexOf(id) !== -1 })
    var shownTray = trayIds.filter(function(id) { return trayHiddenIds.indexOf(id) === -1 })
    var base = hiddenTray.concat(itemIds)
    var marker = base.findIndex(function(id) { return unmanaged.indexOf(id) !== -1 })
    base.splice.apply(base, [marker + 1, 0].concat(shownTray))
    var stored = settings.order instanceof Array ? settings.order : []
    var merged = mergedOrder(base, itemDraft.length > 0 ? itemDraft : stored)
    return orderedIds(merged, merged, allHiddenIds)
  }
  readonly property var panelIds: orderIds.filter(function(id) { return unmanaged.indexOf(id) === -1 })
  readonly property var panelRows: panelIds.map(function(id) {
    var index = trayIds.indexOf(id)
    return { id: id, trayItem: index === -1 ? null : trayItems[index], hidden: allHiddenIds.indexOf(id) !== -1 }
  })

  function mergedOrder(base, stored) {
    var result = stored.filter(function(id) { return base.indexOf(id) !== -1 })
    for (var i = base.length - 1; i >= 0; i--) {
      if (result.indexOf(base[i]) !== -1) continue
      var next = i + 1 < base.length ? result.indexOf(base[i + 1]) : -1
      result.splice(next === -1 ? result.length : next, 0, base[i])
    }
    return result
  }

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

  function moveRow(id, delta) {
    var other = panelIds[panelIds.indexOf(id) + delta]
    var next = orderIds.slice()
    next[orderIds.indexOf(id)] = other
    next[orderIds.indexOf(other)] = id
    itemDraft = next
    layoutDirty = true
  }

  function toggleRow(entry) {
    if (entry.hidden) {
      var next = orderIds.filter(function(id) { return id !== entry.id })
      var marker = next.findIndex(function(id) { return unmanaged.indexOf(id) !== -1 })
      next.splice(marker + 1, 0, entry.id)
      itemDraft = next
    }
    layoutDirty = true
    runScript([entry.trayItem ? "tray-hide" : "hide", entry.id])
  }

  function readTrayState(raw) {
    var right = []
    try { right = JSON.parse(raw).bar.layout.right } catch (e) {}
    for (var i = 0; i < right.length; i++) {
      var entry = right[i]
      if (entry && (entry.id === "local.tray" || entry.id === "omarchy.tray")) {
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
        if (slot.activeItem && "itemDelegate" in slot.activeItem) {
          trayWidget = slot.activeItem
          trayWidget.iconsDetached = true
        }
        continue
      }
      var show = revealing || hiddenIds.indexOf(id) === -1 || (id === "omarchy.bluetooth" && bluetoothConnected)
      if (slot.visible !== show) slot.visible = show
    }
    placeTrayIcons()
  }

  function placeTrayIcons() {
    var items = {}
    var slots = slotRow.children
    for (var i = 0; i < slots.length; i++) {
      if ("entry" in slots[i] && "moduleName" in slots[i]) items[slots[i].moduleName] = slots[i]
    }
    var icons = {}
    for (var j = 0; j < trayIcons.count; j++) {
      var icon = trayIcons.itemAt(j)
      if (!icon) continue
      var iconId = String(icon.modelData.id || "")
      icons[iconId] = icon
      icon.visible = revealing || trayHiddenIds.indexOf(iconId) === -1
    }
    var hidden = orderIds.filter(function(id) { return allHiddenIds.indexOf(id) !== -1 })
    var shown = orderIds.filter(function(id) { return allHiddenIds.indexOf(id) === -1 })
    var split = Math.max(0, shown.findIndex(function(id) { return unmanaged.indexOf(id) !== -1 }))
    var sequence = shown.slice(0, split).concat(["local.drawer"], hidden, shown.slice(split))
    var wanted = sequence.map(function(id) { return icons[id] || items[id] }).filter(function(item) { return item })
    var current = Array.from(slots).filter(function(item) { return wanted.indexOf(item) !== -1 })
    if (current.every(function(item, index) { return item === wanted[index] })) return
    var holder = slotRow.parent
    wanted.forEach(function(item) {
      item.parent = holder
      item.parent = slotRow
    })
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

  onOpenedChanged: {
    if (opened || !layoutDirty) return
    layoutDirty = false
    runScript(["apply"].concat(orderIds))
  }

  onRevealingChanged: applyVisibility()
  onHiddenIdsChanged: applyVisibility()
  onOrderIdsChanged: Qt.callLater(applyVisibility)
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

  implicitWidth: button.width
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

  Repeater {
    id: trayIcons
    parent: root.slotRow
    model: root.slotRow ? root.trayItems : []
    delegate: root.trayWidget ? root.trayWidget.itemDelegate : null
    onItemAdded: function(index, item) {
      item.height = root.bar.barSize
      Qt.callLater(root.applyVisibility)
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
          model: root.panelRows

          Item {
            id: row
            required property var modelData
            required property int index
            readonly property bool isTray: modelData.trayItem !== null
            readonly property bool isHidden: modelData.hidden
            width: column.width
            implicitHeight: 28

            HiddenDivider {
              visible: !row.isHidden && row.index > 0 && root.panelRows[row.index - 1].hidden
              color: root.bar.foreground
            }

            Text {
              id: widgetIconText
              visible: !row.isTray
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              width: 18
              textFormat: Text.PlainText
              text: root.widgetIcon(row.modelData.id)
              color: row.isHidden ? Qt.darker(root.bar.foreground, 1.6) : root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            Image {
              visible: row.isTray
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              width: 16
              height: 16
              fillMode: Image.PreserveAspectFit
              sourceSize.width: Math.round(16 * Screen.devicePixelRatio)
              sourceSize.height: Math.round(16 * Screen.devicePixelRatio)
              source: row.isTray ? String(row.modelData.trayItem.icon || "") : ""
              opacity: row.isHidden ? 0.5 : 1
            }

            Text {
              anchors.left: widgetIconText.right
              anchors.leftMargin: Style.space(6)
              anchors.right: hideButton.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: row.isTray ? root.trayName(row.modelData.trayItem) : root.displayName(row.modelData.id)
              color: row.isHidden ? Qt.darker(root.bar.foreground, 1.6) : root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
            }

            Button {
              id: hideButton
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
              onClicked: root.toggleRow(row.modelData)
            }

            MoveButton {
              id: moveUpButton
              anchors.right: moveDownButton.left
              iconText: "\uf077"
              foreground: root.bar.foreground
              enabled: root.canMove(root.panelIds, root.allHiddenIds, row.modelData.id, -1)
              onClicked: root.moveRow(row.modelData.id, -1)
            }

            MoveButton {
              id: moveDownButton
              anchors.right: parent.right
              iconText: "\uf078"
              foreground: root.bar.foreground
              enabled: root.canMove(root.panelIds, root.allHiddenIds, row.modelData.id, 1)
              onClicked: root.moveRow(row.modelData.id, 1)
            }
          }
        }
      }
    }
  }
}
