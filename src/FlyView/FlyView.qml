import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QtLocation
import QtPositioning
import QtQuick.Window
import QtQml.Models

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView
import QGroundControl.FlightMap
import QGroundControl.UTMSP
import QGroundControl.Viewer3D

Item {
    id: _root

    // These should only be used by MainRootWindow
    property var planController:    _planController
    property var guidedController:  _guidedController

    // Properties of UTM adapter
    property bool utmspSendActTrigger: false

    PlanMasterController {
        id:                     _planController
        flyView:                true
        Component.onCompleted:  start()
    }

    property bool   _isFullWindowItemDark:  mapControl.pipState.state === mapControl.pipState.fullState ? mapControl.isSatelliteMap : true
    property var    _activeVehicle:         QGroundControl.multiVehicleManager.activeVehicle
    property var    _missionController:     _planController.missionController
    property var    _geoFenceController:    _planController.geoFenceController
    property var    _rallyPointController:  _planController.rallyPointController
    property real   _margins:               ScreenTools.defaultFontPixelWidth / 2
    property var    _guidedController:      guidedActionsController
    property var    _guidedValueSlider:     guidedValueSlider
    property var    _widgetLayer:           widgetLayer
    property real   _toolsMargin:           ScreenTools.defaultFontPixelWidth * 0.75
    property rect   _centerViewport:        Qt.rect(0, 0, width, height)
    property real   _rightPanelWidth:       ScreenTools.defaultFontPixelWidth * 30
    property var    _mapControl:            mapControl
    property real   _widgetMargin:          ScreenTools.defaultFontPixelWidth * 0.75
    property string _rtspUrl2:              QGroundControl.settingsManager.videoSettings.rtspUrl2.rawValue
    property string _rtspUrl3:              QGroundControl.settingsManager.videoSettings.rtspUrl3.rawValue
    property bool   _videoStream2Enabled:   QGroundControl.settingsManager.videoSettings.streamEnabled2.rawValue === true &&
                                            _rtspUrl2.length > 0 &&
                                            (_rtspUrl2.toLowerCase().startsWith("rtsp://") ||
                                             _rtspUrl2.toLowerCase().startsWith("rtspt://") ||
                                             _rtspUrl2.toLowerCase().startsWith("rtsps://"))
    property bool   _videoStream3Enabled:   QGroundControl.settingsManager.videoSettings.streamEnabled3.rawValue === true &&
                                            _rtspUrl3.length > 0 &&
                                            (_rtspUrl3.toLowerCase().startsWith("rtsp://") ||
                                             _rtspUrl3.toLowerCase().startsWith("rtspt://") ||
                                             _rtspUrl3.toLowerCase().startsWith("rtsps://"))

    property real   _fullItemZorder:    0
    property real   _pipItemZorder:     QGroundControl.zOrderWidgets

    // ========== PipView Coordination ==========
    // All views are equal: map, video, video2, video3
    // When any view goes full screen, ALL others collapse to pip mode
    // One view full, all others as small pip windows at bottom-left

    function requestFullScreen(viewId) {
        console.log("requestFullScreen called for:", viewId)

        // Collapse ALL other views to pip state - simple and uniform
        if (viewId !== "map" && mapControl.pipState && mapControl.pipState.state === mapControl.pipState.fullState) {
            mapControl.pipState.state = mapControl.pipState.pipState
        }
        if (viewId !== "video" && videoControl.pipState && videoControl.pipState.state === videoControl.pipState.fullState) {
            videoControl.pipState.state = videoControl.pipState.pipState
        }
        if (viewId !== "video2" && videoControl2.pipState && videoControl2.pipState.state === videoControl2.pipState.fullState) {
            videoControl2.pipState.state = videoControl2.pipState.pipState
        }
        if (viewId !== "video3" && videoControl3.pipState && videoControl3.pipState.state === videoControl3.pipState.fullState) {
            videoControl3.pipState.state = videoControl3.pipState.pipState
        }
    }

    Component.onCompleted: {
        console.log("========== FlyView Debug Info ==========")
        console.log("Stream 2 - Enabled:", QGroundControl.settingsManager.videoSettings.streamEnabled2.rawValue)
        console.log("Stream 2 - URL:", QGroundControl.settingsManager.videoSettings.rtspUrl2.rawValue)
        console.log("Stream 2 - URL Length:", QGroundControl.settingsManager.videoSettings.rtspUrl2.rawValue.length)
        console.log("Stream 2 - _videoStream2Enabled:", _videoStream2Enabled)
        console.log("Stream 3 - Enabled:", QGroundControl.settingsManager.videoSettings.streamEnabled3.rawValue)
        console.log("Stream 3 - URL:", QGroundControl.settingsManager.videoSettings.rtspUrl3.rawValue)
        console.log("Stream 3 - URL Length:", QGroundControl.settingsManager.videoSettings.rtspUrl3.rawValue.length)
        console.log("Stream 3 - _videoStream3Enabled:", _videoStream3Enabled)
        console.log("Main Stream Enabled:", QGroundControl.settingsManager.videoSettings.streamEnabled.rawValue)
        console.log("========================================")

        // Ensure something is always fullscreen on startup
        // Check if main video stream is enabled in settings (not hasVideo which takes time to initialize)
        // If main video is disabled, ensure map is fullscreen
        var mainVideoEnabled = QGroundControl.settingsManager.videoSettings.streamEnabled.rawValue
        if (!mainVideoEnabled) {
            // Main video stream is disabled in settings, ensure map is fullscreen
            if (mapControl.pipState) {
                mapControl.pipState.state = mapControl.pipState.fullState
            }
        }
        // If main video is enabled, PipView's default (fullscreen) will handle it
    }

    // Monitor stream enabled state changes using Connections
    Connections {
        target: QGroundControl.settingsManager.videoSettings.streamEnabled2
        function onRawValueChanged() {
            console.log("FlyView: Stream 2 enabled changed to:", _videoStream2Enabled)
        }
    }

    Connections {
        target: QGroundControl.settingsManager.videoSettings.streamEnabled3
        function onRawValueChanged() {
            console.log("FlyView: Stream 3 enabled changed to:", _videoStream3Enabled)
        }
    }

    function _calcCenterViewPort() {
        var newToolInset = Qt.rect(0, 0, width, height)
        toolstrip.adjustToolInset(newToolInset)
    }

    function dropMainStatusIndicatorTool() {
        toolbar.dropMainStatusIndicatorTool();
    }

    QGCToolInsets {
        id:                     _toolInsets
        topEdgeLeftInset:       toolbar.height
        topEdgeCenterInset:     topEdgeLeftInset
        topEdgeRightInset:      topEdgeLeftInset
        leftEdgeBottomInset:    _calcLeftEdgeBottomInset()
        bottomEdgeLeftInset:    _calcBottomEdgeLeftInset()

        function _calcLeftEdgeBottomInset() {
            var maxInset = 0
            if (_pipViewMap.visible) maxInset = Math.max(maxInset, _pipViewMap.leftEdgeBottomInset)
            if (_pipView.visible) maxInset = Math.max(maxInset, _pipView.leftEdgeBottomInset)
            if (_pipView2.visible) maxInset = Math.max(maxInset, _pipView2.leftEdgeBottomInset)
            if (_pipView3.visible) maxInset = Math.max(maxInset, _pipView3.leftEdgeBottomInset)
            return maxInset
        }

        function _calcBottomEdgeLeftInset() {
            var totalInset = 0
            if (_pipViewMap.visible) totalInset += _pipViewMap.height + _toolsMargin
            if (_pipView.visible) totalInset += _pipView.height + _toolsMargin
            if (_pipView2.visible) totalInset += _pipView2.height + _toolsMargin
            if (_pipView3.visible) totalInset += _pipView3.height + _toolsMargin
            return totalInset
        }
    }

    Item {
        id:                 mapHolder
        anchors.fill:       parent

        FlyViewMap {
            id:                     mapControl
            planMasterController:   _planController
            rightPanelWidth:        ScreenTools.defaultFontPixelHeight * 9
            pipView:                _pipViewMap
            pipMode:                mapControl.pipState.state === mapControl.pipState.pipState
            toolInsets:             customOverlay.totalToolInsets
            mapName:                "FlightDisplayView"
            enabled:                !viewer3DWindow.isOpen
        }

        // Monitor map pip state changes
        Connections {
            target: mapControl.pipState
            function onStateChanged() {
                if (mapControl.pipState.state === mapControl.pipState.fullState) {
                    _root.requestFullScreen("map")
                }
            }
        }

        PipView {
            id:                     _pipViewMap
            anchors.left:           parent.left
            anchors.bottom:         parent.bottom
            anchors.margins:        _toolsMargin
            item1IsFullSettingsKey: "MapIsFullWindow"
            item1:                  mapControl
            item2:                  mapControl  // Single-item pip view (toggle pip/full)
            // Show when: not in VideoManager fullScreen mode AND in pip state
            show:                   !QGroundControl.videoManager.fullScreen &&
                                    mapControl.pipState.state === mapControl.pipState.pipState
            z:                      QGroundControl.zOrderWidgets

            property real leftEdgeBottomInset: visible ? width + anchors.margins : 0
            property real bottomEdgeLeftInset: visible ? height + anchors.margins : 0
        }

        FlyViewVideo {
            id:         videoControl
            pipView:    _pipView
            streamIndex: 0  // Primary stream
        }

        // Monitor primary video pip state changes
        Connections {
            target: videoControl.pipState
            function onStateChanged() {
                if (videoControl.pipState.state === videoControl.pipState.fullState) {
                    _root.requestFullScreen("video")
                }
            }
        }

        PipView {
            id:                     _pipView
            anchors.left:           parent.left
            anchors.bottom:         _pipViewMap.visible ? _pipViewMap.top : parent.bottom
            anchors.margins:        _toolsMargin
            item1IsFullSettingsKey: "MainVideoIsFullWindow"
            item1:                  videoControl
            item2:                  videoControl  // Single-item pip view (toggle pip/full)
            // Show when: has video, not in fullScreen mode, and in pip state
            show:                   QGroundControl.videoManager.hasVideo && !QGroundControl.videoManager.fullScreen &&
                                    videoControl.pipState.state === videoControl.pipState.pipState
            z:                      QGroundControl.zOrderWidgets

            property real leftEdgeBottomInset: visible ? width + anchors.margins : 0
            property real bottomEdgeLeftInset: visible ? height + anchors.margins + (_pipViewMap.visible ? _pipViewMap.height + anchors.margins : 0) : 0
        }

        // Additional Video Stream 2 - Always created, visibility controlled by settings
        FlyViewVideo {
            id:          videoControl2
            pipView:     _pipView2
            streamIndex: 1  // Stream 2
            visible:     _videoStream2Enabled
        }

        // Monitor video2 pip state changes
        Connections {
            target: videoControl2.pipState
            function onStateChanged() {
                if (videoControl2.pipState.state === videoControl2.pipState.fullState) {
                    _root.requestFullScreen("video2")
                }
            }
        }

        PipView {
            id:                     _pipView2
            anchors.left:           parent.left
            anchors.bottom:         _pipView.visible ? _pipView.top : (_pipViewMap.visible ? _pipViewMap.top : parent.bottom)
            anchors.margins:        _toolsMargin
            item1IsFullSettingsKey: "VideoStream2IsFullWindow"
            item1:                  videoControl2
            item2:                  videoControl2  // Same item for single-item pip view (toggle pip/full)
            // Show when: stream is enabled AND not in VideoManager fullScreen mode AND in pip state
            // Hide when in full state (content fills screen via PipState reparenting)
            show:                   _videoStream2Enabled && !QGroundControl.videoManager.fullScreen &&
                                    videoControl2.pipState.state === videoControl2.pipState.pipState
            z:                      QGroundControl.zOrderWidgets

            property real leftEdgeBottomInset: visible ? width + anchors.margins : 0
            property real bottomEdgeLeftInset: visible ? height + anchors.margins +
                                                         (_pipView.visible ? _pipView.height + anchors.margins : 0) +
                                                         (_pipViewMap.visible ? _pipViewMap.height + anchors.margins : 0) : 0
        }

        // Additional Video Stream 3 - Always created, visibility controlled by settings
        FlyViewVideo {
            id:          videoControl3
            pipView:     _pipView3
            streamIndex: 2  // Stream 3
            visible:     _videoStream3Enabled
        }

        // Monitor video3 pip state changes
        Connections {
            target: videoControl3.pipState
            function onStateChanged() {
                if (videoControl3.pipState.state === videoControl3.pipState.fullState) {
                    _root.requestFullScreen("video3")
                }
            }
        }

        PipView {
            id:                     _pipView3
            anchors.left:           parent.left
            anchors.bottom:         _pipView2.visible ? _pipView2.top : (_pipView.visible ? _pipView.top : (_pipViewMap.visible ? _pipViewMap.top : parent.bottom))
            anchors.margins:        _toolsMargin
            item1IsFullSettingsKey: "VideoStream3IsFullWindow"
            item1:                  videoControl3
            item2:                  videoControl3  // Same item for single-item pip view (toggle pip/full)
            // Show when: stream is enabled AND not in VideoManager fullScreen mode AND in pip state
            // Hide when in full state (content fills screen via PipState reparenting)
            show:                   _videoStream3Enabled && !QGroundControl.videoManager.fullScreen &&
                                    videoControl3.pipState.state === videoControl3.pipState.pipState
            z:                      QGroundControl.zOrderWidgets

            property real leftEdgeBottomInset: visible ? width + anchors.margins : 0
            property real bottomEdgeLeftInset: visible ? height + anchors.margins +
                                                         (_pipView2.visible ? _pipView2.height + anchors.margins : 0) +
                                                         (_pipView.visible ? _pipView.height + anchors.margins : 0) +
                                                         (_pipViewMap.visible ? _pipViewMap.height + anchors.margins : 0) : 0
        }

        FlyViewWidgetLayer {
            id:                     widgetLayer
            anchors.top:            parent.top
            anchors.bottom:         parent.bottom
            anchors.left:           parent.left
            anchors.right:          guidedValueSlider.visible ? guidedValueSlider.left : parent.right
            anchors.margins:        _widgetMargin
            anchors.topMargin:      toolbar.height + _widgetMargin
            z:                      _fullItemZorder + 2 // we need to add one extra layer for map 3d viewer (normally was 1)
            parentToolInsets:       _toolInsets
            mapControl:             _mapControl
            visible:                !QGroundControl.videoManager.fullScreen
            isViewer3DOpen:         viewer3DWindow.isOpen
        }

        FlyViewCustomLayer {
            id:                 customOverlay
            anchors.fill:       widgetLayer
            z:                  _fullItemZorder + 2
            parentToolInsets:   widgetLayer.totalToolInsets
            mapControl:         _mapControl
            visible:            !QGroundControl.videoManager.fullScreen
        }

        // Development tool for visualizing the insets for a paticular layer, show if needed
        FlyViewInsetViewer {
            id:                     widgetLayerInsetViewer
            anchors.top:            parent.top
            anchors.bottom:         parent.bottom
            anchors.left:           parent.left
            anchors.right:          guidedValueSlider.visible ? guidedValueSlider.left : parent.right
            z:                      widgetLayer.z + 1
            insetsToView:           widgetLayer.totalToolInsets
            visible:                false
        }

        GuidedActionsController {
            id:                 guidedActionsController
            missionController:  _missionController
            guidedValueSlider:     _guidedValueSlider
        }

        //-- Guided value slider (e.g. altitude)
        GuidedValueSlider {
            id:                 guidedValueSlider
            anchors.right:      parent.right
            anchors.top:        parent.top
            anchors.bottom:     parent.bottom
            anchors.topMargin:  toolbar.height
            z:                  QGroundControl.zOrderTopMost
            visible:            false
        }

        Viewer3D {
            id: viewer3DWindow
            anchors.fill: parent
        }
    }

    UTMSPActivationStatusBar {
        activationStartTimestamp:   UTMSPStateStorage.startTimeStamp
        activationApproval:         UTMSPStateStorage.showActivationTab && QGroundControl.utmspManager.utmspVehicle.vehicleActivation
        flightID:                   UTMSPStateStorage.flightID
        anchors.fill:               parent

        function onActivationTriggered(value) {
            _root.utmspSendActTrigger = value
        }
    }

    FlyViewToolBar {
        id:                 toolbar
        guidedValueSlider:  _guidedValueSlider
        utmspSliderTrigger: utmspSendActTrigger
        visible:            !QGroundControl.videoManager.fullScreen
    }
}
