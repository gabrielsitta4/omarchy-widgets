import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "local.headset"
  ipcTarget: "local.headset"

  readonly property string audioModule: "omarchy.audio"
  readonly property string scriptDir: Quickshell.env("HOME") + "/.config/omarchy/bar/scripts"
  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/headset"
  readonly property var sidetoneLevels: [
    { label: "Off", value: 0 },
    { label: "Low", value: 32 },
    { label: "Medium", value: 64 },
    { label: "High", value: 128 }
  ]

  property var battery: null
  property var audioPopup: null
  property var audioColumn: null
  property var section: null

  readonly property bool online: battery !== null
  readonly property bool charging: online && battery.status === "BATTERY_CHARGING"
  readonly property int level: online ? battery.level : -1
  readonly property int sidetone: parseInt(sidetoneFile.text())
  readonly property bool lightOn: lightFile.text().trim() !== "0"
  readonly property string batteryLabel: charging ? "󰋋 󱐋" : "󰋋 " + level + "%"

  readonly property bool injected: section !== null
  readonly property bool standalone: online && !injected
  readonly property bool headsetIsOutput: {
    var sink = Pipewire.defaultAudioSink
    return !!sink && String(sink.name).indexOf("G733") !== -1
  }
  readonly property bool batteryOnAudioButton: injected && online && headsetIsOutput
  readonly property var audioButton: audioPopup ? audioPopup.anchorItem : null

  function updateBattery(raw) {
    var next = null
    try { next = JSON.parse(String(raw || "").trim()) } catch (e) {}
    attachToAudioPanel()
    battery = next && typeof next.level === "number" ? next : null
  }

  function timeLeft() {
    var minutes = online ? battery.time_to_empty_min : undefined
    if (charging || typeof minutes !== "number" || minutes < 0) return "—"
    return Math.floor(minutes / 60) + "h " + (minutes % 60) + "m"
  }

  function setHeadset(key, value) {
    if (setProc.running) return
    setProc.command = [scriptDir + "/headset-set", key, String(value)]
    setProc.running = true
  }

  function findAudioPanel() {
    var item = root.parent
    while (item && !("entry" in item && "region" in item && "moduleName" in item)) item = item.parent
    var slots = item && item.parent ? item.parent.children : []
    for (var i = 0; i < slots.length; i++) {
      if (slots[i].moduleName === audioModule) return slots[i].activeItem || null
    }
    return null
  }

  function findPopup(panel) {
    var objects = panel ? panel.data : []
    for (var i = 0; i < objects.length; i++) {
      var object = objects[i]
      if (object && "anchorItem" in object && "focusTarget" in object && "fittedContentHeight" in object) return object
    }
    return null
  }

  function findColumn(popup) {
    var items = popup && popup.focusTarget ? popup.focusTarget.children : []
    for (var i = 0; i < items.length; i++) {
      var column = "contentChildren" in items[i] ? items[i].contentChildren[0] : null
      if (column && column.children.length > 1) return column
    }
    return null
  }

  function attachToAudioPanel() {
    if (section) return
    var popup = findPopup(findAudioPanel())
    var column = findColumn(popup)
    if (!column) return
    var created = sectionComponent.createObject(column)
    if (!created) return
    audioPopup = popup
    audioColumn = column
    section = created
  }

  onOnlineChanged: if (!online) close()
  Component.onDestruction: if (section) section.destroy()

  visible: standalone
  implicitWidth: standalone ? button.implicitWidth : 0
  implicitHeight: standalone ? button.implicitHeight : 0

  FileView {
    id: sidetoneFile
    path: root.stateDir + "/sidetone"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
  }

  FileView {
    id: lightFile
    path: root.stateDir + "/light"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
  }

  Process {
    id: batteryProc
    command: [root.scriptDir + "/headset-battery"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.updateBattery(text) }
  }

  Process {
    id: setProc
    onExited: {
      sidetoneFile.reload()
      lightFile.reload()
      pollTimer.restart()
    }
  }

  Timer {
    id: pollTimer
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!batteryProc.running && !setProc.running) batteryProc.running = true
  }

  Component { id: sectionComponent; HeadsetSection {} }
  Component { id: emptyIcon; Item {} }

  Binding { target: root.audioButton; when: root.batteryOnAudioButton; property: "text"; value: root.batteryLabel }
  Binding { target: root.audioButton; when: root.batteryOnAudioButton; property: "labelVisible"; value: true }
  Binding { target: root.audioButton; when: root.batteryOnAudioButton; property: "iconComponent"; value: emptyIcon }
  Binding { target: root.audioButton; when: root.batteryOnAudioButton; property: "fixedWidth"; value: -1 }
  Binding { target: root.audioButton; when: root.batteryOnAudioButton; property: "fontSize"; value: 12 }
  Binding { target: root.audioButton; when: root.batteryOnAudioButton; property: "horizontalMargin"; value: 7.5 }
  Binding {
    target: root.audioPopup
    when: root.injected
    property: "contentHeight"
    value: root.audioPopup && root.audioColumn ? root.audioPopup.fittedContentHeight(root.audioColumn.implicitHeight) : 0
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.batteryLabel
    fontSize: 12
    horizontalMargin: 7.5
    onPressed: function(b) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened && root.standalone
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      HeadsetSection {
        id: column
        anchors.top: parent.top
      }
    }
  }

  component HeadsetSection: Column {
    width: parent ? parent.width : 0
    spacing: Style.space(14)
    visible: root.online

    PanelSeparator {
      visible: root.injected
      foreground: root.bar.foreground
    }

    Item {
      width: parent.width
      implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, heroPercent.implicitHeight)

      Text {
        id: heroIcon
        textFormat: Text.PlainText
        text: "󰋋"
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.display
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
      }

      Column {
        id: heroLabels
        anchors.left: heroIcon.right
        anchors.leftMargin: Style.space(14)
        anchors.right: heroPercent.left
        anchors.rightMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(2)

        Text {
          textFormat: Text.PlainText
          text: "G733"
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
          elide: Text.ElideRight
          width: parent.width
        }

        Text {
          textFormat: Text.PlainText
          text: root.charging ? "CHARGING" : "TIME LEFT " + root.timeLeft().toUpperCase()
          color: Qt.darker(root.bar.foreground, 1.4)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 1.2
          elide: Text.ElideRight
          width: parent.width
        }
      }

      Text {
        id: heroPercent
        textFormat: Text.PlainText
        text: root.level >= 0 ? root.level + "%" : "—"
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.displayLarge
        font.bold: true
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    Item {
      width: parent.width
      implicitHeight: Style.space(8)

      Rectangle {
        id: barTrack
        anchors.fill: parent
        radius: height / 2
        color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.12)
      }

      Rectangle {
        anchors.left: barTrack.left
        anchors.verticalCenter: barTrack.verticalCenter
        height: barTrack.height
        radius: barTrack.radius
        color: root.bar.foreground
        width: Math.max(barTrack.height, barTrack.width * Math.max(0, root.level) / 100)
      }
    }

    PanelSeparator {
      foreground: root.bar.foreground
    }

    Column {
      width: parent.width
      spacing: Style.space(10)

      PanelSectionHeader {
        text: "SIDETONE"
        foreground: root.bar.foreground
        fontFamily: root.bar.fontFamily
      }

      Row {
        id: sidetoneRow
        width: parent.width
        spacing: Style.space(6)

        readonly property real cellWidth: (width - spacing * (root.sidetoneLevels.length - 1)) / root.sidetoneLevels.length

        Repeater {
          model: root.sidetoneLevels
          Button {
            required property var modelData
            width: sidetoneRow.cellWidth
            text: modelData.label
            fontSize: Style.font.bodySmall
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            horizontalPadding: Style.spacing.controlPaddingX
            verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
            bordered: true
            active: root.sidetone === modelData.value
            onClicked: root.setHeadset("sidetone", modelData.value)
          }
        }
      }
    }

    PanelSeparator {
      foreground: root.bar.foreground
    }

    Item {
      width: parent.width
      implicitHeight: lightSwitch.implicitHeight

      PanelSectionHeader {
        text: "LIGHTS"
        foreground: root.bar.foreground
        fontFamily: root.bar.fontFamily
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
      }

      ToggleSwitch {
        id: lightSwitch
        checked: root.lightOn
        foreground: root.bar.foreground
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        onToggled: root.setHeadset("light", root.lightOn ? 0 : 1)
      }
    }
  }
}
