import QtQuick
import "../../core"
import "../../ui"

// A picture shown whole, with square corners (PictureFrame). GIFs play.
FaceBase {
    id: face
    PictureFrame { face: face; shape: "square" }
}
