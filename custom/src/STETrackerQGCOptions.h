#pragma once

#include "QGCOptions.h"

class STETrackerQGCPlugin;

class STETrackerQGCOptions : public QGCOptions
{
public:
    STETrackerQGCOptions(STETrackerQGCPlugin* plugin, QObject* parent = NULL);

    QUrl flyViewOverlay  (void) const { return QUrl::fromUserInput("qrc:/qml/VHFTrackerFlyViewOverlay.qml"); }

private:
    STETrackerQGCPlugin*  _vhfQGCPlugin;
};
