import QtQuick
import "../../core"
import "../../ui"

// A picture in a circle, cropped to fill it (PictureFrame). GIFs play.
FaceBase {
    id: face
    PictureFrame { face: face; shape: "circle" }
}
