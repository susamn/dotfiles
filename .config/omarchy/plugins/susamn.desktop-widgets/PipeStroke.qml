import QtQuick
import QtQuick.Shapes

// One flat stroked polyline. `dx`/`dy` offset it (unused now — kept for
// tweaking).
Shape {
  id: s

  property var pts: []
  property real dx: 0
  property real dy: 0
  property real w: 4
  property color col: "white"

  x: dx
  y: dy
  width: parent ? parent.width : 0
  height: parent ? parent.height : 0
  antialiasing: true

  ShapePath {
    strokeColor: s.col
    strokeWidth: s.w
    fillColor: "transparent"
    capStyle: ShapePath.FlatCap
    joinStyle: ShapePath.RoundJoin
    PathPolyline { path: s.pts }
  }
}
