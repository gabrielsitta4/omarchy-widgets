import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "local.hwstats"
  ipcTarget: "local.hwstats"

  readonly property string script: Quickshell.env("HOME") + "/.config/omarchy/bar/scripts/hwstats"
  readonly property int historySize: 20
  readonly property color dimForeground: root.bar ? Qt.darker(root.bar.foreground, 1.4) : "transparent"

  readonly property string display: setting("display", "icons")
  readonly property var displayModes: [
    { label: "Icons", value: "icons" },
    { label: "Names", value: "names" }
  ]

  readonly property color warningColor: "#e5c07b"
  readonly property var barParts: {
    if (stats.cpu === undefined) return []
    var names = display === "names"
    return [
      { text: names ? "CPU " : "\uf4bc " },
      { text: stats.cpu + "%", value: stats.cpu, warning: 70, critical: 90 },
      { text: " " },
      { text: stats.cpuTemp + "°", value: stats.cpuTemp, warning: 75, critical: 85 },
      { text: names ? " / RAM " : " / \uefc5 " },
      { text: stats.memUsed + "G", value: 100 * stats.memUsed / stats.memTotal, warning: 70, critical: 90 },
      { text: names ? " / GPU " : " / 󰢮 " },
      { text: stats.gpuBusy + "%", value: stats.gpuBusy, warning: 70, critical: 90 },
      { text: " " },
      { text: stats.gpuTemp + "°", value: stats.gpuTemp, warning: 85, critical: 100 }
    ]
  }

  property var stats: ({})
  property var usageHistory: []
  readonly property var gpu: stats.gpu || ({})
  readonly property var igpu: stats.igpu || null

  function update(raw) {
    var next = null
    try { next = JSON.parse(String(raw || "")) } catch (e) {}
    if (!next) return
    stats = next
    usageHistory = usageHistory.concat([next.gpu.busy]).slice(-historySize)
  }

  function partColor(part) {
    if (part.value >= part.critical) return String(bar.urgent)
    if (part.value >= part.warning) return String(warningColor)
    return ""
  }

  function barMarkup() {
    return barParts.map(function(part) {
      var text = part.text.replace(/ /g, "\u00a0")
      var color = partColor(part)
      return color ? '<font color="' + color + '">' + text + "</font>" : text
    }).join("")
  }

  function setDisplay(value) {
    var next = Object.assign({}, settings)
    next.display = value
    if (bar && bar.shell) bar.shell.updateEntryInline(moduleName, next)
  }

  function fanText() {
    return gpu.fanRpm > 0 ? gpu.fanRpm + " RPM" : "Stopped (zero RPM)"
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Timer {
    interval: 3000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!statsProc.running) statsProc.running = true
  }

  Process {
    id: statsProc
    command: [root.script]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.update(text) }
  }

  component StatRow: Item {
    id: statRow
    property string label: ""
    property string value: ""
    width: column.width
    implicitHeight: valueText.implicitHeight

    Text {
      anchors.left: parent.left
      textFormat: Text.PlainText
      text: statRow.label
      color: root.dimForeground
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    Text {
      id: valueText
      anchors.right: parent.right
      textFormat: Text.PlainText
      text: statRow.value
      color: root.bar.foreground
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }

  component Meter: Item {
    id: meter
    property real fraction: 0
    width: column.width
    height: Style.space(6)

    Rectangle {
      anchors.fill: parent
      radius: height / 2
      color: root.bar.foreground
      opacity: 0.15
    }

    Rectangle {
      width: parent.width * Math.max(0, Math.min(1, meter.fraction))
      height: parent.height
      radius: height / 2
      color: root.bar.foreground
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.barParts.map(function(part) { return part.text }).join("")
    labelVisible: false
    tooltipText: root.stats.tooltip || ""
    fontSize: 12
    horizontalMargin: 3
    onPressed: function(b) { root.toggle() }

    Text {
      anchors.centerIn: parent
      anchors.verticalCenterOffset: 1
      textFormat: Text.StyledText
      text: root.barMarkup()
      color: button.foreground
      font.family: button.fontFamily
      font.pixelSize: button.fontSize
      renderType: Text.NativeRendering
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
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
          text: String(root.setting("gpuName", "GPU")).toUpperCase()
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
        }

        StatRow { label: "Usage"; value: (root.gpu.busy || 0) + "%" }

        Row {
          spacing: Style.space(2)
          height: Style.space(36)

          Repeater {
            model: root.historySize

            Item {
              required property int index
              readonly property int offset: root.historySize - root.usageHistory.length
              readonly property real sample: index >= offset ? root.usageHistory[index - offset] : 0
              width: (column.width - (root.historySize - 1) * Style.space(2)) / root.historySize
              height: parent.height

              Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: Math.max(1, parent.height * parent.sample / 100)
                color: root.bar.foreground
                opacity: parent.index >= parent.offset ? 1 : 0.15
              }
            }
          }
        }

        StatRow { label: "VRAM"; value: (root.gpu.vramUsed || 0) + " / " + (root.gpu.vramTotal || 0) + " GB" }
        Meter { fraction: root.gpu.vramTotal > 0 ? root.gpu.vramUsed / root.gpu.vramTotal : 0 }

        StatRow { label: "Temperature"; value: root.gpu.core + "° core, " + root.gpu.memory + "° memory, " + root.gpu.edge + "° edge" }

        StatRow { label: "Power"; value: (root.gpu.powerW || 0) + " / " + (root.gpu.capW || 0) + " W" }
        Meter { fraction: root.gpu.capW > 0 ? root.gpu.powerW / root.gpu.capW : 0 }

        StatRow { label: "Clock"; value: root.gpu.sclkMhz + " MHz, memory " + root.gpu.mclkMhz + " MHz" }
        StatRow { label: "Fan"; value: root.fanText() }

        PanelSectionHeader {
          visible: root.igpu !== null
          text: "INTEGRATED GPU"
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
        }

        StatRow {
          visible: root.igpu !== null
          label: "Usage"
          value: root.igpu ? root.igpu.busy + "%, " + root.igpu.temp + "°" : ""
        }

        StatRow {
          visible: root.igpu !== null
          label: "VRAM"
          value: root.igpu ? root.igpu.vramUsedMb + " / " + root.igpu.vramTotalMb + " MB" : ""
        }

        PanelSectionHeader {
          text: "DISPLAY"
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
        }

        Row {
          id: displayRow
          width: parent.width
          spacing: Style.space(6)

          readonly property real cellWidth: (width - spacing * (root.displayModes.length - 1)) / root.displayModes.length

          Repeater {
            model: root.displayModes
            Button {
              required property var modelData
              width: displayRow.cellWidth
              text: modelData.label
              fontSize: Style.font.bodySmall
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              horizontalPadding: Style.spacing.controlPaddingX
              verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
              bordered: true
              active: root.display === modelData.value
              onClicked: root.setDisplay(modelData.value)
            }
          }
        }

        Button {
          text: "Open btop"
          iconText: ""
          foreground: root.bar.foreground
          horizontalPadding: 8
          verticalPadding: 3
          iconSize: Style.font.bodySmall
          fontSize: Style.font.bodySmall
          onClicked: {
            root.close()
            Quickshell.execDetached(["omarchy", "launch", "or", "focus", "tui", "btop"])
          }
        }
      }
    }
  }
}
