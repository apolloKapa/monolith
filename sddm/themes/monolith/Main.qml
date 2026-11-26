import QtQuick
import QtQuick.Window

// Monolith's login screen: the lock screen's quieter sibling. Your wallpaper (blurred) under a
// soft fade, a big clock and the date, the password pill with your picture in it, and in the
// corners the session and the power buttons. Your look comes from the desktop: the shell copies
// the wallpaper, picture, colours and font to /var/lib/monolith/login (scripts/login_sync.py),
// read here through theme.conf.user; without them it's Monolith's own dark look.
Rectangle {
    id: root
    width: Screen.width
    height: Screen.height
    color: c.surface

    readonly property real s: Math.max(0.6, Math.min(width / 1920, height / 1080))
    readonly property bool live: typeof sddm !== "undefined"

    // a setting from theme.conf(.user), or `d`
    function cfg(k, d) {
        if (typeof config === "undefined" || !config) return d;
        const v = config.stringValue ? config.stringValue(k) : config[k];
        return v !== undefined && v !== null && String(v) !== "" ? String(v) : d;
    }

    QtObject {
        id: c
        readonly property bool light: root.cfg("mode", "dark") === "light"
        readonly property color primary: root.cfg("primary", light ? "#5d5791" : "#c6bfff")
        readonly property color onPrimary: root.cfg("onPrimary", light ? "#ffffff" : "#2e295f")
        readonly property color surface: root.cfg("surface", light ? "#fcf8ff" : "#131318")
        readonly property color text: root.cfg("onSurface", light ? "#1c1b20" : "#e5e1e9")
        readonly property color sub: root.cfg("onSurfaceVariant", light ? "#47464f" : "#c8c5d0")
        readonly property color container: root.cfg("container", light ? "#eae7ef" : "#2a292f")
        readonly property color error: root.cfg("error", light ? "#ba1a1a" : "#ffb4ab")
        readonly property color outline: root.cfg("outline", light ? "#c8c5d0" : "#47464f")
    }

    FontLoader { id: sans; source: "font/GoogleSans-VariableFont_GRAD,opsz,wght.ttf" }
    FontLoader { id: sym; source: "font/MonolithSymbols-Rounded.ttf" }
    readonly property string font: cfg("font", "") || (sans.status === FontLoader.Ready ? sans.name : "sans-serif")

    component Sym: Text {
        property string name
        property real size: 22 * root.s
        text: name
        font.family: sym.name
        font.pixelSize: size
        color: c.sub
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        renderType: Text.CurveRendering
    }

    // ── who and which session (read through invisible lists: SDDM's models only give their
    // rows to delegates) ──
    property int userIndex: typeof userModel !== "undefined" && userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIndex: typeof sessionModel !== "undefined" && sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    readonly property int userCount: users.count
    readonly property int sessionCount: sessions.count
    ListView {
        id: users
        visible: false; width: 1; height: 1
        model: typeof userModel !== "undefined" ? userModel : null
        currentIndex: root.userIndex
        delegate: Item {
            required property string name
            required property string realName
            required property string icon
            readonly property string login: name
            readonly property string shown: realName !== "" ? realName : name
        }
    }
    ListView {
        id: sessions
        visible: false; width: 1; height: 1
        model: typeof sessionModel !== "undefined" ? sessionModel : null
        currentIndex: root.sessionIndex
        delegate: Item { required property string name; readonly property string label: name }
    }
    readonly property string login: users.currentItem ? users.currentItem.login : (typeof userModel !== "undefined" ? userModel.lastUser : "")
    readonly property string userName: users.currentItem ? users.currentItem.shown : login
    readonly property string sessionName: sessions.currentItem ? sessions.currentItem.label : ""
    // your picture (made round by the shell) for the user who set Monolith up; another user's
    // own, else their initial
    readonly property string face: login !== "" && login === cfg("user", "") && cfg("face", "") !== "" ? "file://" + cfg("face", "")
                                   : (users.currentItem && users.currentItem.icon !== "" ? users.currentItem.icon : "")

    // ── logging in ──
    property bool busy: false
    property string message: ""
    function tryLogin() {
        if (busy || pwd.text === "" || !live) return;
        busy = true; message = "";
        sddm.login(login, pwd.text, sessionIndex);
    }
    Connections {
        target: root.live ? sddm : null
        // logged in: the greeter quits by itself (left to SDDM it didn't exit in the 5 s it
        // waits, "Process crashed" at every login, and stayed running all session, ~200 MB)
        function onLoginSucceeded() { Qt.quit(); }
        function onLoginFailed() {
            root.busy = false;
            root.message = "Wrong password";
            pwd.text = "";
            shake.restart();
            msgTimer.restart();
            pwd.forceActiveFocus();
        }
    }
    Timer { id: msgTimer; interval: 4000; onTriggered: root.message = "" }

    // ── the background: the wallpaper, blurred already (by the shell: no shader needed here,
    // so it looks the same with software rendering), under a fade; a soft gradient without one ──
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.lighter(c.container, c.light ? 1.0 : 1.15) }
            GradientStop { position: 1; color: c.surface }
        }
    }
    Image {
        id: wall
        anchors.fill: parent
        source: root.cfg("background", "") !== "" ? "file://" + root.cfg("background", "") : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(c.surface, 0.18) }
            GradientStop { position: 0.55; color: Qt.alpha(c.surface, 0.32) }
            GradientStop { position: 1.0; color: Qt.alpha(c.surface, 0.72) }
        }
    }

    // clicks anywhere bring the typing back to the password
    MouseArea { anchors.fill: parent; onClicked: pwd.forceActiveFocus() }

    // ── coming in: the clock first, then the password, then the corners ──
    property real k: 0
    NumberAnimation on k { from: 0; to: 1; duration: 1100; easing.type: Easing.Linear }
    function part(from, len) { const t = Math.max(0, Math.min(1, (k - from) / len)); return 1 - Math.pow(1 - t, 3); }

    QtObject { id: now; property date date: new Date() }
    Timer { interval: 1000; running: true; repeat: true; onTriggered: now.date = new Date() }

    Column {
        id: clockCol
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.36 - height / 2 + (1 - root.part(0, 0.6)) * 24 * root.s
        opacity: root.part(0, 0.6)
        spacing: 2 * root.s
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(now.date, "hh:mm")
            font.family: root.font
            font.pixelSize: 132 * root.s
            font.weight: Font.DemiBold
            font.letterSpacing: -2 * root.s
            color: c.text
            renderType: Text.CurveRendering
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(now.date, "dddd d MMMM")
            font.family: root.font
            font.pixelSize: 22 * root.s
            font.weight: Font.Medium
            color: c.sub
        }
    }

    // ── the password pill ──
    Item {
        id: who
        width: 420 * root.s
        height: pill.height + 40 * root.s
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.62 - pill.height / 2 + (1 - root.part(0.25, 0.6)) * 24 * root.s
        opacity: root.part(0.25, 0.6)
        transform: Translate { id: shakeX }

        Rectangle {
            id: pill
            width: parent.width
            height: 64 * root.s
            radius: height / 2
            color: Qt.alpha(c.container, 0.78)
            border.width: Math.max(1, root.s)
            border.color: root.message !== "" ? Qt.alpha(c.error, 0.9) : (pwd.activeFocus ? Qt.alpha(c.primary, 0.55) : Qt.alpha(c.outline, 0.5))
            Behavior on border.color { ColorAnimation { duration: 200 } }

            // your picture; a click (or ↑ ↓) goes to the next user when there are more
            Rectangle {
                id: avatar
                x: 10 * root.s
                anchors.verticalCenter: parent.verticalCenter
                width: 44 * root.s; height: width; radius: width / 2
                color: c.primary
                Text {
                    anchors.centerIn: parent
                    visible: faceImg.status !== Image.Ready
                    text: root.userName.length > 0 ? root.userName[0].toUpperCase() : "?"
                    font.family: root.font
                    font.pixelSize: 20 * root.s
                    font.weight: Font.Bold
                    color: c.onPrimary
                }
                Image {
                    id: faceImg
                    anchors.fill: parent
                    source: root.face
                    sourceSize: Qt.size(width * 2, height * 2)
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    asynchronous: true
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: root.userCount > 1
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.nextUser(1)
                }
            }

            TextInput {
                id: pwd
                anchors.left: avatar.right; anchors.leftMargin: 16 * root.s
                anchors.right: go.left; anchors.rightMargin: 12 * root.s
                anchors.verticalCenter: parent.verticalCenter
                echoMode: TextInput.Password
                passwordCharacter: "●"
                passwordMaskDelay: 0
                font.family: root.font
                font.pixelSize: 18 * root.s
                font.letterSpacing: 2 * root.s
                color: c.text
                selectionColor: Qt.alpha(c.primary, 0.4)
                clip: true
                focus: true
                enabled: !root.busy
                opacity: root.busy ? 0.5 : 1
                inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                onAccepted: root.tryLogin()
                onTextChanged: if (text !== "") root.message = ""
                Keys.onEscapePressed: text = ""
                Keys.onUpPressed: root.nextUser(-1)
                Keys.onDownPressed: root.nextUser(1)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pwd.text === ""
                    text: root.userName + "  ·  password"
                    font.family: root.font
                    font.pixelSize: 17 * root.s
                    color: c.sub
                    opacity: 0.8
                    elide: Text.ElideRight
                    width: parent.width
                }
            }

            // the arrow, once there's something to send; turning while it logs in
            Rectangle {
                id: go
                anchors.right: parent.right; anchors.rightMargin: 10 * root.s
                anchors.verticalCenter: parent.verticalCenter
                width: 44 * root.s; height: width; radius: width / 2
                color: goMouse.containsMouse ? Qt.lighter(c.primary, 1.08) : c.primary
                readonly property bool on: pwd.text !== "" || root.busy
                opacity: on ? 1 : 0
                scale: on ? 1 : 0.6
                Behavior on opacity { NumberAnimation { duration: 180 } }
                Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
                Sym {
                    anchors.centerIn: parent
                    name: root.busy ? "progress_activity" : "arrow_forward"
                    color: c.onPrimary
                    size: 22 * root.s
                    RotationAnimation on rotation { running: root.busy; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
                    rotation: 0
                }
                MouseArea { id: goMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.tryLogin() }
            }
        }

        // a wrong password, or Caps Lock on
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: pill.bottom; anchors.topMargin: 14 * root.s
            readonly property bool caps: typeof keyboard !== "undefined" && keyboard && keyboard.capsLock
            text: root.message !== "" ? root.message : (caps ? "Caps Lock is on" : "")
            color: root.message !== "" ? c.error : c.sub
            font.family: root.font
            font.pixelSize: 14 * root.s
            font.weight: Font.Medium
            opacity: text !== "" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
    }
    SequentialAnimation {
        id: shake
        NumberAnimation { target: shakeX; property: "x"; to: 14 * root.s; duration: 45 }
        NumberAnimation { target: shakeX; property: "x"; to: -12 * root.s; duration: 70 }
        NumberAnimation { target: shakeX; property: "x"; to: 8 * root.s; duration: 70 }
        NumberAnimation { target: shakeX; property: "x"; to: -4 * root.s; duration: 70 }
        NumberAnimation { target: shakeX; property: "x"; to: 0; duration: 60 }
    }
    function nextUser(d) {
        if (userCount < 2) return;
        userIndex = (userIndex + d + userCount) % userCount;
        pwd.text = ""; message = "";
    }

    // ── the corners: the session (a click goes to the next), the power buttons ──
    component Corner: Rectangle {
        id: cb
        property string icon
        property string label
        property bool wide: false
        signal clicked
        height: 44 * root.s
        width: wide ? row.implicitWidth + 32 * root.s : height
        radius: height / 2
        color: ma.containsMouse ? Qt.alpha(c.container, 0.85) : "transparent"
        Behavior on color { ColorAnimation { duration: 150 } }
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 10 * root.s
            Sym { name: cb.icon; size: 22 * root.s; color: ma.containsMouse ? c.text : c.sub; anchors.verticalCenter: parent.verticalCenter }
            Text {
                visible: cb.wide
                text: cb.label
                font.family: root.font
                font.pixelSize: 15 * root.s
                font.weight: Font.Medium
                color: ma.containsMouse ? c.text : c.sub
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: cb.clicked() }
        readonly property bool hovered: ma.containsMouse
    }

    Corner {
        x: 28 * root.s
        y: root.height - height - 28 * root.s
        opacity: root.part(0.5, 0.5)
        visible: root.sessionCount > 1 || root.sessionName !== ""
        wide: true
        icon: "desktop_windows"
        label: root.sessionName
        onClicked: if (root.sessionCount > 1) root.sessionIndex = (root.sessionIndex + 1) % root.sessionCount
    }

    Row {
        id: power
        x: root.width - width - 28 * root.s
        y: root.height - height - 28 * root.s
        opacity: root.part(0.5, 0.5)
        spacing: 6 * root.s
        // what the button under the pointer does, beside them
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: sleepB.hovered ? "Sleep" : rebootB.hovered ? "Restart" : offB.hovered ? "Power off" : ""
            font.family: root.font
            font.pixelSize: 15 * root.s
            font.weight: Font.Medium
            color: c.text
            rightPadding: 6 * root.s
        }
        Corner { id: sleepB; icon: "bedtime"; visible: !root.live || sddm.canSuspend; onClicked: if (root.live) sddm.suspend() }
        Corner { id: rebootB; icon: "restart_alt"; visible: !root.live || sddm.canReboot; onClicked: if (root.live) sddm.reboot() }
        Corner { id: offB; icon: "power_settings_new"; visible: !root.live || sddm.canPowerOff; onClicked: if (root.live) sddm.powerOff() }
    }

    Component.onCompleted: {
        pwd.forceActiveFocus();
        if (typeof keyboard !== "undefined" && keyboard) keyboard.numLock = true;
    }
    Timer { interval: 300; running: true; onTriggered: pwd.forceActiveFocus() }
}
