import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../"
import "../../reusables"

Popup {
    id: themeEditorPopup
    parent: rootObj ? rootObj : undefined
    x: parent && parent.width > 0 ? Math.max(0, Math.round((parent.width - width) / 2)) : 0
    y: parent && parent.height > 0 ? Math.max(0, Math.round((parent.height - height) / 2)) : 0
    modal: true
    dim: true
    width: rootObj ? Math.min(rootObj.width - rootObj.s(32), rootObj.s(680)) : 680
    padding: rootObj ? rootObj.s(20) : 20
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

    property var rootObj
    property real tileWidth: 0

    property string editingThemeName: ""
    property var currentColors: ({})
    // editing a built-in theme: its name stays, and the changes are kept apart from its own
    // colours (defaultColors), so each colour, or all of them, can go back to the theme's own
    property bool builtin: false
    property var defaultColors: ({})
    // the colours as the editor opened (a theme without, say, "sky" gets a stand-in for it: only
    // saved if you change it)
    property var openedColors: ({})
    function defaultOf(key) {
        return defaultColors[key] !== undefined ? String(defaultColors[key]) : "";
    }
    function isChanged(key) {
        let d = defaultOf(key);
        return d !== "" && String(currentColors[key] || "").toLowerCase() !== d.toLowerCase();
    }
    readonly property bool anyChanged: {
        let c = currentColors;
        for (let i = 0; i < colorKeys.length; i++) if (isChanged(colorKeys[i])) return true;
        return false;
    }
    function resetColor(key) {
        let c = Object.assign({}, currentColors);
        c[key] = defaultOf(key);
        currentColors = c;
    }
    function resetAll() {
        let c = Object.assign({}, currentColors);
        for (let i = 0; i < colorKeys.length; i++) if (defaultOf(colorKeys[i]) !== "") c[colorKeys[i]] = defaultOf(colorKeys[i]);
        currentColors = c;
    }

    readonly property var colorKeys: [
        "base", "mantle", "crust",
        "surface0", "surface1", "surface2",
        "overlay0", "overlay1", "overlay2",
        "subtext0", "subtext1", "text",
        "lavender", "blue", "sapphire", "sky", "teal", "green",
        "yellow", "peach", "maroon", "red", "mauve", "pink", "flamingo", "rosewater"
    ]

    readonly property var colorTranslationKeys: ({
        "surface0": "surf0",
        "surface1": "surf1",
        "surface2": "surf2",
        "overlay0": "over0",
        "overlay1": "over1",
        "overlay2": "over2",
        "subtext0": "sub0",
        "subtext1": "sub1"
    })

    signal saveRequested(var themeObj)
    // a built-in theme's edited colours: name, all colours, its own colours
    signal overrideRequested(string name, var colors, var defaults)

    function colorLabel(key) {
        let translationKey = colorTranslationKeys[key] || key;
        return I18n.t("guide.theme_editor.colors." + translationKey, key);
    }

    function openForNew() {
        builtin = false;
        defaultColors = {};
        editingThemeName = "";
        themeNameInput.text = "";

        let initial = {};
        for (let i = 0; i < colorKeys.length; i++) {
            let k = colorKeys[i];
            initial[k] = ThemeBackend[k] !== undefined
                ? ThemeBackend[k].toString()
                : "#000000";
        }

        currentColors = initial;
        open();
        themeNameInput.forceInputFocus();
    }

    function openForEdit(themeObj) {
        if (!themeObj) return;

        builtin = themeObj.isCustom !== true;
        // a built-in theme's own colours (without your changes); a custom theme has none to go back to
        defaultColors = builtin ? (themeObj.defaultColors || themeObj.colors || {}) : {};
        editingThemeName = themeObj.name || "";
        themeNameInput.text = editingThemeName;

        let initial = {};
        let src = themeObj.colors || {};

        for (let i = 0; i < colorKeys.length; i++) {
            let k = colorKeys[i];

            if (src[k] !== undefined) {
                initial[k] = src[k];
            } else {
                initial[k] = ThemeBackend[k] !== undefined
                    ? ThemeBackend[k].toString()
                    : "#000000";
            }
        }

        currentColors = initial;
        openedColors = Object.assign({}, initial);
        open();
        if (!builtin) themeNameInput.forceInputFocus();
    }

    function commitSave() {
        if (builtin) {
            let colors = {};
            for (let i = 0; i < colorKeys.length; i++) {
                let k = colorKeys[i];
                if (defaultColors[k] !== undefined || String(currentColors[k]).toLowerCase() !== String(openedColors[k]).toLowerCase())
                    colors[k] = currentColors[k];
            }
            themeEditorPopup.overrideRequested(editingThemeName, colors, defaultColors);
            close();
            return;
        }
        let name = themeNameInput.text.trim();

        if (!name) {
            themeNameInput.triggerShake();
            return;
        }

        let themeObj = {
            "name": name,
            "isCustom": true,
            "category": "user",
            "colors": currentColors
        };

        themeEditorPopup.saveRequested(themeObj);
        close();
    }

    Connections {
        target: themeEditorPopup.rootObj ? themeEditorPopup.rootObj : null

        function onVisibleChanged() {
            if (themeEditorPopup.rootObj && !themeEditorPopup.rootObj.visible) {
                themeEditorPopup.close();
            }
        }
    }

    Connections {
        target: themeEditorPopup.parent && themeEditorPopup.parent !== themeEditorPopup.rootObj
            ? themeEditorPopup.parent
            : null

        function onVisibleChanged() {
            if (themeEditorPopup.parent && !themeEditorPopup.parent.visible) {
                themeEditorPopup.close();
            }
        }
    }

    background: Rectangle {
        radius: ThemeBackend.rad(ThemeBackend.clampedBorderRadius)
        color: gf1.active ? "transparent" : ThemeBackend.base

        GlassFill {
            id: gf1
            anchors.fill: parent
            radius: ThemeBackend.rad(parent.radius)
            tintColor: ThemeBackend.base
            tintAmount: 0.25
        }
        border.color: ThemeBackend.surface0
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: rootObj ? rootObj.s(16) : 16

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: themeEditorPopup.builtin
                    ? "Edit " + themeEditorPopup.editingThemeName
                    : themeEditorPopup.editingThemeName === ""
                    ? I18n.t("guide.theme_editor.title", "Create Custom Theme")
                    : I18n.t("guide.theme_editor.edit_title", "Edit Custom Theme")

                color: ThemeBackend.text
                font.family: ThemeBackend.fontFamily
                font.pixelSize: rootObj ? rootObj.s(16) : 16
                font.bold: true
                Layout.fillWidth: true
            }

            CloseButton {
                size: rootObj ? rootObj.s(30) : 30
                cornerRadius: ThemeBackend.rad(rootObj ? rootObj.s(8) : 8)
                iconFontSize: rootObj ? rootObj.s(14) : 14
                onClicked: themeEditorPopup.close()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: rootObj ? rootObj.s(10) : 10

            // a built-in theme keeps its name
            Text {
                visible: themeEditorPopup.builtin
                Layout.fillWidth: true
                text: themeEditorPopup.anyChanged ? "Changed colours have ↺ to go back to the theme's own" : "Your changes are kept apart: the theme can always go back to its own colours"
                color: ThemeBackend.subtext0
                font.family: ThemeBackend.fontFamily
                font.pixelSize: rootObj ? rootObj.s(11) : 11
                wrapMode: Text.WordWrap
            }

            ClickButton {
                visible: themeEditorPopup.builtin && themeEditorPopup.anyChanged
                implicitHeight: rootObj ? rootObj.s(36) : 36
                horizontalPadding: rootObj ? rootObj.s(14) : 14
                cornerRadius: ThemeBackend.borderRadius
                buttonText: "↺  Reset all"
                textFontSize: rootObj ? rootObj.s(11) : 11
                accentColor: ThemeBackend.surface1
                textColor: ThemeBackend.text
                onClicked: themeEditorPopup.resetAll()
            }

            Input {
                id: themeNameInput
                visible: !themeEditorPopup.builtin
                Layout.fillWidth: true
                Layout.preferredHeight: rootObj ? rootObj.s(36) : 36

                placeholderText: I18n.t(
                    "guide.theme_editor.name_placeholder",
                    "Theme Name..."
                )

                baseColor: ThemeBackend.surface0
                accentColor: ThemeBackend.mauve
                textColor: ThemeBackend.text
                subTextColor: ThemeBackend.subtext0
                borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                cornerRadius: ThemeBackend.borderRadius
                fontPixelSize: rootObj ? rootObj.s(12) : 12
                onAccepted: themeEditorPopup.commitSave()
            }

            IconButton {
                size: rootObj ? rootObj.s(36) : 36
                Layout.preferredWidth: rootObj ? rootObj.s(36) : 36
                Layout.preferredHeight: rootObj ? rootObj.s(36) : 36
                cornerRadius: ThemeBackend.borderRadius
                buttonIcon: "󰄬"
                iconFontSize: rootObj ? rootObj.s(16) : 16
                accentColor: ThemeBackend.mauve
                textColor: ThemeBackend.crust
                onClicked: themeEditorPopup.commitSave()
            }
        }

        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: rootObj ? rootObj.s(320) : 320
            contentHeight: colorsGrid.implicitHeight
            contentWidth: width
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                width: rootObj ? rootObj.s(4) : 4
                policy: ScrollBar.AsNeeded

                contentItem: Rectangle {
                    radius: ThemeBackend.rad(rootObj ? rootObj.s(2) : 2)
                    color: ThemeBackend.surface2
                }
            }

            GridLayout {
                id: colorsGrid
                width: parent.width - (rootObj ? rootObj.s(8) : 8)
                columns: 2
                rowSpacing: rootObj ? rootObj.s(8) : 8
                columnSpacing: rootObj ? rootObj.s(12) : 12

                Repeater {
                    model: themeEditorPopup.colorKeys

                    delegate: RowLayout {
                        Layout.fillWidth: true
                        spacing: rootObj ? rootObj.s(8) : 8

                        Rectangle {
                            Layout.preferredWidth: rootObj ? rootObj.s(28) : 28
                            Layout.preferredHeight: rootObj ? rootObj.s(28) : 28
                            radius: ThemeBackend.rad(rootObj ? rootObj.s(6) : 6)
                            color: themeEditorPopup.currentColors[modelData] || "#000000"
                            border.width: 1
                            border.color: Qt.alpha(ThemeBackend.surface2, 0.6)
                        }

                        Text {
                            text: themeEditorPopup.colorLabel(modelData)
                            color: ThemeBackend.text
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj ? rootObj.s(12) : 12
                            Layout.preferredWidth: rootObj ? rootObj.s(80) : 80
                            elide: Text.ElideRight
                        }

                        Input {
                            Layout.fillWidth: true
                            Layout.preferredHeight: rootObj ? rootObj.s(28) : 28
                            text: themeEditorPopup.currentColors[modelData] || ""
                            baseColor: ThemeBackend.surface0
                            accentColor: ThemeBackend.mauve
                            textColor: ThemeBackend.text
                            subTextColor: ThemeBackend.subtext0
                            borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                            cornerRadius: ThemeBackend.rad(rootObj ? rootObj.s(6) : 6)
                            fontPixelSize: rootObj ? rootObj.s(11) : 11

                            onTextEdited: newText => {
                                let c = Object.assign({}, themeEditorPopup.currentColors);
                                c[modelData] = newText;
                                themeEditorPopup.currentColors = c;
                            }
                        }

                        // back to the theme's own colour
                        IconButton {
                            visible: themeEditorPopup.isChanged(modelData)
                            size: rootObj ? rootObj.s(28) : 28
                            Layout.preferredWidth: rootObj ? rootObj.s(28) : 28
                            Layout.preferredHeight: rootObj ? rootObj.s(28) : 28
                            cornerRadius: ThemeBackend.rad(rootObj ? rootObj.s(6) : 6)
                            buttonIcon: "󰑓"
                            iconFontSize: rootObj ? rootObj.s(13) : 13
                            accentColor: ThemeBackend.surface1
                            textColor: ThemeBackend.text
                            onClicked: themeEditorPopup.resetColor(modelData)
                        }
                    }
                }
            }
        }
    }
}
