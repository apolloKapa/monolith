import QtQuick
import Quickshell
import "."

Scope {
    id: runnerRoot

    property string targetFile: Quickshell.env("MONOLITH_TARGET_FILE") || ""

    Loader {
        active: runnerRoot.targetFile !== ""
        source: runnerRoot.targetFile
    }
}
