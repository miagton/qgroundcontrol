import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.FlyView
import QGroundControl.FlightMap
import QGroundControl.Controls

Item {
    id:     root
    clip:   true

    // ========== Configurable Properties for Multi-Stream Support ==========
    // streamIndex: 0 = primary (videoContent), 1 = stream2 (videoContent2), 2 = stream3 (videoContent3)
    property int    streamIndex:        0
    property string videoContentName:   streamIndex === 0 ? "videoContent" : ("videoContent" + (streamIndex + 1))

    // Stream-specific settings based on streamIndex
    property bool   _streamEnabled: {
        if (streamIndex === 0) return QGroundControl.settingsManager.videoSettings.streamEnabled.rawValue
        if (streamIndex === 1) return QGroundControl.settingsManager.videoSettings.streamEnabled2.rawValue
        if (streamIndex === 2) return QGroundControl.settingsManager.videoSettings.streamEnabled3.rawValue
        return false
    }
    property string _streamUrl: {
        if (streamIndex === 0) return QGroundControl.settingsManager.videoSettings.rtspUrl.rawValue
        if (streamIndex === 1) return QGroundControl.settingsManager.videoSettings.rtspUrl2.rawValue
        if (streamIndex === 2) return QGroundControl.settingsManager.videoSettings.rtspUrl3.rawValue
        return ""
    }
    property bool   _streamConfigured:  _streamEnabled && _streamUrl.length > 0
    property string _streamLabel:       streamIndex === 0 ? qsTr("VIDEO") : qsTr("STREAM %1").arg(streamIndex + 1)

    // Per-stream decoding status tracking
    property bool   _isDecoding:        QGroundControl.videoManager.isStreamDecoding(streamIndex)

    Component.onCompleted: {
        console.log("FlightDisplayViewVideo initialized:")
        console.log("  - streamIndex:", streamIndex)
        console.log("  - videoContentName:", videoContentName)
        console.log("  - _streamEnabled:", _streamEnabled)
        console.log("  - _streamUrl:", _streamUrl)
        console.log("  - _streamConfigured:", _streamConfigured)
    }

    // ========== Common Properties ==========
    property bool useSmallFont: true

    property double _ar:                QGroundControl.videoManager.gstreamerEnabled
                                            ? QGroundControl.videoManager.videoSize.width / QGroundControl.videoManager.videoSize.height
                                            : QGroundControl.videoManager.aspectRatio
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

    function getWidth() {
        return videoBackground.getWidth()
    }
    function getHeight() {
        return videoBackground.getHeight()
    }

    property double _thermalHeightFactor: 0.85

    // Video background with GstGLQt6VideoItem - ALWAYS visible so VideoManager can bind to it
    Rectangle {
        id:             videoBackground
        anchors.fill:   parent
        color:          "black"
        z:              0  // Behind the noVideo image

        function getWidth() {
            if(_ar != 0.0){
                if(_isMode_FIT_HEIGHT
                        || (_isMode_FILL && (root.width/root.height < _ar))
                        || (_isMode_NO_CROP && (root.width/root.height > _ar))){
                    return root.height * _ar
                }
            }
            return root.width
        }
        function getHeight() {
            if(_ar != 0.0){
                if(_isMode_FIT_WIDTH
                        || (_isMode_FILL && (root.width/root.height > _ar))
                        || (_isMode_NO_CROP && (root.width/root.height < _ar))){
                    return root.width * (1 / _ar)
                }
            }
            return root.height
        }

        // Video content with dynamic objectName based on streamIndex
        QGCVideoBackground {
            id:             videoContent
            objectName:     root.videoContentName
            height:         parent.getHeight()
            width:          parent.getWidth()
            anchors.centerIn: parent

            Connections {
                target: QGroundControl.videoManager
                enabled: root.streamIndex === 0  // Only primary stream handles screenshot
                function onImageFileChanged(filename) {
                    videoContent.grabToImage(function(result) {
                        if (!result.saveToFile(filename)) {
                            console.error('Error capturing video frame');
                        }
                    });
                }
            }

            // Grid overlay - only for primary stream
            Rectangle {
                color:  Qt.rgba(1,1,1,0.5)
                height: parent.height
                width:  1
                x:      parent.width * 0.33
                visible: root.streamIndex === 0 && _showGrid && !QGroundControl.videoManager.fullScreen
            }
            Rectangle {
                color:  Qt.rgba(1,1,1,0.5)
                height: parent.height
                width:  1
                x:      parent.width * 0.66
                visible: root.streamIndex === 0 && _showGrid && !QGroundControl.videoManager.fullScreen
            }
            Rectangle {
                color:  Qt.rgba(1,1,1,0.5)
                width:  parent.width
                height: 1
                y:      parent.height * 0.33
                visible: root.streamIndex === 0 && _showGrid && !QGroundControl.videoManager.fullScreen
            }
            Rectangle {
                color:  Qt.rgba(1,1,1,0.5)
                width:  parent.width
                height: 1
                y:      parent.height * 0.66
                visible: root.streamIndex === 0 && _showGrid && !QGroundControl.videoManager.fullScreen
            }
        }

        //-- Thermal Image (only for primary stream)
        Item {
            id:                 thermalItem
            visible:            root.streamIndex === 0 && QGroundControl.videoManager.hasThermal && _camera && _camera.thermalMode !== MavlinkCameraControl.THERMAL_OFF
            width:              height * QGroundControl.videoManager.thermalAspectRatio
            height:             _camera ? (_camera.thermalMode === MavlinkCameraControl.THERMAL_FULL ? parent.height : (_camera.thermalMode === MavlinkCameraControl.THERMAL_PIP ? ScreenTools.defaultFontPixelHeight * 12 : parent.height * _thermalHeightFactor)) : 0
            anchors.centerIn:   parent

            function pipOrNot() {
                if(_camera) {
                    if(_camera.thermalMode === MavlinkCameraControl.THERMAL_PIP) {
                        anchors.centerIn    = undefined
                        anchors.top         = parent.top
                        anchors.topMargin   = mainWindow.header.height + (ScreenTools.defaultFontPixelHeight * 0.5)
                        anchors.left        = parent.left
                        anchors.leftMargin  = ScreenTools.defaultFontPixelWidth * 12
                    } else {
                        anchors.top         = undefined
                        anchors.topMargin   = undefined
                        anchors.left        = undefined
                        anchors.leftMargin  = undefined
                        anchors.centerIn    = parent
                    }
                }
            }
            Connections {
                target:                 _camera
                function onThermalModeChanged() { thermalItem.pipOrNot() }
            }
            onVisibleChanged: {
                thermalItem.pipOrNot()
            }
            QGCVideoBackground {
                id:             thermalVideo
                objectName:     "thermalVideo"
                anchors.fill:   parent
                opacity:        _camera ? (_camera.thermalMode === MavlinkCameraControl.THERMAL_BLEND ? _camera.thermalOpacity / 100 : 1.0) : 0
            }
        }

        //-- Zoom (only for primary stream with camera)
        PinchArea {
            id:             pinchZoom
            enabled:        root.streamIndex === 0 && _hasZoom
            anchors.fill:   parent
            onPinchStarted: pinchZoom.zoom = 0
            onPinchUpdated: {
                if(_hasZoom) {
                    var z = 0
                    if(pinch.scale < 1) {
                        z = Math.round(pinch.scale * -10)
                    } else {
                        z = Math.round(pinch.scale)
                    }
                    if(pinchZoom.zoom != z) {
                        _camera.stepZoom(z)
                    }
                }
            }
            property int zoom: 0
        }
    }

    // "Waiting for video" landscape image - shows on top when not decoding
    Image {
        id:             noVideo
        anchors.fill:   parent
        source:         "/res/NoVideoBackground.jpg"
        fillMode:       Image.PreserveAspectCrop
        visible:        !_isDecoding
        z:              1  // On top of video background

        Rectangle {
            anchors.centerIn:   parent
            width:              noVideoLabel.contentWidth + ScreenTools.defaultFontPixelHeight
            height:             noVideoLabel.contentHeight + ScreenTools.defaultFontPixelHeight
            radius:             ScreenTools.defaultFontPixelWidth / 2
            color:              "black"
            opacity:            0.5
        }

        QGCLabel {
            id:                 noVideoLabel
            text:               _streamEnabled ? qsTr("WAITING FOR %1").arg(_streamLabel) : qsTr("%1 DISABLED").arg(_streamLabel)
            font.bold:          true
            color:              "white"
            font.pointSize:     useSmallFont ? ScreenTools.smallFontPointSize : ScreenTools.largeFontPointSize
            anchors.centerIn:   parent
        }
    }
}

