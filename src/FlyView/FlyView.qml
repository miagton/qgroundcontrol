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

    property bool   _mainWindowIsMap:       mapControl.pipState.state === mapControl.pipState.fullState
    property bool   _isFullWindowItemDark:  _mainWindowIsMap ? mapControl.isSatelliteMap : true
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
        console.log("========================================")
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
            if (_pipView.visible) maxInset = Math.max(maxInset, _pipView.leftEdgeBottomInset)
            if (_pipView2.visible) maxInset = Math.max(maxInset, _pipView2.leftEdgeBottomInset)
            if (_pipView3.visible) maxInset = Math.max(maxInset, _pipView3.leftEdgeBottomInset)
            return maxInset
        }

        function _calcBottomEdgeLeftInset() {
            var totalInset = 0
            if (_pipView.visible) totalInset += _pipView.bottomEdgeLeftInset
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
            pipView:                _pipView
            pipMode:                !_mainWindowIsMap
            toolInsets:             customOverlay.totalToolInsets
            mapName:                "FlightDisplayView"
            enabled:                !viewer3DWindow.isOpen
        }

        FlyViewVideo {
            id:         videoControl
            pipView:    _pipView
            streamIndex: 0  // Primary stream
        }

        PipView {
            id:                     _pipView
            anchors.left:           parent.left
            anchors.bottom:         parent.bottom
            anchors.margins:        _toolsMargin
            item1IsFullSettingsKey: "MainFlyWindowIsMap"
            item1:                  mapControl
            item2:                  QGroundControl.videoManager.hasVideo ? videoControl : null
            show:                   QGroundControl.videoManager.hasVideo && !QGroundControl.videoManager.fullScreen &&
                                        (videoControl.pipState.state === videoControl.pipState.pipState || mapControl.pipState.state === mapControl.pipState.pipState)
            z:                      QGroundControl.zOrderWidgets

            property real leftEdgeBottomInset: visible ? width + anchors.margins : 0
            property real bottomEdgeLeftInset: visible ? height + anchors.margins : 0
        }

        // Additional Video Stream 2 - Always created, visibility controlled by settings
        FlyViewVideo {
            id:          videoControl2
            pipView:     _pipView2
            streamIndex: 1  // Stream 2
            visible:     _videoStream2Enabled
        }

        PipView {
            id:                     _pipView2
            anchors.left:           parent.left
            anchors.bottom:         _pipView.visible ? _pipView.top : parent.bottom
            anchors.margins:        _toolsMargin
            item1IsFullSettingsKey: "VideoStream2IsFullWindow"
            item1:                  videoControl2
            item2:                  videoControl2
            show:                   _videoStream2Enabled && !QGroundControl.videoManager.fullScreen
            z:                      QGroundControl.zOrderWidgets

            Component.onCompleted: {
                console.log("PipView2: Created, show:", show, "visible:", visible)
            }

            onItem1Changed: {
                if (item1 && item1 === item2) {
                    var savedState = QGroundControl.loadBoolGlobalSetting(item1IsFullSettingsKey, false)
                    item1.pipState.state = savedState ? item1.pipState.fullState : item1.pipState.pipState
                    console.log("PipView2: Set initial state to:", item1.pipState.state)
                }
            }

            onVisibleChanged: {
                console.log("PipView2: Visible changed to:", visible, "show:", show)
            }

            onShowChanged: {
                console.log("PipView2: Show changed to:", show, "enabled:", _videoStream2Enabled)
            }

            property real leftEdgeBottomInset: visible ? width + anchors.margins : 0
            property real bottomEdgeLeftInset: visible ? height + anchors.margins + (_pipView.visible ? _pipView.height + anchors.margins : 0) : 0
        }

        // Additional Video Stream 3 - Always created, visibility controlled by settings
        FlyViewVideo {
            id:          videoControl3
            pipView:     _pipView3
            streamIndex: 2  // Stream 3
            visible:     _videoStream3Enabled
        }

        PipView {
            id:                     _pipView3
            anchors.left:           parent.left
            anchors.bottom:         _pipView2.visible ? _pipView2.top : (_pipView.visible ? _pipView.top : parent.bottom)
            anchors.margins:        _toolsMargin
            item1IsFullSettingsKey: "VideoStream3IsFullWindow"
            item1:                  videoControl3
            item2:                  videoControl3
            show:                   _videoStream3Enabled && !QGroundControl.videoManager.fullScreen
            z:                      QGroundControl.zOrderWidgets

            Component.onCompleted: {
                console.log("PipView3: Created, show:", show, "visible:", visible)
            }

            onItem1Changed: {
                if (item1 && item1 === item2) {
                    var savedState = QGroundControl.loadBoolGlobalSetting(item1IsFullSettingsKey, false)
                    item1.pipState.state = savedState ? item1.pipState.fullState : item1.pipState.pipState
                    console.log("PipView3: Set initial state to:", item1.pipState.state)
                }
            }

            onVisibleChanged: {
                console.log("PipView3: Visible changed to:", visible, "show:", show)
            }

            onShowChanged: {
                console.log("PipView3: Show changed to:", show, "enabled:", _videoStream3Enabled)
            }

            property real leftEdgeBottomInset: visible ? width + anchors.margins : 0
            property real bottomEdgeLeftInset: visible ? height + anchors.margins + ((_pipView2.visible ? _pipView2.height + anchors.margins : 0) + (_pipView.visible ? _pipView.height + anchors.margins : 0)) : 0
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
