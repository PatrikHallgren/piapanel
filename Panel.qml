import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// PIA bar widget: robot-head icon (bright when connected, dim when not),
// left click opens the panel, right click toggles the VPN, middle click
// refreshes. The panel holds a hero with an on/off switch, the current
// region, a search box, and the full region list.
Panel {
  id: root
  moduleName: "piavpn"
  ipcTarget: "piavpn"
  manageIpc: false

  readonly property Item panelFlick: panel.loadedContent ? panel.loadedContent.panelFlick : null
  readonly property Item regionList: panel.loadedContent ? panel.loadedContent.regionList : null
  readonly property Item regionSearch: panel.loadedContent ? panel.loadedContent.regionSearch : null

  property string focusSection: "header"
  property bool cursorActive: false
  property int regionIndex: 0
  property bool searchFocused: false
  property string regionQuery: ""

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color urgent: bar ? bar.urgent : Commons.Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color hoverFill: bar ? Style.hoverFillFor(bar.foreground, Commons.Color.accent) : "transparent"
  readonly property color selectedFill: bar ? Style.selectedFillFor(bar.foreground, Commons.Color.accent) : "transparent"

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  Service { id: pia }

  readonly property var stateLabel: ({
    connected: strings.t("panel.stateConnected"),
    disconnected: strings.t("panel.stateDisconnected"),
    connecting: strings.t("panel.stateConnecting"),
    reconnecting: strings.t("panel.stateReconnecting"),
    interrupted: strings.t("panel.stateInterrupted"),
    switching: strings.t("panel.stateSwitching"),
    disconnecting: strings.t("panel.stateDisconnecting"),
    unknown: strings.t("panel.stateUnknown")
  })
  readonly property string stateText: stateLabel[pia.stateKind] || strings.t("panel.stateUnknown")

  readonly property var regionEntry: Model.regionEntry(pia.region || "")
  readonly property bool regionIsAuto: pia.region === "auto"
  readonly property string regionTitle: pia.installed && pia.region !== ""
    ? (regionIsAuto ? strings.t("panel.regionAuto") : regionEntry.title)
    : "—"
  readonly property var filteredRegions: Model.filterRegions(pia.regions, regionQuery)

  // Text for the bar icon's tooltip: state plus selected region, sanitized.
  readonly property string tooltipText: {
    if (!pia.installed) return ""
    if (pia.stateKind === "unknown") return "PIA — " + strings.t("panel.stateUnknown")
    if (pia.transitioning) return "PIA — " + root.stateText + "…"
    var region = pia.region === "auto" || pia.region === ""
      ? strings.t("panel.regionAuto")
      : Model.cleanText(Model.regionEntry(pia.region).title)
    return "PIA — " + root.stateText + " · " + region
  }

  function regionsHeaderText() {
    var query = String(regionQuery || "").trim()
    if (query === "") return strings.t("panel.regions")
    return strings.t("panel.regionsFiltered")
      .arg(Commons.I18n.formatNumber(filteredRegions.length))
      .arg(Commons.I18n.formatNumber(pia.regions.length))
  }

  function chooseRegion(id) {
    if (!pia.installed) return
    pia.setRegion(id)
  }

  function ensureCursor() {
    if (regionIndex >= filteredRegions.length) regionIndex = Math.max(0, filteredRegions.length - 1)
  }

  function moveCursor(dx, dy) {
    if (dy === 0) return
    cursorActive = true
    if (focusSection === "header") {
      if (dy > 0 && filteredRegions.length > 0) { focusSection = "regions"; regionIndex = 0 }
    } else {
      if (regionIndex <= 0 && dy < 0) focusSection = "header"
      else regionIndex = Math.max(0, Math.min(filteredRegions.length - 1, regionIndex + dy))
    }
    scrollCursorIntoView()
  }

  function activateCursor() {
    if (focusSection === "header") {
      pia.toggleConnection()
      return
    }
    var index = Math.max(0, Math.min(regionIndex, filteredRegions.length - 1))
    var region = filteredRegions.length > 0 ? filteredRegions[index] : null
    if (region) chooseRegion(region.id)
  }

  function scrollCursorIntoView() {
    if (!regionList || filteredRegions.length === 0) return
    regionList.positionViewAtIndex(Math.max(0, Math.min(regionIndex, filteredRegions.length - 1)), ListView.Contain)
  }

  function refreshPanel() {
    pia.regionsWanted = true
    pia.refresh(true)
  }

  onOpenedChanged: if (opened) {
    cursorActive = false
    focusSection = "header"
    regionIndex = 0
    regionQuery = ""
    if (panelFlick) panelFlick.contentY = 0
    refreshPanel()
    Qt.callLater(function() { if (panel.loadedContent) panel.loadedContent.forceActiveFocus() })
  } else {
    // A query must not survive the panel: reopening to a silently filtered
    // list would look like regions missing.
    regionQuery = ""
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  ShellIpc {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function connect(): string { pia.toggleConnection(); return "ok" }
    function status(): string { return pia.installed ? pia.stateKind : "not-installed" }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: Component {
      Item {
        PiaIcon {
          x: (parent.width - width) / 2
          y: (parent.height - height) / 2
          iconSize: button.iconSize
          color: pia.active ? root.barForeground : Qt.darker(root.barForeground, 1.55)
          active: pia.active
        }
      }
    }
    // Hover tooltip: state plus selected region, sanitized for the shared
    // tooltip sink.
    tooltipText: pia.installed ? root.tooltipText : ""
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) pia.toggleConnection()
      else if (buttonCode === Qt.MiddleButton) refreshPanel()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight, Style.space(560))

    content: PanelKeyCatcher {
      id: keyCatcher
      property alias panelFlick: panelFlick
      property alias regionSearch: regionSearch
      property alias regionList: regionList
      implicitHeight: column.implicitHeight
      anchors.fill: parent
      blocked: root.searchFocused
      onMoveRequested: function(dx, dy) {
        if (root.searchFocused) return
        if (!root.cursorActive) { root.cursorActive = true; return }
        root.moveCursor(dx, dy)
      }
      onActivateRequested: if (root.cursorActive) root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "t" || t === "T") pia.toggleConnection()
        else if (t === "/" && regionSearch.visible) regionSearch.forceActiveFocus()
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          // -- hero ---------------------------------------------------------
          Item {
            id: header
            width: parent.width
            implicitHeight: hero.implicitHeight
            readonly property bool ringVisible: root.cursorActive && root.focusSection === "header"
            function focusHero() { root.cursorActive = true; root.focusSection = "header" }

            PanelHero {
              id: hero
              width: parent.width
              title: strings.t("panel.heroTitle")
              meta: root.stateText
              detail: pia.vpnIp !== "" ? strings.t("panel.detailVpnIp").arg(pia.vpnIp) : ""
              foreground: root.foreground
              fontFamily: root.fontFamily
              iconOpacity: pia.active ? 1.0 : 0.5
              iconComponent: Component {
                PiaIcon {
                  iconSize: Style.font.display
                  color: pia.active ? root.foreground : root.dim
                  active: pia.active
                }
              }

              trailingControl: Component {
                ToggleSwitch {
                  id: powerSwitch
                  visible: pia.installed
                  checked: pia.active
                  busy: pia.transitioning
                  hasCursor: header.ringVisible
                  foreground: hero.foreground
                  onHovered: function(on) { if (on) header.focusHero() }
                  onToggled: pia.toggleConnection()

                  PanelToolTip {
                    visible: powerSwitch.containsMouse
                    text: pia.active ? strings.t("panel.turnOff") : strings.t("panel.turnOn")
                    fontFamily: hero.fontFamily
                  }
                }
              }
            }
          }

          Text {
            visible: pia.actionStatus !== "" || pia.lastError !== ""
            width: parent.width
            textFormat: Text.PlainText
            text: pia.actionStatus !== "" ? pia.actionStatus : pia.lastError
            color: pia.lastError !== "" && pia.actionStatus === "" ? root.urgent : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          CursorSurface {
            visible: !pia.installed
            width: parent.width
            implicitHeight: missingText.implicitHeight + Style.spacing.rowPaddingX
            foreground: root.foreground

            Text {
              id: missingText
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.margins: Style.space(12)
              text: strings.t("panel.notInstalled")
              textFormat: Text.PlainText
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
            }
          }

          CursorSurface {
            visible: pia.installed && pia.stateKind === "unknown"
            width: parent.width
            implicitHeight: noResponseText.implicitHeight + Style.spacing.rowPaddingX
            foreground: root.foreground

            Text {
              id: noResponseText
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.margins: Style.space(12)
              text: strings.t("panel.noResponse")
              textFormat: Text.PlainText
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
            }
          }

          PanelSeparator { foreground: root.foreground }

          // -- current region ------------------------------------------------
          Column {
            visible: pia.installed
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: strings.t("panel.currentRegion")
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            CursorSurface {
              width: parent.width
              implicitHeight: currentRow.implicitHeight + Style.spacing.xl
              current: true
              foreground: root.foreground

              RowLayout {
                id: currentRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.space(6)
                anchors.rightMargin: Style.space(6)
                spacing: Style.space(8)

                Text {
                  text: "󰖂"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  Layout.alignment: Qt.AlignVCenter
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(1)

                  Text {
                    Layout.fillWidth: true
                    textFormat: Text.PlainText
                    text: root.regionTitle
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                    elide: Text.ElideRight
                  }

                  Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    textFormat: Text.PlainText
                    text: root.regionIsAuto ? "" : root.regionEntry.subtitle
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                  }
                }
              }
            }
          }

          PanelSeparator { visible: pia.installed; foreground: root.foreground }

          // -- region picker -------------------------------------------------
          Column {
            visible: pia.installed
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: root.regionsHeaderText()
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            TextField {
              id: regionSearch
              width: parent.width
              foreground: root.foreground
              placeholderText: strings.t("panel.searchRegions")
              onActiveFocusChanged: {
                root.searchFocused = activeFocus
                if (activeFocus) {
                  root.cursorActive = true
                  root.focusSection = "regions"
                }
              }
              onTextChanged: {
                root.regionQuery = text
                root.regionIndex = 0
              }
              onAccepted: root.activateCursor()
              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Down) {
                  root.moveCursor(0, 1)
                  event.accepted = true
                  return
                }
                if (event.key === Qt.Key_Up) {
                  root.moveCursor(0, -1)
                  event.accepted = true
                  return
                }
                if (event.key === Qt.Key_Escape) {
                  if (regionSearch.text !== "") regionSearch.text = ""
                  else keyCatcher.forceActiveFocus()
                  event.accepted = true
                }
              }
            }

            Text {
              visible: pia.installed && !pia.regionsLoaded && pia.regions.length === 0
              width: parent.width
              text: strings.t("panel.loadingRegions")
              textFormat: Text.PlainText
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              horizontalAlignment: Text.AlignHCenter
            }

            Text {
              visible: pia.regions.length > 0 && root.filteredRegions.length === 0
              width: parent.width
              text: strings.t("panel.noMatch")
              textFormat: Text.PlainText
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              horizontalAlignment: Text.AlignHCenter
            }

            // Virtualized region list, like the Tailscale machine list.
            ListView {
              id: regionList
              width: parent.width
              height: Math.min(contentHeight, Style.space(300))
              clip: true
              spacing: Style.space(6)
              model: root.filteredRegions
              reuseItems: true
              boundsBehavior: Flickable.StopAtBounds
              flickableDirection: Flickable.VerticalFlick
              interactive: contentHeight > height
              property real rememberedY: 0
              function rememberPosition() { rememberedY = contentY }
              onContentYChanged: if (moving || dragging) rememberedY = contentY
              onModelChanged: contentY = Math.max(0, Math.min(rememberedY, Math.max(0, contentHeight - height)))
              ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                onPressedChanged: if (!pressed) regionList.rememberPosition()
              }

              delegate: RegionRow {
                required property var modelData
                required property int index
                width: regionList.width
                region: modelData
                rowIndex: index
              }
            }
          }
        }
      }
    }
  }

  component RegionRow: CursorSurface {
    id: regionRow
    property var region: null
    property int rowIndex: 0
    readonly property bool isSelected: region && pia.region === region.id
    readonly property bool isAuto: region && region.isAuto === true
    readonly property string rowTitle: isAuto ? strings.t("panel.regionAuto") : (region ? region.title : "")
    readonly property string rowSubtitle: {
      if (isAuto || !region) return ""
      var text = region.subtitle
      if (region.streaming) text = text === "" ? strings.t("panel.streamingTag") : text + " · " + strings.t("panel.streamingTag")
      return text
    }

    hasCursor: root.cursorActive && root.focusSection === "regions" && root.regionIndex === rowIndex
    current: isSelected
    foreground: root.foreground
    fill: root.hoverFill
    currentFill: root.selectedFill

    implicitHeight: row.implicitHeight + Style.spacing.lg

    MouseArea {
      id: regionMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: {
        root.cursorActive = true
        root.focusSection = "regions"
        root.regionIndex = regionRow.rowIndex
      }
      onClicked: root.chooseRegion(regionRow.region.id)
    }

    Row {
      id: row
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(6)
      anchors.rightMargin: Style.space(6)
      spacing: Style.space(8)

      Text {
        text: regionRow.isAuto ? "󰖂" : (regionRow.isSelected ? "󰕥" : "󰖄")
        color: regionRow.isSelected || regionRow.isAuto ? root.foreground : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        width: Style.space(22)
        horizontalAlignment: Text.AlignHCenter
        anchors.verticalCenter: parent.verticalCenter
      }

      Column {
        width: parent.width - Style.space(30)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(1)

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: regionRow.rowTitle
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: regionRow.isSelected
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          visible: text !== ""
          textFormat: Text.PlainText
          text: regionRow.rowSubtitle
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }

    PanelToolTip {
      visible: regionMouse.containsMouse
      text: regionRow.isSelected
        ? strings.t("panel.currentRegion")
        : strings.t("panel.connectToRegion").arg(regionRow.rowTitle)
      fontFamily: root.fontFamily
    }
  }
}
