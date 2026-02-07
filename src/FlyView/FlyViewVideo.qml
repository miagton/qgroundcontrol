import QtQuick

import QGroundControl
import QGroundControl.Controls

Item {
    id: _root

    // ========== Configurable Properties for Multi-Stream Support ==========
    property int    streamIndex:    0   // 0 = primary, 1 = stream2, 2 = stream3
    property Item   pipView
    property Item   pipState:       videoPipState
    property alias  hdsdButton:     qualityButtonBackground2  // Expose button for PipView exclusion
    property bool   _isTogglingQuality: false  // Track if quality toggle is in progress

    // Only primary stream controls VideoManager start/stop
    property bool   _isPrimaryStream: streamIndex === 0

    property int    _track_rec_x:   0
    property int    _track_rec_y:   0

    PipState {
        id:         videoPipState
        pipView:    _root.pipView
        isDark:     true

        onWindowAboutToOpen: {
            if (_isPrimaryStream) {
                QGroundControl.videoManager.stopVideo()
                videoStartDelay.start()
            }
        }

        onWindowAboutToClose: {
            if (_isPrimaryStream) {
                QGroundControl.videoManager.stopVideo()
                videoStartDelay.start()
            }
        }

        onStateChanged: {
            if (_isPrimaryStream && pipState.state !== pipState.fullState) {
                QGroundControl.videoManager.fullScreen = false
            }
        }
    }

    Timer {
        id:           videoStartDelay
        interval:     2000
        running:      false
        repeat:       false
        onTriggered:  {
            if (_isPrimaryStream) {
                QGroundControl.videoManager.startVideo()
            }
        }
    }

    //-- Video Streaming
    FlightDisplayViewVideo {
        id:             videoStreaming
        anchors.fill:   parent
        streamIndex:    _root.streamIndex
        useSmallFont:   _root.pipState.state !== _root.pipState.fullState
        visible:        _isPrimaryStream ? QGroundControl.videoManager.isStreamSource : true
    }

    //-- UVC Video (USB Camera or Video Device) - only for primary stream
    Loader {
        id:             cameraLoader
        anchors.fill:   parent
        visible:        _isPrimaryStream && QGroundControl.videoManager.isUvc
        active:         _isPrimaryStream
        source:         QGroundControl.videoManager.uvcEnabled ? "qrc:/qml/QGroundControl/FlyView/FlightDisplayViewUVC.qml" : "qrc:/qml/QGroundControl/FlyView//FlightDisplayViewDummy.qml"
    }

    QGCLabel {
        text: qsTr("Double-click to exit full screen")
        font.pointSize: ScreenTools.largeFontPointSize
        visible: _isPrimaryStream && QGroundControl.videoManager.fullScreen && flyViewVideoMouseArea.containsMouse
        anchors.centerIn: parent

        onVisibleChanged: {
            if (visible) {
                labelAnimation.start()
            }
        }

        PropertyAnimation on opacity {
            id: labelAnimation
            duration: 10000
            from: 1.0
            to: 0.0
            easing.type: Easing.InExpo
        }
    }

    // Gimbal controller - only for primary stream
    OnScreenGimbalController {
        id:                      onScreenGimbalController
        anchors.fill:            parent
        visible:                 _isPrimaryStream
        screenX:                 flyViewVideoMouseArea.mouseX
        screenY:                 flyViewVideoMouseArea.mouseY
        cameraTrackingEnabled:   _isPrimaryStream && videoStreaming._camera && videoStreaming._camera.trackingEnabled
    }

    MouseArea {
        id:                         flyViewVideoMouseArea
        anchors.fill:               parent
        enabled:                    pipState.state === pipState.fullState
        hoverEnabled:               true
        propagateComposedEvents:    true  // Allow child MouseAreas to handle events first

        property double x0:         0
        property double x1:         0
        property double y0:         0
        property double y1:         0
        property double offset_x:   0
        property double offset_y:   0
        property double radius:     20
        property var trackingROI:   null
        property var trackingStatus: _isPrimaryStream ? trackingStatusComponent.createObject(flyViewVideoMouseArea, {}) : null

        onClicked: (mouse) => {
            if (_isPrimaryStream) onScreenGimbalController.clickControl()
        }

        onDoubleClicked: (mouse) => {
            if (_isPrimaryStream) QGroundControl.videoManager.fullScreen = !QGroundControl.videoManager.fullScreen
        }

        onPressed:(mouse) => {
            if (!_isPrimaryStream) return
            onScreenGimbalController.pressControl()

            _track_rec_x = mouse.x
            _track_rec_y = mouse.y

            //create a new rectangle at the wanted position
            if(videoStreaming._camera) {
                if (videoStreaming._camera.trackingEnabled) {
                    trackingROI = trackingROIComponent.createObject(flyViewVideoMouseArea, {
                        "x": mouse.x,
                        "y": mouse.y
                    });
                }
            }
        }
        onPositionChanged: (mouse) => {
            if (!_isPrimaryStream) return
            //on move, update the width of rectangle
            if (trackingROI !== null) {
                if (mouse.x < trackingROI.x) {
                    trackingROI.x = mouse.x
                    trackingROI.width = Math.abs(mouse.x - _track_rec_x)
                } else {
                    trackingROI.width = Math.abs(mouse.x - trackingROI.x)
                }
                if (mouse.y < trackingROI.y) {
                    trackingROI.y = mouse.y
                    trackingROI.height = Math.abs(mouse.y - _track_rec_y)
                } else {
                    trackingROI.height = Math.abs(mouse.y - trackingROI.y)
                }
            }
        }
        onReleased: (mouse) => {
            if (!_isPrimaryStream) return
            onScreenGimbalController.releaseControl()

            //if there is already a selection, delete it
            if (trackingROI !== null) {
                trackingROI.destroy();
            }

            if(videoStreaming._camera) {
                if (videoStreaming._camera.trackingEnabled) {
                    // order coordinates --> top/left and bottom/right
                    x0 = Math.min(_track_rec_x, mouse.x)
                    x1 = Math.max(_track_rec_x, mouse.x)
                    y0 = Math.min(_track_rec_y, mouse.y)
                    y1 = Math.max(_track_rec_y, mouse.y)

                    //calculate offset between video stream rect and background (black stripes)
                    offset_x = (parent.width - videoStreaming.getWidth()) / 2
                    offset_y = (parent.height - videoStreaming.getHeight()) / 2

                    //convert absolute coords in background to absolute video stream coords
                    x0 = x0 - offset_x
                    x1 = x1 - offset_x
                    y0 = y0 - offset_y
                    y1 = y1 - offset_y

                    //convert absolute to relative coordinates and limit range to 0...1
                    x0 = Math.max(Math.min(x0 / videoStreaming.getWidth(), 1.0), 0.0)
                    x1 = Math.max(Math.min(x1 / videoStreaming.getWidth(), 1.0), 0.0)
                    y0 = Math.max(Math.min(y0 / videoStreaming.getHeight(), 1.0), 0.0)
                    y1 = Math.max(Math.min(y1 / videoStreaming.getHeight(), 1.0), 0.0)

                    //use point message if rectangle is very small
                    if (Math.abs(_track_rec_x - mouse.x) < 10 && Math.abs(_track_rec_y - mouse.y) < 10) {
                        var pt  = Qt.point(x0, y0)
                        videoStreaming._camera.startTracking(pt, radius / videoStreaming.getWidth())
                    } else {
                        var rec = Qt.rect(x0, y0, x1 - x0, y1 - y0)
                        videoStreaming._camera.startTracking(rec)
                    }
                    _track_rec_x = 0
                    _track_rec_y = 0
                }
            }
        }

        Component {
            id: trackingROIComponent

            Rectangle {
                color:              Qt.rgba(0.1,0.85,0.1,0.25)
                border.color:       "green"
                border.width:       1
            }
        }

        Component {
            id: trackingStatusComponent

            Rectangle {
                color:              "transparent"
                border.color:       "red"
                border.width:       5
                radius:             5
            }
        }

        Timer {
            id: trackingStatusTimer
            interval:               50
            repeat:                 true
            running:                _isPrimaryStream
            onTriggered: {
                if (!_isPrimaryStream) return
                if (videoStreaming._camera) {
                    if (videoStreaming._camera.trackingEnabled && videoStreaming._camera.trackingImageStatus) {
                        var margin_hor = (parent.parent.width - videoStreaming.getWidth()) / 2
                        var margin_ver = (parent.parent.height - videoStreaming.getHeight()) / 2
                        var left = margin_hor + videoStreaming.getWidth() * videoStreaming._camera.trackingImageRect.left
                        var top = margin_ver + videoStreaming.getHeight() * videoStreaming._camera.trackingImageRect.top
                        var right = margin_hor + videoStreaming.getWidth() * videoStreaming._camera.trackingImageRect.right
                        var bottom = margin_ver + !isNaN(videoStreaming._camera.trackingImageRect.bottom) ? videoStreaming.getHeight() * videoStreaming._camera.trackingImageRect.bottom : top + (right - left)
                        var width = right - left
                        var height = bottom - top

                        flyViewVideoMouseArea.trackingStatus.x = left
                        flyViewVideoMouseArea.trackingStatus.y = top
                        flyViewVideoMouseArea.trackingStatus.width = width
                        flyViewVideoMouseArea.trackingStatus.height = height
                    } else {
                        flyViewVideoMouseArea.trackingStatus.x = 0
                        flyViewVideoMouseArea.trackingStatus.y = 0
                        flyViewVideoMouseArea.trackingStatus.width = 0
                        flyViewVideoMouseArea.trackingStatus.height = 0
                    }
                }
            }
        }
    }

    // Proximity radar - only for primary stream
    ProximityRadarVideoView {
        anchors.fill:   parent
        visible:        _isPrimaryStream
        vehicle:        QGroundControl.multiVehicleManager.activeVehicle
    }

    // Obstacle distance overlay - only for primary stream
    ObstacleDistanceOverlayVideo {
        id: obstacleDistance
        visible: _isPrimaryStream
        showText: pipState.state === pipState.fullState
    }

    // HD/SD quality toggle button - MUST BE LAST to be on top of everything
    Rectangle {
        id:                 qualityButtonBackground2
        z:                  10000  // Maximum z-order to be on top

        // Fixed explicit size - NO anchors.fill on parent to prevent stretching
        property bool _isFullScreen: pipState.state === pipState.fullState

        // Explicit FIXED width and height - no implicit sizing, smaller in PIP mode
        implicitWidth:      0  // Disable implicit sizing
        implicitHeight:     0  // Disable implicit sizing
        width:              _isFullScreen ? (ScreenTools.defaultFontPixelHeight * 2.5) : (ScreenTools.defaultFontPixelHeight * 1.8)
        height:             _isFullScreen ? (ScreenTools.defaultFontPixelHeight * 2.5) : (ScreenTools.defaultFontPixelHeight * 0.8)

        // Position using x/y instead of anchors to avoid stretching issues
        x:                  parent.width - width - (_isFullScreen ? ScreenTools.defaultFontPixelHeight : (ScreenTools.defaultFontPixelHeight * 0.5))
        y:                  _isFullScreen ? ((parent.height - height) / 2)-300 : (parent.height - height - (ScreenTools.defaultFontPixelHeight * 0.5))

        radius:             height / 2
        border.width:       1
        border.color:       "white"

        // Red for HD, Blue for SD
        property color _baseColor: videoStreaming._useSecondaryUrl ? "#2196F3" : "#F44336"  // Blue for SD, Red for HD
        color:              _root._isTogglingQuality ? "#9E9E9E" : (qualityButtonMouseArea2.pressed ? "#FF9800" : (qualityButtonMouseArea2.containsMouse ? Qt.lighter(_baseColor, 1.3) : _baseColor))
        opacity:            _root._isTogglingQuality ? 0.5 : 0.85
        visible:            videoStreaming._hasSecondaryUrl

        QGCLabel {
            id:                 qualityButtonLabel2
            text:               _root._isTogglingQuality ? "..." : (videoStreaming._useSecondaryUrl ? "SD" : "HD")
            font.bold:          true
            color:              "white"
            font.pointSize:     qualityButtonBackground2._isFullScreen ? ScreenTools.defaultFontPointSize : ScreenTools.smallFontPointSize
            anchors.centerIn:   parent
        }

        MouseArea {
            id:                 qualityButtonMouseArea2
            anchors.fill:       parent
            enabled:            !_root._isTogglingQuality
            hoverEnabled:       true
            cursorShape:        _root._isTogglingQuality ? Qt.ForbiddenCursor : Qt.PointingHandCursor
            propagateComposedEvents: false
            preventStealing:    true

            onPressed: (mouse) => {
                mouse.accepted = true
                console.log("!!! HD/SD button PRESSED !!!")
            }

            onReleased: (mouse) => {
                mouse.accepted = true
                console.log("!!! HD/SD button RELEASED !!!")
                // Trigger toggle on release to ensure it fires
                _root.toggleStreamQuality()
            }

            onClicked: (mouse) => {
                mouse.accepted = true
                console.log("!!! HD/SD button CLICKED !!!")
            }

            onDoubleClicked: (mouse) => {
                mouse.accepted = true
                console.log("!!! HD/SD button DOUBLE-CLICKED (ignoring) !!!")
            }

            onPressedChanged: {
                console.log("!!! HD/SD button pressedChanged:", pressed)
            }
        }
    }

    // Timer to re-enable button after quality toggle
    Timer {
        id: qualityToggleCooldown
        interval: 3000  // 3 seconds - optimized for fast quality switching
        running: false
        repeat: false
        onTriggered: {
            console.log("*** Quality toggle cooldown complete - button re-enabled ***")
            _root._isTogglingQuality = false
        }
    }

    // Function to toggle between HD and SD streams
    function toggleStreamQuality() {
        if (!videoStreaming._hasSecondaryUrl) return
        if (_root._isTogglingQuality) {
            console.log("*** Quality toggle already in progress - ignoring click ***")
            return
        }

        console.log("=== HD/SD Toggle Clicked ===")
        console.log("Stream Index:", _root.streamIndex)
        console.log("Current _useSecondaryUrl:", videoStreaming._useSecondaryUrl)

        // Set toggling flag and start cooldown
        _root._isTogglingQuality = true
        qualityToggleCooldown.restart()

        // Get the current usingPrimaryUrl value and invert it
        var currentUsingPrimary = true
        if (_root.streamIndex === 0) {
            currentUsingPrimary = QGroundControl.settingsManager.videoSettings.usingPrimaryUrl.value
            console.log("Stream 0 - currentUsingPrimary:", currentUsingPrimary)
            // Use .value instead of .rawValue to ensure proper signal emission
            QGroundControl.settingsManager.videoSettings.usingPrimaryUrl.value = !currentUsingPrimary
            console.log("Stream 0 - NEW usingPrimaryUrl:", !currentUsingPrimary)
            console.log("Stream 0 - VERIFY read back (.value):", QGroundControl.settingsManager.videoSettings.usingPrimaryUrl.value)
            console.log("Stream 0 - VERIFY read back (.rawValue):", QGroundControl.settingsManager.videoSettings.usingPrimaryUrl.rawValue)
        } else if (_root.streamIndex === 1) {
            currentUsingPrimary = QGroundControl.settingsManager.videoSettings.usingPrimaryUrl2.value
            console.log("Stream 1 - currentUsingPrimary:", currentUsingPrimary)
            QGroundControl.settingsManager.videoSettings.usingPrimaryUrl2.value = !currentUsingPrimary
            console.log("Stream 1 - NEW usingPrimaryUrl2:", !currentUsingPrimary)
            console.log("Stream 1 - VERIFY read back (.value):", QGroundControl.settingsManager.videoSettings.usingPrimaryUrl2.value)
            console.log("Stream 1 - VERIFY read back (.rawValue):", QGroundControl.settingsManager.videoSettings.usingPrimaryUrl2.rawValue)
        } else if (_root.streamIndex === 2) {
            currentUsingPrimary = QGroundControl.settingsManager.videoSettings.usingPrimaryUrl3.value
            console.log("Stream 2 - currentUsingPrimary:", currentUsingPrimary)
            QGroundControl.settingsManager.videoSettings.usingPrimaryUrl3.value = !currentUsingPrimary
            console.log("Stream 2 - NEW usingPrimaryUrl3:", !currentUsingPrimary)
            console.log("Stream 2 - VERIFY read back (.value):", QGroundControl.settingsManager.videoSettings.usingPrimaryUrl3.value)
            console.log("Stream 2 - VERIFY read back (.rawValue):", QGroundControl.settingsManager.videoSettings.usingPrimaryUrl3.rawValue)
        }

        console.log("New state will be:", currentUsingPrimary ? "SD" : "HD")
        console.log(">>> Settings changed - _videoSourceChanged signal should fire automatically")
        console.log(">>> Button disabled for 3 seconds to prevent rapid toggling")
    }
}
