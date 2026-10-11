import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "local.media"
  ipcTarget: "local.media"

  property string selectedName: ""

  readonly property var players: {
    var all = Mpris.players ? Mpris.players.values : []
    return all.filter(function(p) { return p && p.dbusName.indexOf("playerctld") === -1 && (p.trackTitle || p.trackArtist) })
  }
  readonly property var player: {
    for (var i = 0; i < players.length; i++) if (players[i].dbusName === selectedName) return players[i]
    for (var j = 0; j < players.length; j++) if (players[j].isPlaying) return players[j]
    return players.length > 0 ? players[0] : null
  }
  readonly property bool hasMedia: player !== null
  readonly property bool playing: player ? player.isPlaying : false
  readonly property string title: player ? (player.trackTitle || "") : ""
  readonly property string artist: player ? (player.trackArtist || "") : ""
  readonly property int maxChars: setting("maxChars", 32)
  readonly property bool canSeek: player ? (player.canSeek && player.positionSupported && player.length > 0) : false

  function run(action) {
    if (!player) return
    if (action === "previous" && player.canGoPrevious) player.previous()
    else if (action === "next" && player.canGoNext) player.next()
    else if (action === "playPause" && player.canTogglePlaying) player.togglePlaying()
  }

  function shortLabel() {
    var label = title + (artist ? " · " + artist : "")
    return label.length > maxChars ? label.slice(0, maxChars - 1) + "…" : label
  }

  function formatTime(seconds) {
    var s = Math.max(0, Math.floor(seconds || 0))
    var m = Math.floor(s / 60)
    s = s % 60
    return m + ":" + (s < 10 ? "0" : "") + s
  }

  onHasMediaChanged: if (!hasMedia) close()

  visible: hasMedia
  implicitWidth: hasMedia ? controls.implicitWidth : 0
  implicitHeight: hasMedia ? controls.implicitHeight : 0

  Timer {
    interval: 1000
    repeat: true
    running: root.opened && root.playing
    onTriggered: if (root.player) root.player.positionChanged()
  }

  Row {
    id: controls

    WidgetButton {
      id: prevButton
      bar: root.bar
      text: "󰒮"
      horizontalMargin: 5
      dimmed: !(root.player && root.player.canGoPrevious)
      onPressed: function(b) { root.run("previous") }
    }

    WidgetButton {
      bar: root.bar
      text: root.playing ? "󰏤" : "󰐊"
      horizontalMargin: 5
      onPressed: function(b) { root.run("playPause") }
    }

    WidgetButton {
      bar: root.bar
      text: "󰒭"
      horizontalMargin: 5
      dimmed: !(root.player && root.player.canGoNext)
      onPressed: function(b) { root.run("next") }
    }

    WidgetButton {
      id: titleButton
      bar: root.bar
      text: root.shortLabel()
      fontSize: 12
      horizontalMargin: 6
      tooltipText: root.title + (root.artist ? " · " + root.artist : "")
      onPressed: function(b) { root.toggle() }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: titleButton
    owner: root
    bar: root.bar
    open: root.opened && root.hasMedia
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
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
        spacing: Style.space(12)

        Row {
          width: parent.width
          spacing: Style.space(12)

          BorderSurface {
            id: cover
            width: Style.space(72)
            height: Style.space(72)
            radius: Style.spacing.labelGap
            color: Style.normalFillFor(root.bar.foreground, Color.accent)
            borderSpec: Border.controlSpec("normal", root.bar.foreground, Color.accent)

            Image {
              anchors.fill: parent
              anchors.margins: Style.space(2)
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              source: root.player && root.player.trackArtUrl ? root.player.trackArtUrl : ""
              visible: source !== ""
            }

            Text {
              anchors.centerIn: parent
              visible: !root.player || !root.player.trackArtUrl
              text: "󰝚"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.displayLarge
            }
          }

          Column {
            width: parent.width - cover.width - parent.spacing
            anchors.verticalCenter: cover.verticalCenter
            spacing: Style.space(3)

            Text {
              textFormat: Text.PlainText
              text: root.title
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.subtitle
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              textFormat: Text.PlainText
              text: root.artist
              color: Qt.darker(root.bar.foreground, 1.3)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
              width: parent.width
              visible: text !== ""
            }

            Text {
              textFormat: Text.PlainText
              text: root.player && root.player.trackAlbum ? root.player.trackAlbum : ""
              color: Qt.darker(root.bar.foreground, 1.6)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              width: parent.width
              visible: text !== ""
            }
          }
        }

        Column {
          width: parent.width
          spacing: Style.space(2)
          visible: root.player && root.player.lengthSupported && root.player.length > 0

          PanelSlider {
            id: seekSlider
            bar: root.bar
            width: parent.width
            minimum: 0
            maximum: root.player ? Math.max(1, root.player.length) : 1
            step: 5
            value: root.player ? root.player.position : 0
            enabled: root.canSeek
            onReleased: function(v) { if (root.canSeek) root.player.position = v }
          }

          Item {
            width: parent.width
            implicitHeight: elapsed.implicitHeight

            Text {
              id: elapsed
              textFormat: Text.PlainText
              text: root.formatTime(seekSlider.dragging ? seekSlider.liveValue : seekSlider.value)
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              anchors.left: parent.left
            }

            Text {
              textFormat: Text.PlainText
              text: root.formatTime(root.player ? root.player.length : 0)
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              anchors.right: parent.right
            }
          }
        }

        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(8)

          Button {
            iconText: "󰒮"
            foreground: root.bar.foreground
            iconSize: Style.font.iconLarge
            enabled: root.player && root.player.canGoPrevious
            opacity: enabled ? 1.0 : 0.4
            onClicked: root.run("previous")
          }

          Button {
            iconText: root.playing ? "󰏤" : "󰐊"
            foreground: root.bar.foreground
            iconSize: Style.font.iconLarge
            horizontalPadding: Style.spacing.panelGap
            onClicked: root.run("playPause")
          }

          Button {
            iconText: "󰒭"
            foreground: root.bar.foreground
            iconSize: Style.font.iconLarge
            enabled: root.player && root.player.canGoNext
            opacity: enabled ? 1.0 : 0.4
            onClicked: root.run("next")
          }
        }

        PanelSeparator {
          visible: root.players.length > 1
          foreground: root.bar.foreground
        }

        Column {
          width: parent.width
          spacing: Style.space(4)
          visible: root.players.length > 1

          Repeater {
            model: root.players

            Button {
              required property var modelData
              width: parent.width
              leftAlign: true
              text: (modelData.isPlaying ? "󰏤  " : "󰐊  ") + (modelData.trackTitle || modelData.identity || "Media source")
              fontSize: Style.font.bodySmall
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              active: root.player === modelData
              onClicked: root.selectedName = modelData.dbusName
            }
          }
        }
      }
    }
  }
}
