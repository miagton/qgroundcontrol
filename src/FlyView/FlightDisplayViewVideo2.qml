import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.FlyView
import QGroundControl.FlightMap
import QGroundControl.Controls
import org.freedesktop.gstreamer.Qt6GLVideoItem

Item {
    id:     root
    clip:   true

    property bool useSmallFont: true

    property double _ar:                16.0 / 9.0  // Default aspect ratio
    property bool   _showGrid:          QGroundControl.settingsManager.videoSettings.gridLines.rawValue
    property var    _dynamicCameras:    globals.activeVehicle ? globals.activeVehicle.cameraManager : null
    property bool   _connected:         globals.activeVehicle ? !globals.activeVehicle.communicationLost : false
    property int    _curCameraIndex:    _dynamicCameras ? _dynamicCameras.currentCamera : 0
    property bool   _isCamera:          _dynamicCameras ? _dynamicCameras.cameras.count > 0 : false
    property var    _camera:            _isCamera ? _dynamicCameras.cameras.get(_curCameraIndex) : null
    property bool   _hasZoom:           _camera && _camera.hasZoom
    property int    _fitMode:           QGroundControl.settingsManager.videoSettings.videoFit.rawValue

    property bool   _isMode_FIT_WIDTH:  _fitMode === 0
    property bool   _isMode_FIT_HEIGHT: _fitMode === 1
    property bool   _isMode_FILL:       _fitMode === 2
    property bool   _isMode_NO_CROP:    _fitMode === 3

    property bool   _streamEnabled:     QGroundControl.settingsManager.videoSettings.streamEnabled2.rawValue &&
                                        QGroundControl.settingsManager.videoSettings.rtspUrl2.rawValue !== "" &&
                                        QGroundControl.settingsManager.videoSettings.rtspUrl2.rawValue.toLowerCase().startsWith("rtsp://")

    property double _thermalHeightFactor: 0.85

    Component.onCompleted: {
        console.log("FlightDisplayViewVideo2: Stream enabled:", _streamEnabled)
        console.log("FlightDisplayViewVideo2: streamEnabled2:", QGroundControl.settingsManager.videoSettings.streamEnabled2.rawValue)
        console.log("FlightDisplayViewVideo2: rtspUrl2:", QGroundControl.settingsManager.videoSettings.rtspUrl2.rawValue)
    }

    Connections {
        target: QGroundControl.settingsManager.videoSettings.streamEnabled2
        function onRawValueChanged() {
            console.log("FlightDisplayViewVideo2: Stream enabled changed to:", _streamEnabled)
        }
    }

    Image {
        id:             noVideo
        anchors.fill:   parent
        source:         "/res/NoVideoBackground.jpg"
        fillMode:       Image.PreserveAspectCrop
        visible:        !_streamEnabled  // Show when stream is not enabled or not decoding

        Rectangle {
            anchors.centerIn:   parent
            width:              noVideoLabel.contentWidth + ScreenTools.defaultFontPixelHeight
            height:             noVideoLabel.contentHeight + ScreenTools.defaultFontPixelHeight
            radius:             ScreenTools.defaultFontPixelHeight * 0.5
            color:              Qt.rgba(0,0,0,0.75)
            visible:            noVideo.visible

            QGCLabel {
                id:                 noVideoLabel
                text:               "STREAM 2"
                color:              "white"
                font.pointSize:     ScreenTools.largeFontPointSize
                anchors.centerIn:   parent
            }
        }
    }

    Rectangle {
        id:                 videoBackground
        anchors.centerIn:   parent
        color:              "black"
        visible:            true
        width:              getWidth()
        height:             getHeight()

        function getWidth() {
            if(_isMode_FIT_WIDTH || _isMode_FILL) {
                return parent.width
            }
            //-- Fit Height or No Crop
            var ar_ = _ar
            if(_ar < 0.01) {
                ar_ = 1.777777
            }
            return parent.height * ar_
        }

        function getHeight() {
            if(_isMode_FIT_HEIGHT || _isMode_FILL) {
                return parent.height
            }
            //-- Fit Width or No Crop
            var ar_ = _ar
            if(_ar < 0.01) {
                ar_ = 1.777777
            }
            return parent.width / ar_
        }

        //-- Video Placeholder
        Rectangle {
            anchors.fill:       parent
            color:              "black"

            Loader {
                id:             videoContent2Loader
                anchors.fill:   parent
                active:         _streamEnabled && QGroundControl.videoManager.gstreamerEnabled
                sourceComponent: Component {
                    GstGLQt6VideoItem {
                        id:         videoContent2
                        objectName: "videoContent2"
                    }
                }
            }
        }
    }
}

