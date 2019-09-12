message("Adding Sentera plugin")

DEFINES += CUSTOMHEADER=\"\\\"STETrackerQGCPlugin.h\\\"\"
DEFINES += CUSTOMCLASS=STETrackerQGCPlugin

DEFINES += QGC_APPLICATION_NAME='"\\\"STE VHF Tracker\\\""'
DEFINES += QGC_ORG_NAME=\"\\\"LatestFiasco.org\\\"\"
DEFINES += QGC_ORG_DOMAIN=\"\\\"org.latestfiasco\\\"\"

CONFIG  += QGC_DISABLE_APM_PLUGIN QGC_DISABLE_APM_PLUGIN_FACTORY QGC_DISABLE_PX4_PLUGIN QGC_DISABLE_PX4_PLUGIN_FACTORY

QGC_ORG_NAME        = "LatestFiasco.org"
QGC_ORG_DOMAIN      = "org.latestfiasco"
QGC_APP_DESCRIPTION = "STE VHF Tracker"
QGC_APP_COPYRIGHT   = "Copyright (C) 2017 Don Gagne. All rights reserved."
QGC_APP_NAME        = "STE VHF Tracker"
TARGET              = "STEVHFTracker"

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

SOURCES += \
    $$PWD/src/DirectionMapItem.cc \
    $$PWD/src/LineMapItem.cc \
    $$PWD/src/STETrackerQGCOptions.cc \
    $$PWD/src/STETrackerQGCPlugin.cc \
    $$PWD/src/STETrackerSettings.cc \
