#pragma once

#include <QObject>
#include <QGeoCoordinate>
#include <QFile>
#include <QTextStream>
#include <QTimer>

class Pulse : public QObject
{
    Q_OBJECT

public:
    Pulse(bool captureRawData);
    ~Pulse();

    void clearFiles(void);
    void startReplay(void);

    Q_PROPERTY(bool             captureMode     MEMBER _captureRawData  CONSTANT)
    Q_PROPERTY(QGeoCoordinate   planeCoordinate MEMBER _planeCoordinate   NOTIFY planeCoordinateChanged)
    Q_PROPERTY(double           planeHeading    MEMBER _planeHeading    NOTIFY planeHeadingChanged)

    Q_INVOKABLE void    setFreq         (int freq);
    Q_INVOKABLE void    setGain         (int gain);
    Q_INVOKABLE double  log10           (double value);
    Q_INVOKABLE void    pulseTrajectory (const QGeoCoordinate coord, double travelHeading, double pulseHeading);
    Q_INVOKABLE void    rawData         (double lat, double lon, int channel, double pulseValue);

signals:
    void pulse                  (int channelIndex, float cpuTemp, double pulseValue);
    void setGainSignal          (int gain);
    void setFreqSignal          (int freq);
    void planeCoordinateChanged (QGeoCoordinate currentLocation);
    void planeHeadingChanged    (double heading);

private slots:
    void _readNextPulse(void);

private:
    QFile           _replayFile;
    QTextStream*    _replayStream;
    qint64          _lastReplayMsecs;
    QTimer          _replayTimer;
    QString         _nextRawDataLine;
    bool            _captureRawData;
    QGeoCoordinate  _planeCoordinate;
    double          _planeHeading;
};

