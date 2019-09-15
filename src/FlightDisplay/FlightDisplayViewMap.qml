/****************************************************************************
 *
 *   (c) 2009-2016 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/


import QtQuick          2.3
import QtQuick.Controls 1.2
import QtLocation       5.3
import QtPositioning    5.3
import QtQuick.Dialogs  1.2

import QGroundControl               1.0
import QGroundControl.Airspace      1.0
import QGroundControl.Controllers   1.0
import QGroundControl.Controls      1.0
import QGroundControl.FlightDisplay 1.0
import QGroundControl.FlightMap     1.0
import QGroundControl.Palette       1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.Vehicle       1.0

FlightMap {
    id:                         flightMap
    anchors.fill:               parent
    mapName:                    _mapName
    allowGCSLocationCenter:     !userPanned
    allowVehicleLocationCenter: !_keepVehicleCentered
    planView:                   false

    // The following properties must be set by the consumer
    property var    qgcView                             ///< QGCView control which contains this map

    property rect   centerViewport:             Qt.rect(0, 0, width, height)

    property var    _activeVehicle:             QGroundControl.multiVehicleManager.offlineEditingVehicle
    property var    _activeVehicleCoordinate:   _activeVehicle ? _activeVehicle.coordinate : QtPositioning.coordinate()
    property real   _toolButtonTopMargin:       parent.height - ScreenTools.availableHeight + (ScreenTools.defaultFontPixelHeight / 2)

    property bool   _disableVehicleTracking:    false
    property bool   _keepVehicleCentered:       false


    property var    _pulse:             QGroundControl.corePlugin.pulse
    property var    _planeCoordinate:   _pulse.planeCoordinate
    property double _planeHeading:      _pulse.planeHeading

    // Track last known map position and zoom from Fly view in settings

    onZoomLevelChanged: {
        QGroundControl.flightMapZoom = zoomLevel
    }
    onCenterChanged: {
        QGroundControl.flightMapPosition = center
    }

    // When the user pans the map we stop responding to vehicle coordinate updates until the panRecenterTimer fires
    onUserPannedChanged: {
        if (userPanned) {
            console.log("user panned")
            userPanned = false
            _disableVehicleTracking = true
            panRecenterTimer.restart()
        }
    }

    function pointInRect(point, rect) {
        return point.x > rect.x &&
                point.x < rect.x + rect.width &&
                point.y > rect.y &&
                point.y < rect.y + rect.height;
    }

    property real _animatedLatitudeStart
    property real _animatedLatitudeStop
    property real _animatedLongitudeStart
    property real _animatedLongitudeStop
    property real animatedLatitude
    property real animatedLongitude

    onAnimatedLatitudeChanged: flightMap.center = QtPositioning.coordinate(animatedLatitude, animatedLongitude)
    onAnimatedLongitudeChanged: flightMap.center = QtPositioning.coordinate(animatedLatitude, animatedLongitude)

    NumberAnimation on animatedLatitude { id: animateLat; from: _animatedLatitudeStart; to: _animatedLatitudeStop; duration: 1000 }
    NumberAnimation on animatedLongitude { id: animateLong; from: _animatedLongitudeStart; to: _animatedLongitudeStop; duration: 1000 }

    function animatedMapRecenter(fromCoord, toCoord) {
        _animatedLatitudeStart = fromCoord.latitude
        _animatedLongitudeStart = fromCoord.longitude
        _animatedLatitudeStop = toCoord.latitude
        _animatedLongitudeStop = toCoord.longitude
        animateLat.start()
        animateLong.start()
    }

    function recenterNeeded() {
        var vehiclePoint = flightMap.fromCoordinate(_activeVehicleCoordinate, false /* clipToViewport */)
        var toolStripRightEdge = mapFromItem(toolStrip, toolStrip.x, 0).x + toolStrip.width
        var instrumentsWidth = 0
        if (QGroundControl.corePlugin.options.instrumentWidget && QGroundControl.corePlugin.options.instrumentWidget.widgetPosition === CustomInstrumentWidget.POS_TOP_RIGHT) {
            // Assume standard instruments
            instrumentsWidth = flightDisplayViewWidgets.getPreferredInstrumentWidth()
        }
        var centerViewport = Qt.rect(toolStripRightEdge, 0, width - toolStripRightEdge - instrumentsWidth, height)
        return !pointInRect(vehiclePoint, centerViewport)
    }

    function updateMapToVehiclePosition() {
        // We let FlightMap handle first vehicle position
        if (firstVehiclePositionReceived && _activeVehicleCoordinate.isValid && !_disableVehicleTracking) {
            if (_keepVehicleCentered) {
                flightMap.center = _activeVehicleCoordinate
            } else {
                if (firstVehiclePositionReceived && recenterNeeded()) {
                    animatedMapRecenter(flightMap.center, _activeVehicleCoordinate)
                }
            }
        }
    }

    Timer {
        id:         panRecenterTimer
        interval:   10000
        running:    false

        onTriggered: {
            _disableVehicleTracking = false
            updateMapToVehiclePosition()
        }
    }

    Timer {
        interval:       500
        running:        true
        repeat:         true
        onTriggered:    updateMapToVehiclePosition()
    }

    QGCPalette { id: qgcPal; colorGroupEnabled: true }
    QGCMapPalette { id: mapPal; lightColors: isSatelliteMap }

    MapQuickItem {
        anchorPoint.x:  vehicleItem.width  / 2
        anchorPoint.y:  vehicleItem.height / 2
        visible:        coordinate.isValid
        coordinate:     _planeCoordinate

        sourceItem: Item {
            id:         vehicleItem
            width:      vehicleIcon.width
            height:     vehicleIcon.height

            Rectangle {
                id:                 vehicleShadow
                anchors.fill:       vehicleIcon
                color:              Qt.rgba(1,1,1,1)
                radius:             width * 0.5
                visible:            false
            }

            Image {
                id:                 vehicleIcon
                source:             "/qmlimages/vehicleArrowOpaque.svg"
                mipmap:             true
                width:              ScreenTools.defaultFontPixelHeight * 3
                sourceSize.width:   width
                fillMode:           Image.PreserveAspectFit
                transform: Rotation {
                    origin.x:       vehicleIcon.width  / 2
                    origin.y:       vehicleIcon.height / 2
                    angle:          isNaN(_planeHeading) ? 0 : _planeHeading
                }
            }
        }
    }

    MapScale {
        id:                     mapScale
        anchors.right:          parent.right
        anchors.margins:        ScreenTools.defaultFontPixelHeight * (0.33)
        anchors.bottom:         parent.bottom
        mapControl:             flightMap
    }
}
