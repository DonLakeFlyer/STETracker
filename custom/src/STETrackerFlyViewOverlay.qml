/****************************************************************************
 *
 *   (c) 2009-2016 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick                  2.11
import QtQuick.Controls         1.4
import QtBluetooth              5.2
import QtQuick.Window           2.11
import Qt.labs.settings         1.0
import QtQuick.Layouts          1.11
import QtQuick.Controls.Styles  1.4
import QtPositioning            5.11

import QGroundControl                   1.0
import QGroundControl.Controls          1.0
import QGroundControl.FactControls      1.0
import QGroundControl.Palette           1.0
import QGroundControl.ScreenTools       1.0
import QGroundControl.Controllers       1.0
import QGroundControl.SettingsManager   1.0

Rectangle {
    id:             flyOverlay
    color:          qgcPal.window

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    property var    _corePlugin:            QGroundControl.corePlugin
    property var    _pulse:                 _corePlugin.pulse
    property real   _margins:               ScreenTools.defaultFontPixelWidth
    property real   _largeFontPixelWidth:   ScreenTools.defaultFontPixelWidth * ScreenTools.largeFontPointRatio
    property real   _largeFontPixelHeight:  ScreenTools.defaultFontPixelHeight * ScreenTools.largeFontPointRatio
    property real   _minRawPulse:           0.01
    property real   _maxRawPulse:           20
    property var    _settings:              _corePlugin.vhfSettings

    readonly property real gainTargetPulsePercent:          0.75
    readonly property real gainTargetPulsePercentWindow:    0.1
    readonly property int  minGain:                         1
    readonly property int  maxGain:                         21
    readonly property int  channelTimeoutMSecs:             10000
    readonly property var  dbRadiationPct:                 [ 1.0,  .97,    .94,    .85,    .63,    .40,    .10,    .20,    .30,    .40,    .45,    0.5,    0.51 ]
    readonly property var  dbRadiationAngle:               [ 0,    15,     30,     45,     60,     75,     90,     105,    120,    135,    150,    165,    180 ]
    readonly property real dbRadiationAngleInc:            15

    property real  dbRadiationMinPulse:            _maxRawPulse * 0.25

    property real pulseRange:           _maxRawPulse - _minRawPulse
    property real heading:              NaN
    property real newHeading:           0
    property bool headingAvailable:     false
    property bool headingLowQuality:    true
    property int  zoomFactor:           1

    property bool channel0FirstFreqSent: false
    property bool channel1FirstFreqSent: false
    property bool channel2FirstFreqSent: false
    property bool channel3FirstFreqSent: false

    property bool channel0Active:   false
    property bool channel1Active:   false
    property bool channel2Active:   false
    property bool channel3Active:   false

    property int channel0CPUTemp:  0
    property int channel1CPUTemp:  0
    property int channel2CPUTemp:  0
    property int channel3CPUTemp:  0

    property real channel0PulseValue:   0
    property real channel1PulseValue:   0
    property real channel2PulseValue:   0
    property real channel3PulseValue:   0

    property real channel0PulsePercent: 0
    property real channel1PulsePercent: 0
    property real channel2PulsePercent: 0
    property real channel3PulsePercent: 0

    property int channel0Gain:   0
    property int channel1Gain:   0
    property int channel2Gain:   0
    property int channel3Gain:   0

    property int  freqDigit1
    property int  freqDigit2
    property int  freqDigit3
    property int  freqDigit4
    property int  freqDigit5
    property int  freqDigit6
    property int  freqDigit7
    property int  freqInt
    property int  freqStart

    property real fontPixelWidth:       textMeasureDefault.fontPixelWidth
    property real fontPixelHeight:      textMeasureDefault.fontPixelHeight
    property real fontPixelWidthLarge:  textMeasureLarge.fontPixelWidth
    property real fontPixelHeightLarge: textMeasureLarge.fontPixelHeight

    onChannel0PulseValueChanged: { channel0Background.color = "green"; channel0Animate.restart() }
    onChannel1PulseValueChanged: { channel1Background.color = "green"; channel1Animate.restart() }
    onChannel2PulseValueChanged: { channel2Background.color = "green"; channel2Animate.restart() }
    onChannel3PulseValueChanged: { channel3Background.color = "green"; channel3Animate.restart() }

    onChannel0PulsePercentChanged: channel0PulseSlice.requestPaint()
    onChannel1PulsePercentChanged: channel1PulseSlice.requestPaint()
    onChannel2PulsePercentChanged: channel2PulseSlice.requestPaint()
    onChannel3PulsePercentChanged: channel3PulseSlice.requestPaint()

    Component.onCompleted: {
        freqInt = _settings.frequency.rawValue
        freqStart = freqInt
        updateDigitsFromFreqInt()
    }

    onFreqDigit1Changed: setFrequencyFromDigits()
    onFreqDigit2Changed: setFrequencyFromDigits()
    onFreqDigit3Changed: setFrequencyFromDigits()
    onFreqDigit4Changed: setFrequencyFromDigits()
    onFreqDigit5Changed: setFrequencyFromDigits()
    onFreqDigit6Changed: setFrequencyFromDigits()
    onFreqDigit7Changed: setFrequencyFromDigits()

    function setFrequencyFromDigits() {
        freqInt = (freqDigit1 * 1000000) + (freqDigit2 * 100000) + (freqDigit3 * 10000) + (freqDigit4 * 1000) + (freqDigit5 * 100) + (freqDigit6 * 10) + freqDigit7
        _settings.frequency.rawValue = freqInt
        sendFreqChange()
    }

    function updateDigitsFromFreqInt() {
        var rgDigits = [ 0, 0, 0, 0, 0, 0, 0 ]
        var digitIndex = 6
        var freqIntWorker = freqInt
        while (freqIntWorker > 0) {
            rgDigits[digitIndex] = freqIntWorker % 10
            freqIntWorker = freqIntWorker / 10;
            digitIndex--
        }
        freqDigit1 = rgDigits[0]
        freqDigit2 = rgDigits[1]
        freqDigit3 = rgDigits[2]
        freqDigit4 = rgDigits[3]
        freqDigit5 = rgDigits[4]
        freqDigit6 = rgDigits[5]
        freqDigit7 = rgDigits[6]

    }

    function sendFreqChange() {
        _pulse.setFreq(freqInt * 100)
    }

    function _normalizeHeading(heading) {
        if (heading >= 360.0) {
            heading = heading - 360.0
        } else if (heading < 0) {
            heading = heading + 360
        }
        return heading
    }

    // We don't upate the heading on every pulse. We wait for the possible group of 4.
    Timer {
        id:             delayedHeadingUpdateTimer
        interval:       50
        repeat:         false
        running:        false
        onTriggered:    updateHeading()
    }

    function _handlePulse(tcpLink, channelIndex, cpuTemp, pulseValue, gain) {
        //console.log(tcpLink ? "TCP Link" : "UDP Link", channelIndex)
        var pulsePercent
        if (pulseValue == 0) {
            pulsePercent = 0
        } else {
            pulsePercent = (pulseValue - _minRawPulse) / pulseRange
        }
        if (channelIndex === 0) {
            channel0Active = true
            channel0PulseValue = pulseValue
            channel0PulsePercent = pulsePercent
            channel0CPUTemp = cpuTemp
            channel0Gain = gain
            channel0NoPulseTimer.restart()
            if (!channel0FirstFreqSent) {
                channel0FirstFreqSent = true
                sendFreqChange()
            }
        } else if (channelIndex === 1) {
            channel1Active = true
            channel1PulseValue = pulseValue
            channel1PulsePercent = pulsePercent
            channel1CPUTemp = cpuTemp
            channel1Gain = gain
            channel1NoPulseTimer.restart()
            if (!channel1FirstFreqSent) {
                channel1FirstFreqSent = true
                sendFreqChange()
            }
        } else if (channelIndex === 2) {
            channel2Active = true
            channel2PulseValue = pulseValue
            channel2PulsePercent = pulsePercent
            channel2CPUTemp = cpuTemp
            channel2Gain = gain
            channel2NoPulseTimer.restart()
            if (!channel2FirstFreqSent) {
                channel2FirstFreqSent = true
                sendFreqChange()
            }
        } else if (channelIndex === 3) {
            channel3Active = true
            channel3PulseValue = pulseValue
            channel3PulsePercent = pulsePercent
            channel3CPUTemp = cpuTemp
            channel3Gain = gain
            channel3NoPulseTimer.restart()
            if (!channel3FirstFreqSent) {
                channel3FirstFreqSent = true
                sendFreqChange()
            }
        }

        delayedHeadingUpdateTimer.restart()

        return

        // Update zoom factor
        var maxChannelPulseValue = Math.max(channel0PulseValue, Math.max(channel1PulseValue, Math.max(channel2PulseValue, channel3PulseValue)))
        var normalizedMaxChannelPulseValue = maxChannelPulseValue - _minRawPulse
        var normalizedMaxRawPulse = _maxRawPulse - _minRawPulse

        var newZoomFactor = 1
        if (maxChannelPulseValue < _minRawPulse) {
            newZoomFactor = 4
        } else if (normalizedMaxChannelPulseValue < normalizedMaxRawPulse / 2) {
            if (normalizedMaxChannelPulseValue < normalizedMaxRawPulse / 4) {
                newZoomFactor = 4
            } else {
                newZoomFactor = 2
            }
        }

        if (newZoomFactor != zoomFactor) {
            zoomFactor = newZoomFactor
            channel0PulseSlice.requestPaint()
            channel1PulseSlice.requestPaint()
            channel2PulseSlice.requestPaint()
            channel3PulseSlice.requestPaint()
        }
    }

    function calcWeakAngleFromRadiation(strongestPct, secondPct) {
        // Normalize weaker value to 1
        var normalizedPulse = secondPct * (1 / strongestPct)
        //console.log("normalized", strongestPct, secondPct, normalizedPulse)

        //readonly property var  dbRadiationPct:                 [ 1.0,  .97,    .94,    .85,    .63,    .40,    .10,    .20,    .30,    .40,    .45,    0.5,    0.51 ]
        //readonly property var  dbRadiationAngle:               [ 0,    15,     30,     45,     60,     75,     90,     105,    120,    135,    150,    165,    180 ]
        //readonly property real dbRadiationAngleInc:            15

        // Find the pulse value in the radiation arrays
        for (var i=1; i<7; i++) {
            if (normalizedPulse > dbRadiationPct[i]) {
                var range = dbRadiationPct[i-1] - dbRadiationPct[i]
                var pctRatio = (normalizedPulse - dbRadiationPct[i]) / range
                var angle = dbRadiationAngle[i] - (dbRadiationAngleInc * pctRatio)
                //console.log("found", i, dbRadiationPct[i], range, pctRatio, angle)
                return angle
            }
        }
    }

    function updateHeading() {
        headingAvailable = true
        headingLowQuality = false

        // Find strongest channel
        var strongestChannel = -1
        var strongestPulsePct = -1
        var rgPulse = [ channel0PulsePercent, channel1PulsePercent, channel2PulsePercent, channel3PulsePercent ]
        for (var index=0; index<rgPulse.length; index++) {
            if (rgPulse[index] > strongestPulsePct) {
                strongestChannel = index
                strongestPulsePct = rgPulse[index]
            }
        }

        if (strongestPulsePct == 0) {
            // No antennas are picking up a signal
            headingAvailable = false
            headingLowQuality = true
            return
        }

        var rgLeft = [ 3, 0, 1, 2 ]
        var rgRight = [ 1, 2, 3, 0 ]
        var rgHeading = [ 0.0, 90.0, 180.0, 270.0 ]
        var strongLeft
        var secondaryStrength
        var leftPulse = rgPulse[rgLeft[strongestChannel]]
        var rightPulse = rgPulse[rgRight[strongestChannel]]

        // Start the the best simple single antenna estimate
        newHeading = rgHeading[strongestChannel]

        if (rightPulse == 0 && leftPulse == 0) {
            // All we have is one antenna
            headingLowQuality = true
            return
        }

        // Take into acount left/right side strengths
        var headingAdjust
        if (rightPulse > leftPulse) {
            if (true/*leftPulse == 0*/) {
                var weakAngle  = calcWeakAngleFromRadiation(strongestPulsePct, rightPulse)
                var adjustedAngle = 90 - weakAngle
                newHeading = rgHeading[strongestChannel] + adjustedAngle
                //headingAdjust = rightPulse / strongestPulsePct
            } else {
                headingAdjust = (1 - (leftPulse / rightPulse)) / 0.5
            }
            /*
            headingAdjust *= 1.1;
            newHeading += 45.0 * headingAdjust
            */
        } else {
            if (true/*rightPulse == 0*/) {
                var weakAngle  = calcWeakAngleFromRadiation(strongestPulsePct, leftPulse)
                var adjustedAngle = 90 - weakAngle
                newHeading = rgHeading[strongestChannel] - adjustedAngle
                //headingAdjust = leftPulse / strongestPulsePct
            } else {
                headingAdjust = (1 - (rightPulse / leftPulse)) / 0.5
            }
            /*
            headingAdjust *= 1.1;
            newHeading -= 45.0 * headingAdjust
            */
        }
        //console.log(qsTr("leftPulse(%1) centerPulse(%2) rightPulse(%3) headingAdjust(%4)").arg(leftPulse).arg(strongestPulsePct).arg(rightPulse).arg(headingAdjust))

        newHeading = _normalizeHeading(newHeading)

        //console.log("Estimated Heading:", heading)
    }

    Connections {
        target:     _pulse
        onPulse:    _handlePulse(tcpLink, channelIndex, cpuTemp, pulseValue, gain)
    }

    // Drift range testing
    Timer {
        running:    false
        interval:   5000
        repeat:     true

        onTriggered: {
            freqInt += 1
            if (freqInt > freqStart + 20) {
                freqInt = freqStart
            }
            console.log(freqInt, freqStart)
            updateDigitsFromFreqInt()
        }
    }

    // Simulator
    Timer {
        id:             pulseSimulator
        running:        false
        interval:       2000
        repeat:         true

        property real heading:              0
        property real headingIncrement:     10
        property real pulseAdjustFactor:    1
        property real pulseAdjustIncrement: 0.05
        property real pulseAdjustDirection: -1

        readonly property real minPulseAdjustFactor: 0.01

        onTriggered: pulseSimulator.nextHeading()

        function generatePulse(channel, heading) {
            //console.log("original", heading)
            if ( heading > 180) {
                heading = 180 - (heading - 180)
            }

            var radiationIndex
            if (heading == 0) {
                radiationIndex = 1
            } else {
                radiationIndex = Math.ceil(heading / dbRadiationAngleInc)
            }

            var powerLow = dbRadiationPct[radiationIndex-1]
            var powerHigh = dbRadiationPct[radiationIndex]
            var powerRange = powerHigh - powerLow
            var slicePct = (heading - ((radiationIndex - 1) * dbRadiationAngleInc)) / dbRadiationAngleInc
            var powerHeading = powerLow + (powerRange * slicePct)

            //console.log(qsTr("heading(%1) radiationIndex(%2) powerLow(%3) powerHigh(%4) powerRange(%5) slicePct(%6) powerHeading(%7)").arg(heading).arg(radiationIndex).arg(powerLow).arg(powerHigh).arg(powerRange).arg(slicePct).arg(powerHeading))

            var simulatedMaxRawPulse = _maxRawPulse
            var pulseValue = dbRadiationMinPulse + ((_maxRawPulse - dbRadiationMinPulse) * powerHeading)
            pulseValue *= pulseAdjustFactor

            //console.log("heading:pulse", heading, pulseValue)

            _handlePulse(channel, 0, pulseValue, 21)
        }

        function nextHeading() {
            pulseSimulator.heading = _normalizeHeading(pulseSimulator.heading + pulseSimulator.headingIncrement)
            console.log("Simulated Heading", heading, pulseAdjustFactor)

            pulseSimulator.generatePulse(0, pulseSimulator.heading)
            pulseSimulator.generatePulse(1, _normalizeHeading(pulseSimulator.heading - 90))
            pulseSimulator.generatePulse(2, _normalizeHeading(pulseSimulator.heading - 180))
            pulseSimulator.generatePulse(3, _normalizeHeading(pulseSimulator.heading - 270))

            pulseAdjustFactor = pulseAdjustFactor + (pulseAdjustIncrement * pulseAdjustDirection)
            if (pulseAdjustFactor < minPulseAdjustFactor) {
                pulseAdjustFactor = minPulseAdjustFactor
                pulseAdjustDirection = 1
            } else if (pulseAdjustFactor > 1) {
                pulseAdjustFactor = 1
                pulseAdjustDirection = -1
            }
        }
    }

    Timer {
        id:             channel0NoPulseTimer
        running:        true
        interval:       channelTimeoutMSecs
        onTriggered: {
            channel0FirstFreqSent = false
            channel0Active = false
            channel0PulsePercent = 0
            channel0CPUTemp = 0
            updateHeading()
        }
    }

    Timer {
        id:             channel1NoPulseTimer
        running:        true
        interval:       channelTimeoutMSecs
        onTriggered: {
            channel0FirstFreqSent = false
            channel1Active = false
            channel1PulsePercent = 0
            channel1CPUTemp = 0
            updateHeading()
        }
    }

    Timer {
        id:             channel2NoPulseTimer
        running:        true
        interval:       channelTimeoutMSecs
        onTriggered: {
            channel0FirstFreqSent = false
            channel2Active = false
            channel2PulsePercent = 0
            channel2CPUTemp = 0
            updateHeading()
        }
    }

    Timer {
        id:             channel3NoPulseTimer
        running:        true
        interval:       channelTimeoutMSecs
        onTriggered: {
            channel0FirstFreqSent = false
            channel3Active = false
            channel3PulsePercent = 0
            channel3CPUTemp = 0
            updateHeading()
        }
    }

    // Determine max pulse strength:
    //  - Adjust gain if auto-gain
    Timer {
        running:    true
        interval:   10000
        repeat:     true

        onTriggered: {
            if (_settings.autoGain.value) {
                var maxPulsePct = Math.max(channel0PulsePercent, Math.max(channel1PulsePercent, Math.max(channel2PulsePercent, channel3PulsePercent)))
                //console.log("maxPulsePct", maxPulsePct)

                var curGain = _settings.gain.rawValue
                var newGain = curGain
                if (maxPulsePct > gainTargetPulsePercent + gainTargetPulsePercentWindow) {
                    if (curGain > minGain) {
                        newGain = curGain - 1
                    }
                } else if (maxPulsePct < gainTargetPulsePercent - gainTargetPulsePercentWindow) {
                    if (curGain < maxGain) {
                        newGain = curGain + 1
                    }
                }
                if (newGain !== curGain) {
                    console.log("Adjusting gain", newGain)
                    _settings.gain.rawValue = newGain
                    _pulse.setGain(newGain)
                }
            }
        }
    }

    // This timer updates the heading value using a low pass filter
    Timer {
        running:    true
        interval:   500
        repeat:     true

        onTriggered: {
            if (isNaN(heading)) {
                heading = newHeading
                return
            }

            // If the differential in heading is > 180 degrees we need to make sure we adjust in the rotational
            // direction which is the shortest rotation distance
            var rotationAdjustedNewHeading = newHeading
            if (Math.abs(heading - newHeading) > 180) {
                if (newHeading > heading) {
                    rotationAdjustedNewHeading -= 360
                } else {
                    rotationAdjustedNewHeading += 360
                }
            }

            var filteredHeading = (heading * 0.9) + (rotationAdjustedNewHeading * 0.1)
            //console.log("tick", heading, newHeading, rotationAdjustedNewHeading, filteredHeading)
            filteredHeading = _normalizeHeading(filteredHeading)
            heading = filteredHeading
            //heading = newHeading
            _pulse.pulseTrajectory(heading)
        }
    }

    Text {
        id:         textMeasureDefault
        text:       "X"
        visible:    false

        property real fontPixelWidth:   contentWidth
        property real fontPixelHeight:  contentHeight
    }

    Text {
        id:             textMeasureLarge
        text:           "X"
        visible:        false
        font.pointSize: textMeasureDefault.font.pointSize * 2

        property real fontPixelWidth:   contentWidth
        property real fontPixelHeight:  contentHeight
    }

    Text {
        id:             textMeasureExtraLarge
        text:           "X"
        font.pointSize: 72
        visible:        false

        property real fontPixelWidth:   contentWidth
        property real fontPixelHeight:  contentHeight
    }

    function drawSlice(channel, ctx, centerX, centerX, radius) {
        if (radius <= 0) {
            return
        }

        var startPi = [ Math.PI * 1.25, Math.PI * 1.75, Math.PI * 0.25, Math.PI * 0.75 ]
        var stopPi = [ Math.PI * 1.75, Math.PI * 0.25, Math.PI * 0.75, Math.PI * 1.25 ]
        ctx.beginPath();
        ctx.fillStyle = "black";
        ctx.strokeStyle = "white";
        ctx.moveTo(centerX, centerX);
        ctx.arc(centerX, centerX, radius, startPi[channel], stopPi[channel], false);
        ctx.lineTo(centerX, centerX);
        ctx.fill();
        ctx.stroke()
    }

    Column {
        anchors.margins:    _margins
        anchors.top:        parent.top
        anchors.left:       parent.left
        anchors.right:      parent.right
        spacing:            ScreenTools.defaultFontPixelHeight

        QGCLabel {
            anchors.horizontalCenter:   parent.horizontalCenter
            text:                       "Zoom " + zoomFactor
            font.pointSize:             ScreenTools.largeFontPointSize
        }

        Rectangle {
            id:                 headingIndicator
            anchors.left:       parent.left
            anchors.right:      parent.right
            height:             width
            radius:             height / 2
            color:              "transparent"
            border.color:       "black"
            border.width:       2

            property real _centerX: width / 2
            property real _centerY: height / 2

            Canvas {
                id:             channel0PulseSlice
                anchors.fill:   parent

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    drawSlice(0, ctx, parent._centerX, parent._centerY, parent.radius * channel0PulsePercent * zoomFactor)
                }
            }

            Canvas {
                id:             channel1PulseSlice
                anchors.fill:   parent

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    drawSlice(1, ctx, parent._centerX, parent._centerY, parent.radius * channel1PulsePercent * zoomFactor)
                }
            }

            Canvas {
                id:             channel2PulseSlice
                anchors.fill:   parent

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    drawSlice(2, ctx, parent._centerX, parent._centerY, parent.radius * channel2PulsePercent * zoomFactor)
                }
            }

            Canvas {
                id:             channel3PulseSlice
                anchors.fill:   parent

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    drawSlice(3, ctx, parent._centerX, parent._centerY, parent.radius * channel3PulsePercent * zoomFactor)
                }
            }

            // Fitered heading indicator
            Image {
                id:                     fiteredHeadingIndicator
                source:                 "/qmlimages/attitudePointer.svg"
                mipmap:                 true
                fillMode:               Image.PreserveAspectFit
                anchors.leftMargin:     _pointerMargin
                anchors.rightMargin:    _pointerMargin
                anchors.topMargin:      _pointerMargin
                anchors.bottomMargin:   _pointerMargin
                anchors.fill:           parent
                sourceSize.height:      parent.height
                visible:                headingAvailable

                transform: Rotation {
                    origin.x:       fiteredHeadingIndicator.width  / 2
                    origin.y:       fiteredHeadingIndicator.height / 2
                    angle:          heading
                }

                readonly property real _pointerMargin: -10
            }

            // Raw heading indicator
            Image {
                id:                     rawHeadingIndicator
                source:                 "/qmlimages/attitudePointer.svg"
                mipmap:                 true
                fillMode:               Image.PreserveAspectFit
                anchors.leftMargin:     _pointerMargin
                anchors.rightMargin:    _pointerMargin
                anchors.topMargin:      _pointerMargin
                anchors.bottomMargin:   _pointerMargin
                anchors.fill:           parent
                sourceSize.height:      parent.height
                visible:                headingAvailable
                opacity:                0.5

                transform: Rotation {
                    origin.x:       rawHeadingIndicator.width  / 2
                    origin.y:       rawHeadingIndicator.height / 2
                    angle:          newHeading
                }

                readonly property real _pointerMargin: -10
            }
        }

        /*QGCButton {
            text: "Pause"
            onClicked: _pulse.pause()
        }

        QGCButton {
            text: "Go"
            onClicked: _pulse.go()
        }*/

        QGCLabel {
            text:           _settings.frequency.value
            font.pointSize: ScreenTools.largeFontPointSize

            MouseArea {
                anchors.fill:   parent
                onClicked:      freqEditor.visible = true
            }
        }

        QGCLabel {
            text:               (_settings.autoGain.value ? "Auto" : "Manual") + " Gain " + _settings.gain.value
            font.pointSize:     ScreenTools.largeFontPointSize

            MouseArea {
                anchors.fill:   parent
                onClicked:      gainEditor.visible = true
            }
        }
    }

    GridLayout {
        anchors.margins:    _margins
        anchors.bottom:     parent.bottom
        columns:            2

        Rectangle {
            id:     channel0Background
            width:  label0.width
            height: label0.height
            color:  "green"

            ColorAnimation on color {
                id:         channel0Animate
                to:         "white"
                duration:   500
            }

            QGCLabel { id: label0; text: "Channel 0" }
        }
        QGCLabel { text: channel0Active ? (qsTr("%1 %2% %3c %4g").arg(channel0PulseValue.toFixed(3)).arg(channel0PulsePercent.toFixed(1)).arg(channel0CPUTemp).arg(channel0Gain)) : "DISCONNECTED" }

        Rectangle {
            id:     channel1Background
            width:  label1.width
            height: label1.height
            color:  "green"

            ColorAnimation on color {
                id:         channel1Animate
                to:         "white"
                duration:   500
            }

            QGCLabel { id: label1; text: "Channel 1" }
        }
        QGCLabel { text: channel1Active ? (qsTr("%1 %2% %3c %4g").arg(channel1PulseValue.toFixed(3)).arg(channel1PulsePercent.toFixed(1)).arg(channel1CPUTemp).arg(channel1Gain)) : "DISCONNECTED" }

        Rectangle {
            id:     channel2Background
            width:  label2.width
            height: label2.height
            color:  "green"

            ColorAnimation on color {
                id:         channel2Animate
                to:         "white"
                duration:   500
            }

            QGCLabel { id: label2; text: "Channel 2" }
        }
        QGCLabel { text: channel2Active ? (qsTr("%1 %2% %3c %4g").arg(channel2PulseValue.toFixed(3)).arg(channel2PulsePercent.toFixed(1)).arg(channel2CPUTemp).arg(channel2Gain)) : "DISCONNECTED" }

        Rectangle {
            id:     channel3Background
            width:  label3.width
            height: label3.height
            color:  "green"

            ColorAnimation on color {
                id:         channel3Animate
                to:         "white"
                duration:   500
            }

            QGCLabel { id: label3; text: "Channel 3" }
        }
        QGCLabel { text: channel3Active ? (qsTr("%1 %2% %3c %4g").arg(channel3PulseValue.toFixed(3)).arg(channel3PulsePercent.toFixed(1)).arg(channel3CPUTemp).arg(channel3Gain)) : "DISCONNECTED" }
    }

    Rectangle {
        id:             freqEditor
        anchors.fill:   parent
        color:          qgcPal.window
        visible:        false

        ColumnLayout {
            anchors.margins:    _margins
            anchors.fill:       parent
            spacing:            ScreenTools.defaultFontPixelHeight

            FactTextField {
                Layout.fillWidth:   true
                fact:               _settings.frequency
            }

            QGCButton {
                Layout.fillWidth:   true
                text:               "Close"
                onClicked:          freqEditor.visible = false
            }
        }
    }

    Rectangle {
        id:             gainEditor
        anchors.fill:   parent
        color:          qgcPal.window
        visible:        false

        ColumnLayout {
            anchors.margins:    _margins
            anchors.fill:       parent
            spacing:            ScreenTools.defaultFontPixelHeight

            FactCheckBox {
                fact:   _settings.autoGain
                text:   "Auto-Gain"
            }

            FactTextField {
                Layout.fillWidth:   true
                fact:               _settings.gain
            }

            QGCButton {
                Layout.fillWidth:   true
                text:               "Close"
                onClicked:          gainEditor.visible = false
            }
        }
    }
}
