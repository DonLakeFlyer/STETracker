/****************************************************************************
 *
 *   (c) 2009-2016 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "STETrackerSettings.h"

#include <QQmlEngine>
#include <QtQml>

DECLARE_SETTINGGROUP(STETracker, "STETracker")
{
    QQmlEngine::setObjectOwnership(this, QQmlEngine::CppOwnership); \
    qmlRegisterUncreatableType<STETrackerSettings>("QGroundControl.SettingsManager", 1, 0, "STETrackerSettings", "Reference only"); \
}

DECLARE_SETTINGSFACT(STETrackerSettings, frequency)
DECLARE_SETTINGSFACT(STETrackerSettings, gain)
DECLARE_SETTINGSFACT(STETrackerSettings, autoGain)
