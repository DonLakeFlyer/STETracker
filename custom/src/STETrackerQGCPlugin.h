#pragma once

#include "QGCCorePlugin.h"
#include "QmlObjectListModel.h"
#include "SettingsFact.h"
#include "STETrackerQGCOptions.h"
#include "QGCLoggingCategory.h"
#include "Pulse.h"
#include "STEUDPLink.h"

#include <QElapsedTimer>
#include <QGeoCoordinate>
#include <QTimer>

class STETrackerSettings;

Q_DECLARE_LOGGING_CATEGORY(STETrackerQGCPluginLog)

class STETrackerQGCPlugin : public QGCCorePlugin
{
    Q_OBJECT

public:
    STETrackerQGCPlugin(QGCApplication* app, QGCToolbox* toolbox);
    ~STETrackerQGCPlugin();

    Q_PROPERTY(STETrackerSettings*  vhfSettings MEMBER _vhfSettings CONSTANT)
    Q_PROPERTY(Pulse*               pulse       READ pulse          CONSTANT)

    Pulse* pulse(void) { return &_pulse; }

    // Overrides from QGCCorePlugin
    QString             brandImageIndoor        (void) const final;
    QString             brandImageOutdoor       (void) const final;
    QVariantList&       settingsPages           (void) final;
    QGCOptions*         options                 (void) final { return qobject_cast<QGCOptions*>(_vhfQGCOptions); }

    // Overrides from QGCTool
    void setToolbox(QGCToolbox* toolbox) final;

signals:

private slots:

private:

    QVariantList            _settingsPages;
    STETrackerQGCOptions*   _vhfQGCOptions;
    STETrackerSettings*     _vhfSettings;
    STEUDPLink              _udpLink;
    Pulse                   _pulse;
};
