import QtQuick

import QGroundControl
import QGroundControl.Controls

Item {
    id: _root

    property Item pipView
    property Item pipState: videoPipState

    PipState {
        id:         videoPipState
        pipView:    _root.pipView
        isDark:     true

        onWindowAboutToOpen: {
            // Note: Video stream 2 doesn't control main videoManager
            videoStartDelay.start()
        }

        onWindowAboutToClose: {
            // Note: Video stream 2 doesn't control main videoManager
            videoStartDelay.start()
        }

        onStateChanged: {
            // Video stream 2 doesn't affect full screen state
        }
    }

    Timer {
        id:           videoStartDelay
        interval:     2000
        running:      false
        repeat:       false
        onTriggered:  {
            // Video receivers are managed by VideoManager
        }
    }

    //-- Video Streaming for Stream 2
    Loader {
        id:             videoStreaming2
        anchors.fill:   parent
        active:         true  // Always active when parent FlyViewVideo2 is created
        source:         "qrc:/qml/QGroundControl/FlyView/FlightDisplayViewVideo2.qml"

        onLoaded: {
            item.useSmallFont = Qt.binding(function() { return _root.pipState.state !== _root.pipState.fullState })
        }
    }

    QGCLabel {
        text: qsTr("Double-click to exit full screen")
        font.pointSize: ScreenTools.largeFontPointSize
        visible: pipState.state === pipState.windowState && videoMouseArea.containsMouse
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

    MouseArea {
        id:                         videoMouseArea
        anchors.fill:               parent
        enabled:                    pipState.state === pipState.fullState || pipState.state === pipState.windowState
        hoverEnabled:               true

        onDoubleClicked: {
            if (pipState.state === pipState.windowState) {
                pipState.state = pipState.pipState
            }
        }
    }
}

