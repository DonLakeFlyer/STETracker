#pragma once

#include <QObject>
#include <QGeoCoordinate>
#include <QFile>
#include <QTextStream>
#include <QTimer>
#include <QDir>

#include "PositionManager.h"
#include "QmlObjectListModel.h"

class Pulse : public QObject
{
    Q_OBJECT

public:
    Pulse(bool replay);
    ~Pulse();

    void clearFiles(void);
    void startReplay(void);

    Q_PROPERTY(QGeoCoordinate       planeCoordinate     MEMBER _planeCoordinate NOTIFY planeCoordinateChanged)
    Q_PROPERTY(double               planeHeading        MEMBER _planeHeading    NOTIFY planeHeadingChanged)
    Q_PROPERTY(QmlObjectListModel*  pulseTrajectories   READ pulseTrajectories  CONSTANT)

    Q_INVOKABLE void    setFreq         (int freq);
    Q_INVOKABLE void    setGain         (int gain);
    Q_INVOKABLE double  log10           (double value);
    Q_INVOKABLE void    pulseTrajectory (double pulseHeading);

    QGeoCoordinate      planeCoordinate     (void) const { return _posMgr->gcsPosition(); }
    double              planeHeading        (void) const { return _posMgr->gcsHeading(); }
    QmlObjectListModel* pulseTrajectories   (void) { return &_pulseTrajectories; }

signals:
    void pulse                  (bool tcpLink, int channelIndex, float cpuTemp, double pulseValue, int gain);
    void setGainSignal          (int gain);
    void setFreqSignal          (int freq);
    void planeCoordinateChanged (QGeoCoordinate currentLocation);
    void planeHeadingChanged    (double heading);

private slots:
    void _readNextPulse         (void);
    void _rawData               (bool tcpLink, int channelIndex, float cpuTemp, double pulseValue, int gain);
    void _setPlaneCoordinate    (QGeoCoordinate coordinate);
    void _setPlaneHeading       (double heading);

private:
    QFile               _replayFile;
    QTextStream*        _replayStream;
    qint64              _lastReplayMsecs;
    QTimer              _replayTimer;
    QString             _nextRawDataLine;
    bool                _replay;
    QGeoCoordinate      _planeCoordinate;
    double              _planeHeading;
    QDir                _dataDir;
    QGCPositionManager* _posMgr;
    QmlObjectListModel  _pulseTrajectories;
};

class PulseTrajectory : public QObject
{
    Q_OBJECT

public:
    PulseTrajectory(const QGeoCoordinate& coordinate, double heading, QObject* parent = NULL);

    Q_PROPERTY(QGeoCoordinate   coordinate  MEMBER _coordinate  CONSTANT)
    Q_PROPERTY(double           heading     MEMBER _heading     CONSTANT)

private:
    QGeoCoordinate  _coordinate;
    double          _heading;
};

