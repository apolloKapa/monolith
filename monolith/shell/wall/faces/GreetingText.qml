import QtQuick
import Quickshell
import "../../core"
import "../../ui"

// Greeting: good morning/afternoon/evening with your name, and what's waiting.
FaceBase {
    id: f
    readonly property int h: f.now.getHours()
    Column {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        Inked { width: parent.width; height: f.height * 0.58; font.weight: Font.Black; font.pixelSize: height; fontSizeMode: Text.Fit; verticalAlignment: Text.AlignBottom
            text: (f.h < 5 ? "Good night" : f.h < 12 ? "Good morning" : f.h < 18 ? "Good afternoon" : "Good evening") + ", " + (Quickshell.env("USER") || "") }
        Inked { width: parent.width; height: f.height * 0.3; color: Theme.subtext; font.weight: Font.Bold; font.pixelSize: height; fontSizeMode: Text.Fit
            text: Notifs.list.length > 0 ? Notifs.list.length + " notifications waiting" : "Nothing waiting" }
    }
}
