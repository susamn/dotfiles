import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import "Pipes.js" as Pipes

// Desktop-layer widgets, hosted by omarchy-shell as a keepLoaded "panel"
// plugin (no bar widget, no icon). Two click-through surfaces sit on the
// background layer of every screen:
//   - a clock card, top-left
//   - a themed "pipes" animation card, bottom-right
// Colours track the active Omarchy theme (colors.toml, re-read on switch).
Item {
  id: root

  // Injected by the shell host (see shell.qml panel loader).
  property var shell
  property string omarchyPath
  property var manifest

  // ---- tunables ---------------------------------------------------------
  readonly property int clockMarginTop: 44
  readonly property int clockMarginLeft: 28
  readonly property int pipesMarginBottom: 40
  readonly property int pipesMarginRight: 40
  readonly property int pipesSize: 230   // square
  readonly property real cardOpacity: 0.82
  // A blocky/mono face reads closest to the reference. Swap for a 7-segment
  // font (e.g. "DSEG7 Classic") if you install one.
  readonly property string clockFont: "CaskaydiaMono Nerd Font"

  // ---- live theme palette ------------------------------------------------
  // Foundational roles come straight from the shared qs.Commons Color
  // singleton, which omarchy-shell updates over IPC on every `omarchy theme
  // set …` (file-watching colors.toml is unreliable — the stock shell
  // doesn't do it either). The extended hues used for the pipes aren't on
  // that singleton, so those are parsed from colors.toml, re-read whenever a
  // Color property changes (i.e. the theme just switched — the file on disk
  // is already updated by then).
  QtObject {
    id: theme
    readonly property color background: Color.background
    readonly property color backgroundDark: Qt.darker(Color.background, 1.5)
    readonly property color foreground: Color.foreground
    readonly property color muted: Color.muted
    readonly property color accent: Color.accent
    property var pipeColors: [Color.accent]

    function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    function parsePalette(raw) {
      var map = ({})
      var lines = String(raw || "").split("\n")
      for (var i = 0; i < lines.length; i++) {
        var m = lines[i].match(/^\s*([A-Za-z0-9_]+)\s*=\s*["']?(#[0-9A-Fa-f]{6})/)
        if (m) map[m[1].toLowerCase()] = m[2]
      }
      var order = ["red", "orange", "yellow", "green", "cyan", "blue", "magenta",
                   "bright_red", "bright_green", "bright_cyan", "bright_blue", "bright_magenta"]
      var out = []
      for (var k = 0; k < order.length; k++)
        if (map[order[k]] && out.indexOf(map[order[k]]) === -1) out.push(map[order[k]])
      pipeColors = out.length ? out : [String(Color.accent)]
    }
  }

  FileView {
    id: colorsFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/colors.toml"
    watchChanges: true
    printErrors: false
    onLoaded: theme.parsePalette(text())
    onFileChanged: reload()
    onLoadFailed: theme.parsePalette("")
  }

  Connections {
    target: Color
    function onAccentChanged() { colorsFile.reload() }
    function onBackgroundChanged() { colorsFile.reload() }
    function onForegroundChanged() { colorsFile.reload() }
  }

  SystemClock {
    id: sysClock
    precision: SystemClock.Minutes
  }

  // ------------------------------------------------------------ clock card
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: clockWin
      required property var modelData
      screen: modelData

      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.namespace: "omarchy-desktop-widget"
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusiveZone: 0
      color: "transparent"
      mask: Region {} // empty -> fully click-through

      anchors { top: true; left: true }
      margins { top: root.clockMarginTop; left: root.clockMarginLeft }
      implicitWidth: card.implicitWidth
      implicitHeight: card.implicitHeight

      Rectangle {
        id: card
        implicitWidth: col.implicitWidth + 56
        implicitHeight: col.implicitHeight + 40
        radius: 18
        color: theme.withAlpha(theme.backgroundDark, root.cardOpacity)
        border.width: 1
        border.color: theme.withAlpha(theme.accent, 0.16)

        Column {
          id: col
          anchors.centerIn: parent
          spacing: 2

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(sysClock.date, "HH:mm")
            color: theme.foreground
            font.family: root.clockFont
            font.pixelSize: 64
            font.bold: true
            font.letterSpacing: 2
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(sysClock.date, "yyyy-MM-dd")
            color: theme.muted
            font.family: root.clockFont
            font.pixelSize: 14
            font.letterSpacing: 3
          }
        }
      }
    }
  }

  // ------------------------------------------------------------ pipes card
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: pipesWin
      required property var modelData
      screen: modelData

      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.namespace: "omarchy-desktop-widget"
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusiveZone: 0
      color: "transparent"
      mask: Region {}

      anchors { bottom: true; right: true }
      margins { bottom: root.pipesMarginBottom; right: root.pipesMarginRight }
      implicitWidth: root.pipesSize
      implicitHeight: root.pipesSize

      Rectangle {
        anchors.fill: parent
        radius: 18
        clip: true
        color: theme.withAlpha(theme.backgroundDark, root.cardOpacity)
        border.width: 1
        border.color: theme.withAlpha(theme.accent, 0.16)

        Item {
          id: field
          anchors.fill: parent
          anchors.margins: 12

          property var mgr: Pipes.createManager(function () { return theme.pipeColors })
          property var bodies: []   // committed geometry — rebuilt only on change
          property var heads: []    // moving leading segments — rebuilt every frame
          property real lastMs: Date.now()

          function toPoly(pairs) {
            var a = []
            for (var i = 0; i < pairs.length; i++) a.push(Qt.point(pairs[i][0], pairs[i][1]))
            return a
          }

          // committed pipe bodies
          Repeater {
            model: 16
            delegate: Item {
              id: bslot
              required property int index
              anchors.fill: parent
              readonly property var b: (field.bodies.length > index) ? field.bodies[index] : null
              readonly property var poly: b ? field.toPoly(b.pts) : []
              readonly property color base: b ? b.color : "transparent"
              visible: poly.length >= 2
              opacity: b ? Math.max(0, Math.min(1, b.opacity)) : 0

              PipeStroke { pts: bslot.poly; w: 2.5; col: bslot.base }
            }
          }

          // moving heads
          Repeater {
            model: 4
            delegate: Item {
              id: hslot
              required property int index
              anchors.fill: parent
              readonly property var hd: (field.heads.length > index) ? field.heads[index] : null
              readonly property var poly: hd ? field.toPoly(hd.pts) : []
              readonly property color base: hd ? hd.color : "transparent"
              visible: poly.length >= 2

              PipeStroke { pts: hslot.poly; w: 2.5; col: hslot.base }
            }
          }

          FrameAnimation {
            running: true
            onTriggered: {
              var now = Date.now()
              var dt = Math.min(0.05, (now - field.lastMs) / 1000)
              field.lastMs = now
              field.mgr.step(dt, field.width, field.height)
              if (field.mgr.structDirty) {
                field.bodies = field.mgr.bodyList(field.width, field.height)
                field.mgr.structDirty = false
              }
              field.heads = field.mgr.headList(field.width, field.height)
            }
          }
        }
      }
    }
  }
}
