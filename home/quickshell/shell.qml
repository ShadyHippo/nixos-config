// Game launcher menu (QuickShell default config → ~/.config/quickshell/shell.qml).
// @TOKEN@ placeholders are substituted from machine/theme.nix, images/*.svg and
// package paths in home/default.nix (the waybar @TOKEN@ pattern). Edit THERE,
// rebuild — HM overwrites the installed file. For live iteration, edit the
// installed ~/.config/quickshell/shell.qml directly (qs hot-reloads on save),
// then port the diff back into this file and rebuild.
//
// Sizes are budgeted for the 720p preset (1280×720) and scaled up on larger
// outputs via card.scale, so the menu never overflows when you launch games.
//
// Autostart: sway `exec qs -n` (starts hidden — shown: false).
// Toggle:    $mod+g → qs ipc call menu toggle   (also: open / hide / Esc /
//            controller Home). D-pad/stick move the selection, A activates,
//            B closes — dispatched in-process by the gamepad patch.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
  id: root
  property bool shown: false

  // Controller/keyboard selection: row 0 = launchers, row 1 = presets.
  property int selRow: 0
  property int selCol: 0

  readonly property var launchers: [
    { name: "RetroDECK", hint: "emulators",
      icon: "file://@ICON_RETRODECK@",
      cmd: ["@BIN_FLATPAK@", "run", "net.retrodeck.retrodeck"] },
    { name: "Moonlight", hint: "PC streaming",
      icon: "file://@ICON_MOONLIGHT@",
      cmd: ["@BIN_MOONLIGHT@"] },
    { name: "Steam", hint: "Big Picture",
      icon: "file://@ICON_STEAM@",
      cmd: ["@BIN_STEAM@", "steam://open/bigpicture"] },
  ]

  readonly property var presets: [
    { preset: "720",  label: "720p",  key: "$mod+F10" },
    { preset: "1080", label: "1080p", key: "$mod+F11" },
    { preset: "4k",   label: "4K",    key: "$mod+F12" },
  ]

  function resetSelection(): void { selRow = 0; selCol = 0 }
  function launchAt(index: int): void {
    Quickshell.execDetached(launchers[index].cmd)
    shown = false
  }
  function presetAt(index: int): void {
    Quickshell.execDetached(["@BIN_SH@", "@SET_RES@", presets[index].preset])
  }
  function activateSelection(): void {
    if (selRow === 0) launchAt(selCol)
    else presetAt(selCol)
  }

  // External control: $mod+g sway bind, controller Home (patched qs) and the
  // gamepad move*/activate/back dispatch below. Signature types are MANDATORY
  // — qs drops untyped handler functions (and a function named `show`
  // collides with the `qs ipc show` listing command, hence `open`).
  IpcHandler {
    target: "menu"
    function toggle(): void { root.shown = !root.shown }
    function open(): void { root.shown = true }
    function hide(): void { root.shown = false }
    function getShown(): bool { return root.shown }

    // Gamepad navigation (patch dispatches these). The guards keep in-game
    // controller input from touching a hidden menu.
    function moveUp(): void { if (root.shown) root.selRow = Math.max(0, root.selRow - 1) }
    function moveDown(): void { if (root.shown) root.selRow = Math.min(1, root.selRow + 1) }
    function moveLeft(): void { if (root.shown) root.selCol = Math.max(0, root.selCol - 1) }
    function moveRight(): void { if (root.shown) root.selCol = Math.min(root.launchers.length - 1, root.selCol + 1) }
    function activate(): void { if (root.shown) root.activateSelection() }
    function back(): void { root.shown = false }

    // Global desktop layer — no shown-guard: mod enforced by the patch.
    // Bumpers: prev/next existing workspace; triggers: prev/next CLEAN
    // workspace (1-10 scan — ws-clean.sh creates the empty slot).
    function workspacePrev(): void { Quickshell.execDetached(["@BIN_SWAYMSG@", "workspace", "prev"]) }
    function workspaceNext(): void { Quickshell.execDetached(["@BIN_SWAYMSG@", "workspace", "next"]) }
    function cleanPrev(): void { Quickshell.execDetached(["@BIN_SH@", "@WS_CLEAN@", "prev"]) }
    function cleanNext(): void { Quickshell.execDetached(["@BIN_SH@", "@WS_CLEAN@", "next"]) }
  }

  PanelWindow {
    id: win
    visible: root.shown

    // Fullscreen overlay. Overlay layer = above fullscreen games; 4 anchors
    // force the surface to screen size (both-opposite-anchors rule).
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    // Overlay must not reserve panel space for other shells.
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    onVisibleChanged: if (visible) {
      root.resetSelection()
      backdrop.forceActiveFocus()
    }

    // Siblings, not nested: backdrop first (dim + dismiss), card above it at
    // full opacity (a child of the 0.92-opacity backdrop would inherit it).
    Rectangle {
      id: backdrop
      anchors.fill: parent
      color: "@PAL_BG@"
      opacity: 0.92
      focus: true

      Keys.onEscapePressed: root.shown = false
      // Click outside the card = dismiss.
      MouseArea {
        anchors.fill: parent
        onClicked: root.shown = false
      }
    }

    Rectangle {
      id: card
      anchors.centerIn: parent
      width: grid.implicitWidth + 110
      height: grid.implicitHeight + 90
      radius: 24
      color: "@PAL_BGALT@"
      border.color: "@PAL_BGDIM@"
      border.width: 2
      // Fit-to-window, not a magic budget: QT_SCALE_FACTOR=1.5 means a 720p
      // output is only 853×480 *logical* px, and the card (≈1194px) overflowed
      // the old 0.8 scale floor. Derive scale from actual window/card sizes so
      // it always fits with 24px margins; cap growth at 2.2 for giant outputs.
      transformOrigin: Item.Center
      scale: (win.width > 0 && width > 0)
        ? Math.min(2.2, Math.min((win.width - 48) / width, (win.height - 48) / height))
        : 1

      // Swallow card-background clicks (else they fall through to dismiss).
      MouseArea { anchors.fill: parent }

      ColumnLayout {
        id: grid
        anchors.centerIn: parent
        spacing: 44

        // ── The three launchers ──
        RowLayout {
          spacing: 32

          Repeater {
            model: root.launchers

            delegate: Rectangle {
              required property int index
              required property var modelData

              Layout.preferredWidth: 340
              Layout.preferredHeight: 360
              radius: 16
              color: "@PAL_BG@"
              property bool focused: root.shown && root.selRow === 0 && root.selCol === index
              border.width: (tileMouse.containsMouse || focused) ? 3 : 1
              border.color: (tileMouse.containsMouse || focused) ? "@PAL_ACCENT@" : "@PAL_BGDIM@"

              ColumnLayout {
                anchors.centerIn: parent
                spacing: 20

                Image {
                  Layout.alignment: Qt.AlignHCenter
                  source: modelData.icon
                  sourceSize.width: 256
                  sourceSize.height: 256
                  Layout.preferredWidth: 130
                  Layout.preferredHeight: 130
                }
                Text {
                  Layout.alignment: Qt.AlignHCenter
                  text: modelData.name
                  color: "@PAL_FG@"
                  font { family: "@FONT@"; pixelSize: 30; bold: true }
                }
                Text {
                  Layout.alignment: Qt.AlignHCenter
                  text: modelData.hint
                  color: "@PAL_FGDIM@"
                  font { family: "@FONT@"; pixelSize: 18 }
                }
              }

              MouseArea {
                id: tileMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: { root.selRow = 0; root.selCol = index }
                onClicked: root.launchAt(index)
              }
            }
          }
        }

        // ── Resolution presets ($mod+F10/11/12 twins — menu stays open so
        //    you can hop between presets) ──
        ColumnLayout {
          Layout.alignment: Qt.AlignHCenter
          spacing: 16

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: "RESOLUTION PRESETS"
            color: "@PAL_FGDIM@"
            font { family: "@FONT@"; pixelSize: 18; bold: true }
          }

          RowLayout {
            spacing: 20

            Repeater {
              model: root.presets

              delegate: Rectangle {
                required property int index
                required property var modelData

                Layout.preferredWidth: 280
                Layout.preferredHeight: 100
                radius: 12
                color: "@PAL_BG@"
                property bool focused: root.shown && root.selRow === 1 && root.selCol === index
                border.width: (resMouse.containsMouse || focused) ? 3 : 1
                border.color: (resMouse.containsMouse || focused) ? "@PAL_ACCENT@" : "@PAL_BGDIM@"

                ColumnLayout {
                  anchors.centerIn: parent
                  spacing: 2

                  Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: modelData.label
                    color: "@PAL_FG@"
                    font { family: "@FONT@"; pixelSize: 26; bold: true }
                  }
                  Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: modelData.key
                    color: "@PAL_FGDIM@"
                    font { family: "@FONT@"; pixelSize: 15 }
                  }
                }

                MouseArea {
                  id: resMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onEntered: { root.selRow = 1; root.selCol = index }
                  onClicked: root.presetAt(index)
                }
              }
            }
          }
        }
      }
    }
  }
}
