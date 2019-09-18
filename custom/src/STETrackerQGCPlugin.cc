#include "STETrackerQGCPlugin.h"
#include "STETrackerSettings.h"
#include "QGCApplication.h"
#include "AppSettings.h"

#include <QDebug>

#define REPLAY

QGC_LOGGING_CATEGORY(STETrackerQGCPluginLog, "STETrackerQGCPluginLog")

STETrackerQGCPlugin::STETrackerQGCPlugin(QGCApplication *app, QGCToolbox* toolbox)
    : QGCCorePlugin (app, toolbox)
    , _udpLink      (nullptr)
    , _pulse        (nullptr)
{
    //_showAdvancedUI = false;
}

STETrackerQGCPlugin::~STETrackerQGCPlugin()
{
    delete _udpLink;
    delete _pulse;
}

void STETrackerQGCPlugin::setToolbox(QGCToolbox* toolbox)
{
    QGCCorePlugin::setToolbox(toolbox);

    _vhfSettings =      new STETrackerSettings(this);
    _vhfQGCOptions =    new STETrackerQGCOptions(this, this);
}

void STETrackerQGCPlugin::allReady(void)
{
#ifdef REPLAY
    _pulse = new Pulse(true /* replay */);
#else
    _pulse = new Pulse(false /* replay */);
#endif

    _udpLink = new STEUDPLink(_pulse);
}


QString STETrackerQGCPlugin::brandImageIndoor(void) const
{
    return QStringLiteral("/res/PaintedDogsLogo.png");
}

QString STETrackerQGCPlugin::brandImageOutdoor(void) const
{
    return QStringLiteral("/res/PaintedDogsLogo.png");
}

QVariantList& STETrackerQGCPlugin::settingsPages(void)
{
    if(_settingsPages.size() == 0) {
        _settingsPages = QGCCorePlugin::settingsPages();
    }

    return _settingsPages;
}
