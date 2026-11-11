import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "../core"
import "../ui"

// A tray icon's menu (right click on it in the bar), drawn by Monolith instead of the app's
// plain toolkit menu: a card dropping out of the bar like the sound and notification ones, with
// the app's entries as rows (their icons, check marks and radio dots, greyed out when disabled,
// separators as thin lines). A submenu opens in place, with a back row on top. A click on an
// entry runs it and puts the menu away; a click anywhere else or Esc puts it away too.
PanelWindow {
    id: dd
    required property var modelData
    screen: modelData
    readonly property bool shown: HubState.dropScreen === modelData.name && HubState.dropKind === "tray" && !HubState.open && !!HubState.trayItem

    // the submenus you went into, deepest last; the menu shown is the last one (or the app's own)
    property var trail: []
    Connections { target: HubState; function onTrayItemChanged() { dd.trail = []; } }
    onShownChanged: { if (shown) { trail = []; keys.forceActiveFocus(); } }

    // every level stays open while you're inside it: let go of the app's menu and its entries
    // (the submenu you went into among them) are gone, and the submenu shows up empty
    QsMenuOpener { id: rootOpener; menu: HubState.trayItem ? HubState.trayItem.menu : null }
    Instantiator {
        id: levels
        model: dd.trail
        delegate: QsMenuOpener { required property var modelData; menu: modelData }
    }
    readonly property var opener: trail.length > 0 && levels.count === trail.length ? levels.objectAt(trail.length - 1) : rootOpener
    readonly property var entries: opener && opener.children ? opener.children.values : []

    visible: shown || card.opacity > 0.01
    WlrLayershell.namespace: "monolith-traymenu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    // open, the whole screen takes the mouse: a click off the card closes it
    mask: Region { item: dd.shown ? full : null }
    Item { id: full; anchors.fill: parent }

    MouseArea { anchors.fill: parent; onClicked: HubState.closeDrop() }
    Item {
        id: keys
        focus: true
        Keys.onEscapePressed: { if (dd.trail.length > 0) dd.trail = dd.trail.slice(0, -1); else HubState.closeDrop(); }
    }

    readonly property real rowH: 36
    Rectangle {
        id: card
        // as wide as its longest entry needs, within reason
        width: Math.round(Math.max(220, Math.min(420, col.wantW + 16)))
        height: Math.min(dd.height - 80, col.implicitHeight + 16)
        Behavior on height { NumberAnimation { duration: Theme.shortMs; easing.type: Easing.OutCubic } }
        readonly property point at: Theme.dropPos(HubState.dropX, HubState.dropY, width, height, dd.width, dd.height)
        x: at.x
        y: at.y
        radius: Theme.corner(80, 14)
        color: Theme.frame
        border.width: Theme.outlineW; border.color: Theme.outlineColor
        // (no clip here: it would cut the shadow square round the rounded corners; the list
        // clips itself)
        opacity: dd.shown ? 1 : 0
        scale: dd.shown ? 1 : Theme.popScale
        transformOrigin: Theme.dropOrigin
        Behavior on opacity { NumberAnimation { duration: dd.shown ? Theme.popInMs : Theme.popOutMs; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: dd.shown ? Theme.popInMs : Theme.popOutMs; easing.type: Easing.BezierSpline; easing.bezierCurve: dd.shown ? Theme.enterCurve : Theme.exitCurve } }
        CardShadow {}
        MouseArea { anchors.fill: parent }

        Flickable {
            id: scroller
            SmoothWheel {}
            x: 8; y: 8
            width: card.width - 16
            height: card.height - 16
            contentHeight: col.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            Column {
                id: col
                width: scroller.width
                spacing: 2
                // the widest row's text, for the card's width
                property real wantW: 0
                function measure() {
                    let w = 0;
                    for (let i = 0; i < children.length; i++) if (children[i].wantW !== undefined) w = Math.max(w, children[i].wantW);
                    wantW = w;
                }

                // the app's name, or the way back out of a submenu
                Pressable {
                    readonly property bool back: dd.trail.length > 0
                    readonly property real wantW: headLabel.implicitWidth + 60
                    width: col.width
                    height: dd.rowH
                    color: back && hovered ? Theme.containerHigh : "transparent"
                    enabledInput: back
                    cursor: back ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: dd.trail = dd.trail.slice(0, -1)
                    Icon {
                        id: headIcon
                        x: 10; anchors.verticalCenter: parent.verticalCenter
                        visible: parent.back
                        name: "arrow_back"; size: 18; color: Theme.accent
                    }
                    Image {
                        x: 10; anchors.verticalCenter: parent.verticalCenter
                        visible: !parent.back && status === Image.Ready
                        width: 18; height: 18
                        source: HubState.trayItem ? HubState.trayItem.icon : ""
                        sourceSize: Qt.size(36, 36); smooth: true; mipmap: true
                    }
                    Label {
                        id: headLabel
                        x: 38; anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - x - 10
                        elide: Text.ElideRight
                        text: parent.back ? (dd.trail[dd.trail.length - 1].text || "Back").replace(/&(?!&)/g, "")
                                          : (HubState.trayItem ? (HubState.trayItem.tooltipTitle || HubState.trayItem.title || HubState.trayItem.id) : "")
                        strong: true
                        color: parent.back ? Theme.accent : Theme.text
                    }
                }
                Rectangle { width: col.width; height: 1; color: Qt.alpha(Theme.text, 0.08) }

                Repeater {
                    model: dd.entries
                    onItemAdded: Qt.callLater(col.measure)
                    onItemRemoved: Qt.callLater(col.measure)
                    delegate: Item {
                        id: row
                        required property var modelData
                        readonly property var e: modelData
                        readonly property bool sep: e.isSeparator
                        // (mnemonic underscores / ampersands from the toolkit, dropped)
                        readonly property string label: String(e.text || "").replace(/&(?!&)/g, "").replace(/&&/g, "&").replace(/_(?!_)/g, "")
                        readonly property bool check: e.buttonType === QsMenuButtonType.CheckBox
                        readonly property bool radio: e.buttonType === QsMenuButtonType.RadioButton
                        readonly property bool on: e.checkState === Qt.Checked
                        readonly property real wantW: sep ? 0 : rowLabel.implicitWidth + 38 + 16 + (e.hasChildren ? 26 : 0)
                        width: col.width
                        height: sep ? 9 : dd.rowH
                        Rectangle { visible: row.sep; anchors.centerIn: parent; width: parent.width - 16; height: 1; color: Qt.alpha(Theme.text, 0.1) }
                        Pressable {
                            visible: !row.sep
                            anchors.fill: parent
                            color: hovered && row.e.enabled ? Theme.containerHigh : "transparent"
                            enabledInput: row.e.enabled
                            cursor: row.e.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (row.e.hasChildren) { dd.trail = dd.trail.concat([row.e]); return; }
                                row.e.triggered();
                                HubState.closeDrop();
                            }
                            // its mark: a check, a radio dot, or the app's icon for it
                            Item {
                                x: 10; width: 18; height: 18
                                anchors.verticalCenter: parent.verticalCenter
                                Rectangle {
                                    visible: row.check
                                    anchors.fill: parent
                                    radius: Theme.corner(18, -6)
                                    color: row.on ? Theme.accent : "transparent"
                                    border.width: row.on ? 0 : 1.5
                                    border.color: Theme.subtext
                                    Icon { visible: row.on; anchors.centerIn: parent; name: "check"; size: 14; color: Theme.onAccent }
                                }
                                Rectangle {
                                    visible: row.radio
                                    anchors.centerIn: parent
                                    width: 16; height: 16; radius: 8
                                    color: "transparent"
                                    border.width: 1.5
                                    border.color: row.on ? Theme.accent : Theme.subtext
                                    Rectangle { visible: row.on; anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: Theme.accent }
                                }
                                Image {
                                    visible: !row.check && !row.radio && status === Image.Ready
                                    anchors.fill: parent
                                    source: !row.check && !row.radio ? (row.e.icon || "") : ""
                                    sourceSize: Qt.size(36, 36); smooth: true; mipmap: true
                                    opacity: row.e.enabled ? 1 : 0.45
                                }
                            }
                            Label {
                                id: rowLabel
                                x: 38; anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - x - (row.e.hasChildren ? 30 : 10)
                                elide: Text.ElideRight
                                text: row.label
                                color: row.e.enabled ? Theme.text : Theme.faint
                            }
                            Icon {
                                visible: row.e.hasChildren
                                anchors.right: parent.right; anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                name: "chevron_right"; size: 18; color: Theme.subtext
                            }
                        }
                    }
                }
            }
        }
    }
}
