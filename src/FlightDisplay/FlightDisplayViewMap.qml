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
    allowVehicleLocationCenter: true
    planView:                   false

    // The following properties must be set by the consumer
    property var    qgcView                             ///< QGCView control which contains this map

    property rect   centerViewport:             Qt.rect(0, 0, width, height)

    property var    _activeVehicle:             QGroundControl.multiVehicleManager.offlineEditingVehicle
    property real   _toolButtonTopMargin:       parent.height - ScreenTools.availableHeight + (ScreenTools.defaultFontPixelHeight / 2)

    property bool   _disableVehicleTracking:    false


    property var    _pulse:             QGroundControl.corePlugin.pulse
    property var    _planeCoordinate:   _pulse.planeCoordinate
    property double _planeHeading:      _pulse.planeHeading
    property double _collarHeading:     _pulse.collarHeading
    property var    _collarPath:        []

    function updateCollarHeadingPath() {
        _collarPath = [ _planeCoordinate, _planeCoordinate.atDistanceAndAzimuth(10000, _planeHeading + _collarHeading)]
    }

    on_PlaneCoordinateChanged:  updateCollarHeadingPath()
    on_CollarHeadingChanged:    updateCollarHeadingPath()

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
        var vehiclePoint = flightMap.fromCoordinate(_planeCoordinate, false /* clipToViewport */)
        var centerViewport = Qt.rect(0, 0, width - (width /4), height)
        return !pointInRect(vehiclePoint, centerViewport)
    }

    function updateMapToVehiclePosition() {
        if (_planeCoordinate.isValid && !_disableVehicleTracking) {
            if (recenterNeeded()) {
                animatedMapRecenter(flightMap.center, _planeCoordinate)
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

    MapPolyline {
        line.width: 1
        line.color: "yellow"
        path:       _collarPath
    }

    MapQuickItem {
        anchorPoint.x:  transmitterIndicator.width  / 2
        anchorPoint.y:  transmitterIndicator.height / 2
        coordinate:     QtPositioning.coordinate(0.535316, 37.529429)

        sourceItem: Rectangle {
            id:                 transmitterIndicator
            color:              "red"
            width:              10
            height:             10
            radius:             width * 0.5
        }
    }

    MapItemView {
        model: QGroundControl.corePlugin.pulse.pulseTrajectories

        delegate: MapQuickItem {
            anchorPoint.x:  indicator.width / 2
            anchorPoint.y:  indicator.height / 2
            coordinate:     object.coordinate

            sourceItem: Rectangle {
                id:     indicator
                width:  ScreenTools.defaultFontPixelWidth
                height: width
                radius: width / 2
                color:  "green"
            }
        }
    }


    MapItemView {
        model: QGroundControl.corePlugin.pulse.pulseTrajectories

        delegate: MapPolyline {
            line.width: 2
            line.color: "green"
            path:       [ from, to ]
            opacity:    0.75

            property var from:  object.coordinate
            property var to:    object.coordinate.atDistanceAndAzimuth(10000, object.heading)
        }
    }

    MapScale {
        id:                     mapScale
        anchors.left:           parent.left
        anchors.margins:        ScreenTools.defaultFontPixelHeight * (0.33)
        anchors.bottom:         parent.bottom
        mapControl:             flightMap
    }
}
