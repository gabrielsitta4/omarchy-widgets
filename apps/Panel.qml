import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "local.apps"
  ipcTarget: "local.apps"

  readonly property string forceKill: Quickshell.env("HOME") + "/.local/bin/force-kill"

  property var windows: []

  function updateWindows(raw) {
    var clients = []
    try { clients = JSON.parse(String(raw || "[]")) } catch (e) {}
    var seen = {}
    var next = []
    for (var i = 0; i < clients.length; i++) {
      var c = clients[i]
      if (!c.mapped || c.pid <= 0 || seen[c.pid]) continue
      seen[c.pid] = true
      next.push({ pid: c.pid, appClass: c["class"] || "", title: c.title || "" })
    }
    next.sort(function(a, b) { return a.appClass.localeCompare(b.appClass) })
    windows = next
  }

  function iconFor(appClass) {
    var entry = DesktopEntries.heuristicLookup(appClass)
    var path = Quickshell.iconPath(entry && entry.icon ? entry.icon : appClass, true)
    return path.length > 0 ? path : Quickshell.iconPath("application-x-executable", true)
  }

  function refresh() {
    if (!listProc.running) listProc.running = true
  }

  function kill(pid) {
    killProc.command = [forceKill, String(pid)]
    killProc.running = true
  }

  onOpenedChanged: if (opened) refresh()

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: listProc
    command: ["hyprctl", "clients", "-j"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.updateWindows(text) }
  }

  Process {
    id: killProc
    onExited: refreshDelay.restart()
  }

  Timer {
    id: refreshDelay
    interval: 400
    onTriggered: root.refresh()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰀻"
    fontSize: 12
    horizontalMargin: 7.5
    onPressed: function(b) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
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
        spacing: Style.space(10)

        PanelSectionHeader {
          text: "OPEN APPS"
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
        }

        Text {
          visible: root.windows.length === 0
          textFormat: Text.PlainText
          text: "No open windows"
          color: Qt.darker(root.bar.foreground, 1.4)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        Repeater {
          model: root.windows

          Item {
            required property var modelData
            width: column.width
            implicitHeight: Math.max(appIcon.height, labels.implicitHeight, killButton.implicitHeight)

            Image {
              id: appIcon
              width: Style.font.iconLarge
              height: Style.font.iconLarge
              fillMode: Image.PreserveAspectFit
              sourceSize.width: width * Screen.devicePixelRatio
              sourceSize.height: height * Screen.devicePixelRatio
              source: root.iconFor(modelData.appClass)
              asynchronous: true
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Column {
              id: labels
              anchors.left: appIcon.right
              anchors.leftMargin: Style.space(10)
              anchors.right: killButton.left
              anchors.rightMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter

              Text {
                textFormat: Text.PlainText
                text: modelData.appClass
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                elide: Text.ElideRight
                width: parent.width
              }

              Text {
                textFormat: Text.PlainText
                text: modelData.title
                color: Qt.darker(root.bar.foreground, 1.4)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
                width: parent.width
              }
            }

            PanelActionButton {
              id: killButton
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              iconText: "󰅙"
              tooltipText: "Force kill"
              foreground: root.bar.foreground
              hoverColor: root.bar.urgent
              fontFamily: root.bar.fontFamily
              onClicked: root.kill(modelData.pid)
            }
          }
        }
      }
    }
  }
}
