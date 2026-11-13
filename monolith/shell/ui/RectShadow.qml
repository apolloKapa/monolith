import QtQuick
import QtQuick.Effects

// A rounded-rectangle shadow drawn by a shader (Qt 6.9+). Only ever loaded by URL (CardShadow,
// IslandShape): on an older Qt this type doesn't exist, and naming it in those files would stop
// them (and the shell) from loading. Theme.rectShadows says whether it's there.
RectangularShadow {}
