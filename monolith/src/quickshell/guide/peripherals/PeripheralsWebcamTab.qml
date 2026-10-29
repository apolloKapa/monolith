import QtQuick
import QtQuick.Layouts
import QtMultimedia
import "../"
import "../../"
import "../../reusables"
import "../../reusables/guide"

// Settings -> Peripherals -> Webcam: the cameras Qt Multimedia finds, with a preview to check
// one works and how it looks. The camera is opened only after "Show preview" and closed again
// as soon as you leave the page (Settings loads every page in the background for search, so
// nothing here may touch the camera on its own).
GuideTab {
    id: camTab

    readonly property var cameras: devices.videoInputs
    property int chosen: 0
    readonly property var camera: cameras.length > 0 ? cameras[Math.min(chosen, cameras.length - 1)] : null
    property bool previewing: false
    property bool mirrored: true

    onIsCurrentChanged: if (!isCurrent) previewing = false
    onCamerasChanged: if (cameras.length === 0) previewing = false

    MediaDevices { id: devices }

    Flickable {
        anchors.fill: parent
        anchors.topMargin: rootObj.s(8)
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        anchors.bottomMargin: rootObj.s(4)
        contentHeight: col.implicitHeight
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: col
            width: parent.width
            spacing: rootObj.s(6)

            SettingsBlob {
                Layout.fillWidth: true

                SettingsRow {
                    rootObj: camTab.rootObj
                    settingId: "webcam_device"
                    icon: "󰖠"
                    title: "Webcam"
                    description: camTab.cameras.length === 0
                        ? "No webcam found. Plug one in and it shows up here"
                        : camTab.cameras.length === 1 ? camTab.cameras[0].description
                        : "Pick one to preview"
                    searchKeywords: "webcam camera video cam preview test face"

                    Dropdown {
                        visible: camTab.cameras.length > 1
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitWidth: rootObj.s(240)
                        implicitHeight: rootObj.s(32)
                        options: camTab.cameras.map(c => c.description)
                        currentIndex: camTab.chosen
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface0
                        onValueChanged: function(index, value) { camTab.chosen = index; }
                    }

                    ClickButton {
                        visible: camTab.cameras.length > 0
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitHeight: rootObj.s(32)
                        horizontalPadding: rootObj.s(14)
                        cornerRadius: ThemeBackend.borderRadius
                        buttonText: camTab.previewing ? "Stop preview" : "Show preview"
                        textFontSize: rootObj.s(11)
                        accentColor: camTab.previewing ? ThemeBackend.surface1 : ThemeBackend.mauve
                        textColor: camTab.previewing ? ThemeBackend.text : ThemeBackend.crust
                        onClicked: camTab.previewing = !camTab.previewing
                    }
                }

                SettingsRow {
                    rootObj: camTab.rootObj
                    visible: camTab.cameras.length > 0
                    settingId: "webcam_mirror"
                    icon: "󰯌"
                    title: "Mirror the preview"
                    description: "Show it like a mirror. Only the preview here: others always see you the right way round"
                    searchKeywords: "webcam camera mirror flip preview"

                    Toggle {
                        checked: camTab.mirrored
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(c) { camTab.mirrored = c; }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(width * 9 / 16, rootObj.s(420))
                visible: camTab.previewing
                radius: ThemeBackend.rad(ThemeBackend.borderRadius)
                color: ThemeBackend.crust
                clip: true

                // made only while previewing: the camera light goes off with it
                Loader {
                    anchors.fill: parent
                    active: camTab.previewing && camTab.camera !== null

                    sourceComponent: Item {
                        Camera {
                            id: cam
                            cameraDevice: camTab.camera
                            active: true
                        }
                        CaptureSession {
                            camera: cam
                            videoOutput: view
                        }
                        VideoOutput {
                            id: view
                            anchors.fill: parent
                            fillMode: VideoOutput.PreserveAspectFit
                            transform: Scale {
                                origin.x: view.width / 2
                                xScale: camTab.mirrored ? -1 : 1
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            width: parent.width - rootObj.s(40)
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            visible: cam.error !== Camera.NoError
                            text: "Couldn't open the camera: " + cam.errorString
                                + "\nAnother app may be using it."
                            color: ThemeBackend.subtext0
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(12)
                        }
                    }
                }
            }
        }
    }
}
