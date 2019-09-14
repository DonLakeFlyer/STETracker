#include "STETrackerQGCPlugin.h"
#include "STETrackerSettings.h"
#include "QGCApplication.h"
#include "AppSettings.h"

#include <QDebug>

#define REPLAY

QGC_LOGGING_CATEGORY(STETrackerQGCPluginLog, "STETrackerQGCPluginLog")

STETrackerQGCPlugin::STETrackerQGCPlugin(QGCApplication *app, QGCToolbox* toolbox)
    : QGCCorePlugin         (app, toolbox)
#ifdef REPLAY
    , _pulse    (false /* captureRawData */)
#else
    , _pulse    (true /* captureRawData */)
#endif
{
    //_showAdvancedUI = false;

    _udpLink.connect(&_udpLink, &STEUDPLink::pulse,     &_pulse,     &Pulse::pulse);
    _pulse.connect(&_pulse,     &Pulse::setGainSignal,  &_udpLink,   &STEUDPLink::setGain);
    _pulse.connect(&_pulse,     &Pulse::setFreqSignal,  &_udpLink,   &STEUDPLink::setFreq);
}

STETrackerQGCPlugin::~STETrackerQGCPlugin()
{

}

void STETrackerQGCPlugin::setToolbox(QGCToolbox* toolbox)
{
    QGCCorePlugin::setToolbox(toolbox);

    _vhfSettings =      new STETrackerSettings(this);
    _vhfQGCOptions =    new STETrackerQGCOptions(this, this);

#ifdef REPLAY
    _pulse.startReplay();
#else
    _pulse.clearFiles();
#endif
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
