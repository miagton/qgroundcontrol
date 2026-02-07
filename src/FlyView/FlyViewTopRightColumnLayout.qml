import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView
import QGroundControl.FlightMap

ColumnLayout {
    spacing: ScreenTools.defaultFontPixelHeight / 2

    TerrainProgress {
        Layout.fillWidth: true
    }

    // Show PhotoVideoControl when either:
    // 1. Vehicle with camera manager is connected (for MAVLink camera control)
    // 2. Video streaming is available (for RTSP/UDP recording without vehicle)
    Loader {
        id:                 photoVideoControlLoader
        Layout.alignment:   Qt.AlignRight
        sourceComponent:    (globals.activeVehicle && globals.activeVehicle.cameraManager) || QGroundControl.videoManager.hasVideo ? photoVideoControlComponent : undefined

        property real rightEdgeCenterInset: visible ? parent.width - x : 0

        Component {
            id: photoVideoControlComponent

            PhotoVideoControl {
            }
        }
    }
}
