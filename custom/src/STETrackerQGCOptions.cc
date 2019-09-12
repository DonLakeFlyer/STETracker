#include "STETrackerQGCOptions.h"
#include "STETrackerQGCOptions.h"

STETrackerQGCOptions::STETrackerQGCOptions(STETrackerQGCPlugin* plugin, QObject* parent)
    : QGCOptions    (parent)
    , _vhfQGCPlugin (plugin)
{

}
