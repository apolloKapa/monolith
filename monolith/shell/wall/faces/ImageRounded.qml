import QtQuick
import "../../core"
import "../../ui"

// A picture shown whole, its corners rounded like the theme's (PictureFrame). GIFs play.
FaceBase {
    id: face
    PictureFrame { face: face; shape: "rounded" }
}
