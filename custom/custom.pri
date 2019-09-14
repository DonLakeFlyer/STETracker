message("Adding Sentera plugin")

DEFINES += CUSTOMHEADER=\"\\\"STETrackerQGCPlugin.h\\\"\"
DEFINES += CUSTOMCLASS=STETrackerQGCPlugin

DEFINES += QGC_APPLICATION_NAME='"\\\"STE Tracker\\\""'
DEFINES += QGC_ORG_NAME=\"\\\"LatestFiasco.org\\\"\"
DEFINES += QGC_ORG_DOMAIN=\"\\\"org.latestfiasco\\\"\"

CONFIG  += QGC_DISABLE_APM_PLUGIN QGC_DISABLE_APM_PLUGIN_FACTORY QGC_DISABLE_PX4_PLUGIN QGC_DISABLE_PX4_PLUGIN_FACTORY

QGC_ORG_NAME        = "LatestFiasco.org"
QGC_ORG_DOMAIN      = "org.latestfiasco"
QGC_APP_DESCRIPTION = "STE Tracker"
QGC_APP_COPYRIGHT   = "Copyright (C) 2019 Don Gagne. All rights reserved."
QGC_APP_NAME        = "STE Tracker"
TARGET              = "STETracker"

RESOURCES += \
    $$PWD/STETrackerQGCPlugin.qrc \

INCLUDEPATH += \
    $$PWD/src \

HEADERS += \
    $$PWD/src/DirectionMapItem.h \
    $$PWD/src/LineMapItem.h \
    $$PWD/src/STETrackerQGCOptions.h \
    $$PWD/src/STETrackerQGCPlugin.h \
    $$PWD/src/STETrackerSettings.h \
    $$PWD/src/STEUDPLink.h \
    $$PWD/src/Pulse.h \

SOURCES += \
    $$PWD/src/DirectionMapItem.cc \
    $$PWD/src/LineMapItem.cc \
    $$PWD/src/STETrackerQGCOptions.cc \
    $$PWD/src/STETrackerQGCPlugin.cc \
    $$PWD/src/STETrackerSettings.cc \
    $$PWD/src/STEUDPLink.cc \
    $$PWD/src/Pulse.cc \
