import QtQuick
import QtQuick.Layouts
import Quickshell
import "../core"
import "../ui"

// Wellbeing: your screen time. A header (Day / Week, the date with arrows and Today, the gear),
// then for a day: the total (against the day before, and your daily goal), the busiest hour and
// the daily average; that week's bars next to the month as a heatmap (click a day to see it);
// and the apps, each opening its own view (its hours, its week, its daily limit). For a week:
// days × hours as a heatmap, and the week's apps. The gear holds its settings (tracking, the
// daily goal, every limit, forgetting it all). Data: core/Wellbeing.qml.
Page {
    id: page
    pageId: "wellbeing"
    implicitHeight: 660

    // ── where you are ──
    property string mode: "day"            // day | week
    property var sel: new Date()           // the day looked at (in week mode: its week)
    property string app: ""                // an app's own view, "" for none
    property bool settingsOpen: false
    onCurrentChanged: if (current) { sel = new Date(); app = ""; settingsOpen = false; }

    function k(d) { return Wellbeing.key(d); }
    function addDays(d, n) { const x = new Date(d); x.setDate(x.getDate() + n); return x; }
    function sameDay(a, b) { return k(a) === k(b); }
    readonly property bool isToday: sameDay(sel, new Date())
    // Monday of the week `sel` is in, and its seven days
    readonly property var monday: { const d = new Date(sel); d.setHours(12); d.setDate(d.getDate() - ((d.getDay() + 6) % 7)); return d; }
    readonly property var weekDays: [0, 1, 2, 3, 4, 5, 6].map(i => addDays(monday, i))
    readonly property bool thisWeek: sameDay(monday, (() => { const d = new Date(); d.setDate(d.getDate() - ((d.getDay() + 6) % 7)); return d; })())
    function step(n) {
        const next = addDays(sel, n * (mode === "week" ? 7 : 1));
        sel = next > new Date() ? new Date() : next;
    }
    readonly property string dateLabel: mode === "week"
        ? Qt.formatDate(weekDays[0], "d MMM") + " – " + Qt.formatDate(weekDays[6], "d MMM yyyy")
        : (isToday ? "Today" : sameDay(sel, addDays(new Date(), -1)) ? "Yesterday" : Qt.formatDate(sel, "dddd d MMMM"))

    // ── the numbers (Wellbeing.days etc. in each, so they follow the data) ──
    readonly property int dayTotal: { Wellbeing.days; return app !== "" ? (Wellbeing.dayMap(k(sel))[app] || 0) : Wellbeing.dayTotal(k(sel)); }
    readonly property int prevTotal: { Wellbeing.days; const p = k(addDays(sel, -1)); return app !== "" ? (Wellbeing.dayMap(p)[app] || 0) : Wellbeing.dayTotal(p); }
    readonly property var dayHours: { Wellbeing.hours; Wellbeing.appHours; return app !== "" ? Wellbeing.appHoursOf(k(sel), app) : Wellbeing.hoursOf(k(sel)); }
    readonly property int peakHour: { const h = dayHours; if (!h) return -1; let b = -1, v = 0; for (let i = 0; i < 24; i++) if (h[i] > v) { v = h[i]; b = i; } return b; }
    // the last seven days up to `sel` (days with nothing count too, but not ones before tracking began)
    readonly property int average: {
        Wellbeing.days;
        let sum = 0, n = 0;
        const first = Object.keys(Wellbeing.days).sort()[0] || k(sel);
        for (let i = 0; i < 7; i++) {
            const dk = k(addDays(sel, -i));
            if (dk < first) break;
            sum += app !== "" ? (Wellbeing.dayMap(dk)[app] || 0) : Wellbeing.dayTotal(dk);
            n++;
        }
        return n ? Math.round(sum / n) : 0;
    }
    readonly property var weekTotals: { Wellbeing.days; return weekDays.map(d => app !== "" ? (Wellbeing.dayMap(k(d))[app] || 0) : Wellbeing.dayTotal(k(d))); }
    readonly property real weekMax: Math.max(1800, ...weekTotals)
    // the apps of the day (or the week), most first
    function appsOf(keys) {
        Wellbeing.days;
        const sum = {};
        for (const dk of keys) { const m = Wellbeing.dayMap(dk); for (const a in m) sum[a] = (sum[a] || 0) + m[a]; }
        return Object.keys(sum).map(a => ({ id: a, s: sum[a] })).filter(x => x.s >= 60).sort((x, y) => y.s - x.s);
    }
    readonly property var dayApps: appsOf([k(sel)])
    readonly property var weekApps: appsOf(weekDays.map(d => k(d)))
    // the month of `sel`: Monday-first cells, { d: Date or null, s }
    readonly property var monthCells: {
        Wellbeing.days;
        const first = new Date(sel.getFullYear(), sel.getMonth(), 1, 12);
        const lead = (first.getDay() + 6) % 7;
        const n = new Date(sel.getFullYear(), sel.getMonth() + 1, 0).getDate();
        const out = [];
        for (let i = 0; i < lead; i++) out.push({ d: null, s: 0 });
        for (let i = 1; i <= n; i++) { const d = new Date(sel.getFullYear(), sel.getMonth(), i, 12); out.push({ d: d, s: Wellbeing.dayTotal(k(d)) }); }
        return out;
    }
    readonly property real monthMax: Math.max(3600, ...monthCells.map(c => c.s))
    // the week as days × hours
    readonly property var heat: { Wellbeing.hours; return weekDays.map(d => Wellbeing.hoursOf(k(d)) || new Array(24).fill(0)); }
    readonly property real heatMax: Math.max(600, ...heat.map(r => Math.max(...r)))
    readonly property bool hasHours: heat.some(r => r.some(v => v > 0))

    // ── shared pieces ──
    component Box: Rectangle {
        radius: Theme.corner(80, 8)
        color: Theme.container
        border.width: Theme.outlineW; border.color: Theme.outlineColor
    }
    component Small: Label { muted: true; font.pixelSize: Theme.sizeSmall }
    component IconBtn: Pressable {
        property string icon: ""
        property bool on: false
        width: 34; height: 34
        color: on ? Theme.accent : (hovered ? Theme.containerHigh : "transparent")
        Icon { anchors.centerIn: parent; name: parent.icon; size: 20; color: parent.on ? Theme.onAccent : Theme.text }
    }
    // a list of apps: icon, name, time, share, bar; a click opens the app's own view
    component AppList: Column {
        id: al
        property var list: []
        property real total: 1
        property bool canOpen: true
        signal picked(string id)
        spacing: 4
        Repeater {
            model: al.list
            Pressable {
                id: ar
                required property var modelData
                readonly property int limit: Wellbeing.limitOf(modelData.id)
                width: al.width
                height: 52
                color: hovered && al.canOpen ? Theme.containerHigh : "transparent"
                enabledInput: al.canOpen
                onClicked: al.picked(modelData.id)
                Image { id: ai; x: 10; anchors.verticalCenter: parent.verticalCenter; width: 30; height: 30; sourceSize: Qt.size(60, 60); source: Wellbeing.iconOf(ar.modelData.id); smooth: true; mipmap: true; asynchronous: true }
                Column {
                    anchors.left: ai.right; anchors.leftMargin: 12
                    anchors.right: parent.right; anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    RowLayout {
                        width: parent.width
                        Label { Layout.fillWidth: true; text: Wellbeing.nameOf(ar.modelData.id); strong: true; elide: Text.ElideRight }
                        Label { visible: ar.limit > 0; text: "limit " + Wellbeing.fmtShort(ar.limit * 60); muted: true; font.pixelSize: Theme.sizeTiny + 1 }
                        Label { text: Math.round(100 * ar.modelData.s / Math.max(1, al.total)) + "%"; muted: true; font.pixelSize: Theme.sizeSmall; Layout.preferredWidth: 40; horizontalAlignment: Text.AlignRight }
                        Label { text: Wellbeing.fmt(ar.modelData.s); font.pixelSize: Theme.sizeSmall; strong: true; Layout.preferredWidth: 84; horizontalAlignment: Text.AlignRight }
                        Icon { visible: al.canOpen; name: "chevron_right"; size: 18; color: Theme.subtext }
                    }
                    Rectangle {
                        width: parent.width; height: 5; radius: 3
                        color: Theme.control
                        Rectangle {
                            width: parent.width * Math.min(1, ar.modelData.s / Math.max(1, al.list.length ? al.list[0].s : 1))
                            height: parent.height; radius: 3
                            color: ar.limit > 0 && ar.modelData.s >= ar.limit * 60 ? Theme.danger : Theme.accent
                            Behavior on width { NumberAnimation { duration: Theme.ms(500); easing.type: Easing.OutCubic } }
                        }
                    }
                }
            }
        }
    }
    // bars over labels (a week's days, a day's hours); `hot` is the highlighted one
    component Bars: Item {
        id: bars
        property var values: []
        property var labels: []
        property int hot: -1
        property real max: 1
        property bool clickable: false
        property var dim: []               // indexes to draw faint (days still to come)
        signal picked(int i)
        Row {
            anchors.fill: parent
            spacing: bars.values.length > 12 ? 3 : 10
            Repeater {
                model: bars.values.length
                Item {
                    id: bi
                    required property int index
                    readonly property real v: bars.values[index] || 0
                    width: (bars.width - (bars.values.length - 1) * parent.spacing) / bars.values.length
                    height: bars.height
                    // its value over the highlighted bar
                    Label {
                        visible: bi.index === bars.hot && bi.v > 0
                        anchors.horizontalCenter: col.horizontalCenter; anchors.bottom: col.top; anchors.bottomMargin: 4
                        text: Wellbeing.fmtShort(bi.v); font.pixelSize: Theme.sizeTiny + 1; strong: true
                    }
                    Rectangle {
                        id: col
                        anchors.bottom: lab.top; anchors.bottomMargin: 6
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(parent.width, 34)
                        height: Math.max(4, (bars.height - 40) * Math.min(1, bi.v / Math.max(1, bars.max)))
                        radius: Math.min(width / 2, Theme.corner(width))
                        color: bi.index === bars.hot ? Theme.accent : (bars.dim.indexOf(bi.index) !== -1 ? Qt.alpha(Theme.control, 0.4) : Theme.control)
                        Behavior on height { NumberAnimation { duration: Theme.ms(450); easing.type: Easing.OutCubic } }
                    }
                    Label { id: lab; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; text: bars.labels[bi.index] || ""; muted: bi.index !== bars.hot; strong: bi.index === bars.hot; font.pixelSize: Theme.sizeTiny + 1 }
                    MouseArea { anchors.fill: parent; enabled: bars.clickable && bars.dim.indexOf(bi.index) === -1; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: bars.picked(bi.index) }
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // ── the header ──
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            spacing: 6
            IconBtn { visible: page.app !== "" || page.settingsOpen; icon: "arrow_back"; onClicked: { page.app = ""; page.settingsOpen = false; } }
            Segmented {
                visible: !page.settingsOpen
                Layout.preferredWidth: 170; height: 36
                opts: [["day", "Day"], ["week", "Week"]]
                value: page.mode
                onPicked: v => { page.mode = v; page.app = ""; }
            }
            Image { visible: page.app !== "" && !page.settingsOpen; Layout.leftMargin: 6; Layout.preferredWidth: 24; Layout.preferredHeight: 24; sourceSize: Qt.size(48, 48); source: page.app !== "" ? Wellbeing.iconOf(page.app) : ""; smooth: true; mipmap: true }
            Label {
                Layout.leftMargin: 4
                text: page.settingsOpen ? "Wellbeing settings" : page.app !== "" ? Wellbeing.nameOf(page.app) : (page.mode === "week" ? "Your week" : "Screen time")
                strong: true; font.pixelSize: Theme.sizeTitle
            }
            Item { Layout.fillWidth: true }
            // the date, with arrows (no going past today) and Today
            IconBtn { visible: !page.settingsOpen; icon: "chevron_left"; onClicked: page.step(-1) }
            Label { visible: !page.settingsOpen; text: page.dateLabel; strong: true; Layout.minimumWidth: 120; horizontalAlignment: Text.AlignHCenter }
            IconBtn { visible: !page.settingsOpen; icon: "chevron_right"; opacity: (page.mode === "week" ? page.thisWeek : page.isToday) ? 0.3 : 1; enabledInput: opacity === 1; onClicked: page.step(1) }
            Button { visible: !page.settingsOpen && !(page.mode === "week" ? page.thisWeek : page.isToday); text: "Today"; height: 34; onClicked: page.sel = new Date() }
            IconBtn { icon: "settings"; on: page.settingsOpen; onClicked: page.settingsOpen = !page.settingsOpen }
        }
        Rectangle { visible: !Wellbeing.tracking && !page.settingsOpen; Layout.fillWidth: true; Layout.preferredHeight: 38; radius: 19; color: Qt.alpha(Theme.accent, 0.12)
            Small { anchors.centerIn: parent; text: "Tracking is off, so nothing new is added. Turn it on with the gear" } }

        // ── a day ──
        Flickable {
            id: dayView
            visible: page.mode === "day" && !page.settingsOpen
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: dayCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            SmoothWheel {}
            ColumnLayout {
                id: dayCol
                width: dayView.width
                spacing: 10

                // the total, the busiest hour, the average
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 128
                    spacing: 10
                    Box {
                        id: totalBox
                        Rise {}
                        Layout.fillWidth: true; Layout.fillHeight: true
                        Column {
                            x: 18; y: 14; width: parent.width - 36
                            spacing: 4
                            Small { text: page.app !== "" ? "Time in " + Wellbeing.nameOf(page.app) : "Screen time" }
                            Label { text: Wellbeing.fmt(page.dayTotal); font.pixelSize: 34; font.weight: Font.Light }
                            Row {
                                spacing: 6
                                readonly property int diff: page.dayTotal - page.prevTotal
                                Icon { visible: page.prevTotal > 0; name: parent.diff > 0 ? "trending_up" : parent.diff < 0 ? "trending_down" : "trending_flat"; size: 16; color: Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
                                Small {
                                    text: page.prevTotal === 0 ? "Nothing the day before to compare with"
                                        : Math.abs(parent.diff) < 60 ? "About the same as the day before"
                                        : Wellbeing.fmt(Math.abs(parent.diff)) + (parent.diff > 0 ? " more" : " less") + " than the day before"
                                }
                            }
                        }
                        // the daily goal (or an app's limit), as a bar along the bottom
                        readonly property int cap: page.app !== "" ? Wellbeing.limitOf(page.app) : Wellbeing.goal
                        Column {
                            visible: parent.cap > 0
                            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                            anchors.margins: 18; anchors.bottomMargin: 12
                            spacing: 4
                            Rectangle {
                                width: parent.width; height: 6; radius: 3; color: Theme.control
                                Rectangle { height: parent.height; radius: 3; width: parent.width * Math.min(1, page.dayTotal / Math.max(1, totalBox.cap * 60)); color: page.dayTotal >= totalBox.cap * 60 ? Theme.danger : Theme.accent }
                            }
                            Small {
                                font.pixelSize: Theme.sizeTiny + 1
                                text: page.dayTotal >= totalBox.cap * 60 ? (page.app !== "" ? "Limit reached (" : "Goal reached (") + Wellbeing.fmt(totalBox.cap * 60) + ")"
                                    : Wellbeing.fmt(page.dayTotal) + " of " + Wellbeing.fmt(totalBox.cap * 60) + (page.app !== "" ? " limit" : " goal")
                            }
                        }
                    }
                    Box {
                        Rise {}
                        Layout.preferredWidth: 200; Layout.fillHeight: true
                        Column {
                            x: 16; y: 14; width: parent.width - 32; spacing: 6
                            Row { spacing: 6; Icon { name: "schedule"; size: 16; color: Theme.subtext; anchors.verticalCenter: parent.verticalCenter } Small { text: "Busiest hour" } }
                            Label { text: page.peakHour < 0 ? "—" : String(page.peakHour).padStart(2, "0") + ":00"; font.pixelSize: 28; font.weight: Font.Light }
                            Small { width: parent.width; wrapMode: Text.Wrap; font.pixelSize: Theme.sizeTiny + 1; text: page.peakHour < 0 ? "Hours are kept from 2.7.1 on" : Wellbeing.fmt(page.dayHours[page.peakHour]) + " in that hour" }
                        }
                    }
                    Box {
                        Rise {}
                        Layout.preferredWidth: 200; Layout.fillHeight: true
                        Column {
                            x: 16; y: 14; width: parent.width - 32; spacing: 6
                            Row { spacing: 6; Icon { name: "avg_pace"; size: 16; color: Theme.subtext; anchors.verticalCenter: parent.verticalCenter } Small { text: "Daily average" } }
                            Label { text: Wellbeing.fmt(page.average); font.pixelSize: 28; font.weight: Font.Light }
                            Small { font.pixelSize: Theme.sizeTiny + 1; text: "Over the last 7 days" }
                        }
                    }
                }

                // that week's bars, and the month as a heatmap (or an app's hours)
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 230
                    spacing: 10
                    Box {
                        Rise {}
                        Layout.fillWidth: true; Layout.fillHeight: true
                        Small { x: 18; y: 14; text: Qt.formatDate(page.weekDays[0], "d MMM") + " – " + Qt.formatDate(page.weekDays[6], "d MMM") }
                        Small { anchors.right: parent.right; anchors.rightMargin: 18; y: 14; text: "Total " + Wellbeing.fmt(page.weekTotals.reduce((a, b) => a + b, 0)) }
                        Bars {
                            x: 18; y: 44; width: parent.width - 36; height: parent.height - 58
                            values: page.weekTotals
                            labels: page.weekDays.map(d => Qt.formatDate(d, "ddd"))
                            hot: page.weekDays.findIndex(d => page.sameDay(d, page.sel))
                            max: page.weekMax
                            dim: page.weekDays.map((d, i) => d > new Date() ? i : -1).filter(i => i >= 0)
                            clickable: true
                            onPicked: i => page.sel = page.weekDays[i]
                        }
                    }
                    // the whole month: a square a day, the brighter the longer (click one to see it)
                    Box {
                        Rise {}
                        visible: page.app === ""
                        Layout.preferredWidth: 300; Layout.fillHeight: true
                        Small { x: 16; y: 14; text: Qt.formatDate(page.sel, "MMMM yyyy") }
                        Grid {
                            id: mg
                            x: 16; y: 40
                            columns: 7
                            columnSpacing: 5; rowSpacing: 5
                            readonly property real cell: (parent.width - 32 - 6 * 5) / 7
                            Repeater {
                                model: ["M", "T", "W", "T", "F", "S", "S"]
                                Label { required property string modelData; width: mg.cell; height: 14; horizontalAlignment: Text.AlignHCenter; text: modelData; muted: true; font.pixelSize: Theme.sizeTiny }
                            }
                            Repeater {
                                model: page.monthCells
                                Rectangle {
                                    id: mc
                                    required property var modelData
                                    readonly property bool real: !!modelData.d
                                    readonly property bool future: real && modelData.d > new Date()
                                    readonly property bool picked: real && page.sameDay(modelData.d, page.sel)
                                    width: mg.cell; height: Math.min(mg.cell, 22)
                                    radius: 5
                                    color: !real ? "transparent" : future ? Qt.alpha(Theme.control, 0.3) : modelData.s === 0 ? Theme.control : Qt.alpha(Theme.accent, 0.25 + 0.75 * Math.min(1, modelData.s / page.monthMax))
                                    border.width: picked ? 2 : 0
                                    border.color: Theme.text
                                    Label { anchors.centerIn: parent; visible: mc.real; text: mc.real ? mc.modelData.d.getDate() : ""; font.pixelSize: Theme.sizeTiny; color: mc.modelData.s > page.monthMax * 0.5 ? Theme.onAccent : Theme.text }
                                    MouseArea { anchors.fill: parent; enabled: mc.real && !mc.future; cursorShape: Qt.PointingHandCursor; onClicked: page.sel = mc.modelData.d }
                                }
                            }
                        }
                    }
                    // an app: its hours that day
                    Box {
                        Rise {}
                        visible: page.app !== ""
                        Layout.preferredWidth: 420; Layout.fillHeight: true
                        Small { x: 16; y: 14; text: "Hour by hour" }
                        Bars {
                            x: 16; y: 44; width: parent.width - 32; height: parent.height - 58
                            values: page.dayHours || new Array(24).fill(0)
                            labels: [...Array(24).keys()].map(h => h % 6 === 0 ? String(h).padStart(2, "0") : "")
                            hot: page.peakHour
                            max: Math.max(300, ...(page.dayHours || [0]))
                        }
                        Small { anchors.centerIn: parent; visible: !page.dayHours; text: "No hours kept for this day" }
                    }
                }

                // the apps (or, in an app's view, its limit)
                Box {
                    Rise {}
                    visible: page.app === ""
                    Layout.fillWidth: true
                    Layout.preferredHeight: dayList.implicitHeight + 56
                    Small { x: 18; y: 14; text: page.dayApps.length + (page.dayApps.length === 1 ? " app" : " apps") + "   ·   click one for its own view" }
                    AppList {
                        id: dayList
                        x: 8; y: 40; width: parent.width - 16
                        list: page.dayApps
                        total: page.dayTotal
                        onPicked: id => page.app = id
                    }
                    Small { visible: page.dayApps.length === 0; anchors.horizontalCenter: parent.horizontalCenter; y: 40; text: "Nothing tracked on this day" }
                }
                Box {
                    Rise {}
                    visible: page.app !== ""
                    Layout.fillWidth: true
                    Layout.preferredHeight: 76
                    readonly property int lim: Wellbeing.limitOf(page.app)
                    Icon { id: hg; x: 18; anchors.verticalCenter: parent.verticalCenter; name: "hourglass"; size: 22; color: Theme.accent }
                    Column {
                        anchors.left: hg.right; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                        Label { text: "Daily limit"; strong: true }
                        Small { text: parent.parent.lim > 0 ? "A notification when you've used it this long in a day" : "None: set one and you get a notification when it's reached" }
                    }
                    NumberBox {
                        anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter
                        width: 320
                        from: 0; to: 1440; slideTo: 480; step: 5; unit: " min"; zeroText: "None"
                        value: parent.lim
                        onMoved: v => Wellbeing.setLimit(page.app, v)
                    }
                }
            }
        }

        // ── a week ──
        Flickable {
            id: weekView
            visible: page.mode === "week" && !page.settingsOpen
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: weekCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            SmoothWheel {}
            ColumnLayout {
                id: weekCol
                width: weekView.width
                spacing: 10
                // days × hours: when you're at the screen
                Box {
                    Rise {}
                    Layout.fillWidth: true
                    Layout.preferredHeight: 290
                    Small { x: 18; y: 14; text: "When you were at the screen" }
                    Small { anchors.right: parent.right; anchors.rightMargin: 18; y: 14; text: "Total " + Wellbeing.fmt(page.weekTotals.reduce((a, b) => a + b, 0)) + "   ·   " + Wellbeing.fmt(page.weekTotals.reduce((a, b) => a + b, 0) / 7) + " a day" }
                    Column {
                        id: hm
                        x: 18; y: 44
                        width: parent.width - 36
                        spacing: 4
                        readonly property real cellW: (width - 44 - 23 * 3) / 24
                        Repeater {
                            model: 7
                            Row {
                                id: hr
                                required property int index
                                spacing: 3
                                Label { width: 44; height: 24; verticalAlignment: Text.AlignVCenter; text: Qt.formatDate(page.weekDays[hr.index], "ddd"); muted: true; font.pixelSize: Theme.sizeTiny + 1 }
                                Repeater {
                                    model: 24
                                    Rectangle {
                                        required property int index
                                        readonly property real v: page.heat[hr.index][index]
                                        width: hm.cellW; height: 24; radius: 4
                                        color: v <= 0 ? Theme.control : Qt.alpha(Theme.accent, 0.2 + 0.8 * Math.min(1, v / page.heatMax))
                                        HoverHandler { id: hh }
                                        // what's in it, on hover
                                        Rectangle {
                                            visible: hh.hovered && parent.v > 0
                                            z: 10
                                            anchors.bottom: parent.top; anchors.bottomMargin: 4; anchors.horizontalCenter: parent.horizontalCenter
                                            width: tipL.implicitWidth + 14; height: 24; radius: 12
                                            color: Theme.frame
                                            Label { id: tipL; anchors.centerIn: parent; text: String(parent.parent.index).padStart(2, "0") + ":00  ·  " + Wellbeing.fmtShort(parent.parent.v); font.pixelSize: Theme.sizeTiny + 1 }
                                        }
                                    }
                                }
                            }
                        }
                        // hours along the bottom, and the scale
                        Item {
                            width: parent.width; height: 20
                            Repeater {
                                model: [0, 6, 12, 18, 23]
                                Label { required property int modelData; x: 47 + modelData * (hm.cellW + 3); text: String(modelData).padStart(2, "0"); muted: true; font.pixelSize: Theme.sizeTiny }
                            }
                        }
                        Row {
                            spacing: 4
                            Small { text: "Less"; font.pixelSize: Theme.sizeTiny; anchors.verticalCenter: parent.verticalCenter }
                            Repeater {
                                model: [0, 0.25, 0.5, 0.75, 1]
                                Rectangle { required property real modelData; width: 14; height: 14; radius: 3; color: modelData === 0 ? Theme.control : Qt.alpha(Theme.accent, 0.2 + 0.8 * modelData) }
                            }
                            Small { text: "More"; font.pixelSize: Theme.sizeTiny; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                    Small { anchors.centerIn: parent; visible: !page.hasHours; text: "Hours are kept from 2.7.1 on: this fills in as you use the PC" }
                }
                Box {
                    Rise {}
                    Layout.fillWidth: true
                    Layout.preferredHeight: weekList.implicitHeight + 56
                    Small { x: 18; y: 14; text: "The week's apps" }
                    AppList {
                        id: weekList
                        x: 8; y: 40; width: parent.width - 16
                        list: page.weekApps
                        total: page.weekTotals.reduce((a, b) => a + b, 0)
                        onPicked: id => { page.mode = "day"; page.app = id; }
                    }
                    Small { visible: page.weekApps.length === 0; anchors.horizontalCenter: parent.horizontalCenter; y: 40; text: "Nothing tracked this week" }
                }
            }
        }

        // ── settings (the gear) ──
        Flickable {
            id: setView
            visible: page.settingsOpen
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: setCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            SmoothWheel {}
            ColumnLayout {
                id: setCol
                width: setView.width
                spacing: 8
                SettingRow {
                    key: "wellbeing.track"; def: true;
                    icon: "self_improvement"; title: "Track screen time"; desc: "How long each app is focused, hour by hour (not while you're away). Kept six weeks, only on this PC"
                    Toggle { checked: Wellbeing.tracking; onToggled: on => Store.set("wellbeing.track", on) }
                }
                SettingRow {
                    key: "wellbeing.goal"; def: 0;
                    icon: "flag"; title: "Daily goal"; desc: "At most this much screen time a day: a notification when you reach it, and a bar under the total"
                    NumberBox { from: 0; to: 1440; slideTo: 720; step: 15; unit: " min"; zeroText: "None"; value: Wellbeing.goal; onMoved: v => Store.set("wellbeing.goal", v) }
                }
                Small { Layout.leftMargin: 6; Layout.topMargin: 6; text: "App limits" }
                SettingRow {
                    visible: Wellbeing.limits.length === 0
                    icon: "hourglass"; title: "No app limits yet"; desc: "Open an app from the list (Day) and set its daily limit there"
                }
                Repeater {
                    model: Wellbeing.limits
                    SettingRow {
                        id: lr
                        required property var modelData
                        // the app id with its dots back (limits are stored with _)
                        readonly property string appId: Object.keys(Wellbeing.days[Wellbeing.today] || {}).concat(...Object.values(Wellbeing.days).map(m => Object.keys(m))).find(a => a.replace(/\./g, "_") === modelData.key) || modelData.key
                        icon: "hourglass_top"; title: Wellbeing.nameOf(appId)
                        desc: "Today " + Wellbeing.fmt(Wellbeing.dayMap(Wellbeing.today)[appId] || 0) + " of " + Wellbeing.fmt(modelData.minutes * 60)
                        NumberBox { from: 0; to: 1440; slideTo: 480; step: 5; unit: " min"; zeroText: "None"; value: lr.modelData.minutes; onMoved: v => Wellbeing.setLimit(lr.appId, v) }
                    }
                }
                Small { Layout.leftMargin: 6; Layout.topMargin: 6; text: "Data" }
                SettingRow {
                    icon: "delete"; title: "Forget screen time"; desc: "Delete everything tracked so far (limits and the goal stay)"
                    Button { id: clr; property bool armed: false; text: armed ? "Sure?" : "Delete"; onClicked: { if (armed) { Wellbeing.clear(); armed = false; } else { armed = true; disarm.restart(); } } Timer { id: disarm; interval: 4000; onTriggered: clr.armed = false } }
                }
            }
        }
    }
}
