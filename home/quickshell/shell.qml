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
//            X focuses the selected window, B closes — dispatched in-process
//            by the gamepad patch. The menu lists windows on the focused
//            workspace (ws-list.sh scan, refreshed while open).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
  id: root
  property bool shown: false

  // Controller/keyboard selection: sections = launchers / windows / presets.
  property int selSection: 0
  property int selIndex: 0
  // Windows on the focused workspace: [{id, title, app}], ws-list.sh scan.
  property var winList: []

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

  function resetSelection(): void { selSection = 0; selIndex = 0 }
  function sectionLength(section: int): int {
    if (section === 0) return launchers.length
    if (section === 1) return winList.length
    return presets.length
  }
  function launchAt(index: int): void {
    Quickshell.execDetached(launchers[index].cmd)
    shown = false
  }
  function presetAt(index: int): void {
    Quickshell.execDetached(["@BIN_SH@", "@SET_RES@", presets[index].preset])
  }
  function closeWindow(index: int): void {
    Quickshell.execDetached(["@BIN_SWAYMSG@", "[con_id=" + winList[index].id + "] kill"])
  }
  function focusSelection(): void {
    if (selSection !== 1 || selIndex >= winList.length) return
    Quickshell.execDetached(["@BIN_SWAYMSG@", "[con_id=" + winList[selIndex].id + "] focus"])
  }
  function activateSelection(): void {
    if (selSection === 0) launchAt(selIndex)
    else if (selSection === 1 && selIndex < winList.length) closeWindow(selIndex)
    else if (selSection === 2) presetAt(selIndex)
  }
  function moveSection(dir: int): void {
    let section = selSection + dir
    while (section >= 0 && section <= 2) {
      if (sectionLength(section) > 0) {
        selSection = section
        selIndex = Math.min(selIndex, sectionLength(section) - 1)
        return
      }
      section += dir
    }
  }
  function moveItem(dir: int): void {
    const length = sectionLength(selSection)
    if (length === 0) return
    selIndex = Math.max(0, Math.min(length - 1, selIndex + dir))
  }

  // Window list for the focused workspace. The scan lives in ws-list.sh:
  // get_workspaces identifies the workspace (stable while this menu holds
  // keyboard focus — get_tree's focused con vanishes under the grab, which
  // emptied the section ~1s after opening in the first implementation).
  function parseTree(text: string): void {
    try {
      winList = JSON.parse(text)
      selIndex = Math.min(selIndex, Math.max(0, sectionLength(selSection) - 1))
    } catch (error) {
      console.warn("window scan failed:", error)
    }
  }

  Process {
    id: winScan
    command: ["@BIN_SH@", "@WS_LIST@"]
    stdout: StdioCollector {
      id: scanOut
      onStreamFinished: root.parseTree(scanOut.text)
    }
  }

  function scanWindows(): void {
    winScan.running = false
    winScan.running = true
  }

  // Rescan every second while visible: games spawn/close behind the menu.
  Timer {
    interval: 1000
    repeat: true
    running: root.shown
    onTriggered: root.scanWindows()
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
    function moveUp(): void { if (root.shown) root.moveSection(-1) }
    function moveDown(): void { if (root.shown) root.moveSection(1) }
    function moveLeft(): void { if (root.shown) root.moveItem(-1) }
    function moveRight(): void { if (root.shown) root.moveItem(1) }
    function activate(): void { if (root.shown) root.activateSelection() }
    function focusWindow(): void { if (root.shown) root.focusSelection() }
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
      root.scanWindows()
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
          id: launchersRow
          Layout.alignment: Qt.AlignHCenter
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
              property bool focused: root.shown && root.selSection === 0 && root.selIndex === index
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
                onEntered: { root.selSection = 0; root.selIndex = index }
                onClicked: root.launchAt(index)
              }
            }
          }
        }

        // ── Windows on the focused workspace (A = close, X = focus) ──
        ColumnLayout {
          visible: root.winList.length > 0
          Layout.alignment: Qt.AlignHCenter
          spacing: 16

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: "ON THIS DESKTOP (" + root.winList.length + ")"
            color: "@PAL_FGDIM@"
            font { family: "@FONT@"; pixelSize: 18; bold: true }
          }

          RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 20

            Repeater {
              model: root.winList

              delegate: Rectangle {
                id: chip
                required property int index
                required property var modelData

                // Never outgrow the launcher row: chips shrink as the count
                // rises, so the card width (and menu scale) stay put.
                Layout.preferredWidth: Math.min(300, (launchersRow.implicitWidth - 20 * (root.winList.length - 1)) / root.winList.length)
                Layout.preferredHeight: 110
                radius: 12
                color: "@PAL_BG@"
                property bool focused: root.shown && root.selSection === 1 && root.selIndex === index
                border.width: (winMouse.containsMouse || focused) ? 3 : 1
                border.color: (winMouse.containsMouse || focused) ? "@PAL_ACCENT@" : "@PAL_BGDIM@"

                ColumnLayout {
                  anchors.centerIn: parent
                  spacing: 4

                  Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: chip.width - 36
                    text: modelData.title
                    color: "@PAL_FG@"
                    font { family: "@FONT@"; pixelSize: 18; bold: true }
                    elide: Text.ElideMiddle
                    horizontalAlignment: Text.AlignHCenter
                  }
                  Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: chip.width - 36
                    text: modelData.app
                    color: "@PAL_FGDIM@"
                    font { family: "@FONT@"; pixelSize: 14 }
                    elide: Text.ElideMiddle
                    horizontalAlignment: Text.AlignHCenter
                  }
                }

                MouseArea {
                  id: winMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onEntered: { root.selSection = 1; root.selIndex = index }
                  onClicked: root.closeWindow(index)
                }
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
                property bool focused: root.shown && root.selSection === 2 && root.selIndex === index
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
                  onEntered: { root.selSection = 2; root.selIndex = index }
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
