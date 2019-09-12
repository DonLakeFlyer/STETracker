/****************************************************************************
 *
 *   (c) 2009-2016 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "STETrackerSettings.h"
#include "QGCPalette.h"
#include "QGCApplication.h"

#include <QQmlEngine>
#include <QtQml>
#include <QStandardPaths>

const char* STETrackerSettings::_settingsGroup =        "STETracker";
const char* STETrackerSettings::_altitudeFactName =     "Altitude";
const char* STETrackerSettings::_divisionsFactName =    "Divisions";
const char* STETrackerSettings::_frequencyFactName =    "Frequency";
const char* STETrackerSettings::_maxPulseFactName =     "MaxPulse";
const char* STETrackerSettings::_gainFactName =         "gain";

STETrackerSettings::STETrackerSettings(QObject* parent)
    : SettingsGroup     (_settingsGroup, _settingsGroup, parent)
    , _altitudeFact     (nullptr)
    , _divisionsFact    (nullptr)
    , _frequencyFact    (nullptr)
    , _maxPulseFact     (nullptr)
    , _gainFact         (nullptr)
{
    QQmlEngine::setObjectOwnership(this, QQmlEngine::CppOwnership);
    qmlRegisterUncreatableType<STETrackerSettings>("QGroundControl.SettingsManager", 1, 0, "STETrackerSettings", "Reference only");
}

Fact* STETrackerSettings::altitude(void)
{
    if (!_altitudeFact) {
        _altitudeFact = _createSettingsFact(_altitudeFactName);
    }

    return _altitudeFact;
}

Fact* STETrackerSettings::divisions(void)
{
    if (!_divisionsFact) {
        _divisionsFact = _createSettingsFact(_divisionsFactName);
    }

    return _divisionsFact;
}

Fact* STETrackerSettings::frequency(void)
{
    if (!_frequencyFact) {
        _frequencyFact = _createSettingsFact(_frequencyFactName);
    }

    return _frequencyFact;
}

Fact* STETrackerSettings::maxPulse(void)
{
    if (!_maxPulseFact) {
        _maxPulseFact = _createSettingsFact(_maxPulseFactName);
    }

    return _maxPulseFact;
}

Fact* STETrackerSettings::gain(void)
{
    if (!_gainFact) {
        _gainFact = _createSettingsFact(_gainFactName);
    }

    return _gainFact;
}
