/****************************************************************************
 *
 *   (c) 2009-2016 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/


import QtQuick                  2.3
import QtQuick.Controls         1.2
import QtQuick.Controls.Styles  1.4
import QtQuick.Dialogs          1.2
import QtLocation               5.3
import QtPositioning            5.3
import QtQuick.Layouts          1.2
import QtQuick.Window           2.2
import QtQml.Models             2.1

import QGroundControl               1.0
import QGroundControl.Airspace      1.0
import QGroundControl.Controllers   1.0
import QGroundControl.Controls      1.0
import QGroundControl.FactSystem    1.0
import QGroundControl.FlightDisplay 1.0
import QGroundControl.FlightMap     1.0
import QGroundControl.Palette       1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.Vehicle       1.0

/// Flight Display View
QGCView {
    id:             root
    viewPanel:      _panel

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    property real   _margins:               ScreenTools.defaultFontPixelWidth / 2

    readonly property bool      isBackgroundDark:       _flightMap ? _flightMap.isSatelliteMap : true
    readonly property string    _mapName:               "FlightDisplayView"

    QGCMapPalette { id: mapPal; lightColors: _flightMap.isSatelliteMap }

    QGCViewPanel {
        id:             _panel
        anchors.fill:   parent

        FlightDisplayViewMap {
            id:                     _flightMap
            anchors.rightMargin:    parent.width / 4
            anchors.fill:           parent
            qgcView:                root
        }

        //-------------------------------------------------------------------------
        //-- Loader helper for plugins to overlay elements over the fly view
        Loader {
            id:                 flyViewOverlay
            height:             ScreenTools.availableHeight
            width:              parent.width / 4
            anchors.right:      parent.right
            anchors.bottom:     parent.bottom
            source:             "/qml/STETrackerFlyViewOverlay.qml"

            property var qgcView: root
        }

    }
}
