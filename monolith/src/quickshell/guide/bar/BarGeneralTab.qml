import QtQuick
import QtQuick.Layouts
import "general"
import "../../"

BarGeneralState {
    id: barTabRoot

    onVisibleChanged: {
        if (visible) {
            syncSettings();
            loadModuleModels();
        } else {
            clearPendingGroup();
            if (placementSection.barPosDropdown.isOpen) placementSection.barPosDropdown.closePopup();
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.topMargin: rootObj.s(8)
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        anchors.bottomMargin: rootObj.s(8)
        contentHeight: settingsCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        onMovementStarted: {
            barTabRoot.clearPendingGroup();
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: {
                barTabRoot.clearPendingGroup();
            }
        }

        ColumnLayout {
            id: settingsCol
            width: parent.width
            spacing: rootObj.s(6)

            // live preview of the bar as the settings below describe it
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: livePreview.height + rootObj.s(24)
                radius: ThemeBackend.square ? 0 : ThemeBackend.borderRadius
                color: Qt.alpha(ThemeBackend.surface0, 0.4)

                BarPreview {
                    id: livePreview
                    anchors.centerIn: parent
                    width: Math.min(parent.width - rootObj.s(24), rootObj.s(520), rootObj.s(240) * screenW / screenH)
                    height: implicitHeight
                    style: barTabRoot.barStyle
                    position: barTabRoot.barPosition
                    widthPct: barTabRoot.currentBarWidth
                    thickness: barTabRoot.currentBarThickness
                    pillGap: barTabRoot.pillGap
                    sectionGap: barTabRoot.sectionGap
                    frameThickness: barTabRoot.frameThickness
                    distinctPills: barTabRoot.distinctPills
                    autohide: barTabRoot.autohide
                }
            }

            BarPlacementSection { id: placementSection; tab: barTabRoot }

            BarStyleSection { tab: barTabRoot }

            BarSpacingSection { tab: barTabRoot }

            BarAutohideSection { tab: barTabRoot }

            BarLayoutEditor { tab: barTabRoot }
        }
    }
}
