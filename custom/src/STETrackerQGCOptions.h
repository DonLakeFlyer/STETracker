#pragma once

#include "QGCOptions.h"

class STETrackerQGCPlugin;

class STETrackerQGCOptions : public QGCOptions
{
public:
    STETrackerQGCOptions(STETrackerQGCPlugin* plugin, QObject* parent = NULL);

private:
    STETrackerQGCPlugin*  _vhfQGCPlugin;
};
