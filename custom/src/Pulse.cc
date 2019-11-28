#include "Pulse.h"
#include "QGCApplication.h"
#include "AppSettings.h"
#include "SettingsManager.h"
#include "PositionManager.h"

#include <QDebug>
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QTime>

#include <cmath>

Pulse::Pulse(bool replay)
    : _replayStream     (nullptr)
    , _replay           (replay)
    , _posMgr           (qgcApp()->toolbox()->qgcPositionManager())
    , _trackTrajectories(false)
{
    _replayTimer.setSingleShot(true);
    _replayTimer.setTimerType(Qt::PreciseTimer);

    _rgPulse[0] = _rgPulse[1] = _rgPulse[2] = _rgPulse[3] = qQNaN();

    _dataDir.setPath(qgcApp()->toolbox()->settingsManager()->appSettings()->telemetrySavePath());

    if (_replay) {
        connect(&_replayTimer,  &QTimer::timeout,                           this, &Pulse::_readNextPulse);
        startReplay();
    } else {
        connect(this,           &Pulse::pulse,                              this, &Pulse::_rawData);
        connect(_posMgr,        &QGCPositionManager::gcsPositionChanged,    this, &Pulse::_setPlaneCoordinate);
        connect(_posMgr,        &QGCPositionManager::gcsHeadingChanged,     this, &Pulse::_setPlaneHeading);

        clearFiles();
    }
}

Pulse::~Pulse()
{
    _replayFile.close();
    delete _replayStream;
}

void Pulse::setFreq(int freq)
{
    emit setFreqSignal(freq);
}

void Pulse::setGain(int gain)
{
    emit setGainSignal(gain);
}

double Pulse::log10(double value)
{
    return ::log10(value);
}

void Pulse::clearFiles(void)
{
    QFile   file1(_dataDir.filePath(QStringLiteral("pulse.csv")));
    QFile   file2(_dataDir.filePath(QStringLiteral("rawData.csv")));
    file1.remove();
    file2.remove();
}


void Pulse::pulseTrajectory(double pulseHeading)
{
    if (qIsNaN(_collarHeading) || !qFuzzyCompare(_collarHeading, pulseHeading)) {
        _collarHeading = pulseHeading;
        emit collarHeadingChanged(_collarHeading);
    }

    if (!_trackTrajectories) {
        return;
    }

    if (_planeCoordinate.isValid()) {
        _pulseTrajectories.append(new PulseTrajectory(_planeCoordinate, _planeHeading + pulseHeading, this));
    }

    if (!_replay) {
        QFile   file(_dataDir.filePath(QStringLiteral("pulse.csv")));

        if (file.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
            file.write((QStringLiteral("%1,%2,%3,%4,%5\n").arg(QDateTime::currentMSecsSinceEpoch()).arg(planeCoordinate().latitude(),0,'f',6).arg(planeCoordinate().longitude(),0,'f',6).arg(planeHeading()).arg(pulseHeading)).toUtf8().constData());
        } else {
            qDebug() << "Pulse file open failed" << file.fileName() << file.errorString();
        }
        //qDebug() << coord << travelHeading << pulseHeading;
    }
}

void Pulse::_rawData(bool /*tcpLink*/, int channelIndex, float cpuTemp, double pulseValue, int gain)
{
    QFile   file(_dataDir.filePath(QStringLiteral("rawData.csv")));

    if (file.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
        static bool firstLine = true;

        if (firstLine) {
            firstLine = false;
            file.write("Msecs,Lat,Lon,Heading,Channel,Temp,Pulse,Gain\n");
        }
        file.write((QStringLiteral("%1,%2,%3,%4,%5,%6,%7,%8\n").arg(QDateTime::currentMSecsSinceEpoch()).arg(planeCoordinate().latitude(),0,'f',6).arg(planeCoordinate().longitude(),0,'f',6).arg(planeHeading()).arg(channelIndex).arg(cpuTemp).arg(pulseValue).arg(gain)).toUtf8().constData());
    } else {
        qDebug() << "Raw data file open failed" << file.fileName() << file.errorString();
    }
}

void Pulse::startReplay(void)
{
    _replayFile.setFileName(_dataDir.filePath(QStringLiteral("/Users/Don/Documents/BuffaloSprings.rawData.csv")));
    //_replayFile.setFileName(":/rawdata/rawData.csv");

    if (_replayFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        _replayStream = new QTextStream(&_replayFile);
        _nextRawDataLine = _replayStream->readLine();   // Skip over header line
        _nextRawDataLine = _replayStream->readLine();
        _replayPaused = false;
        emit replayPausedChanged(_replayPaused);
        _readNextPulse();
    } else {
        qDebug() << "Replay file open failed" << _replayFile.fileName() << _replayFile.errorString();
    }
}

void Pulse::_readNextPulse(void)
{
    QStringList rgParts = _nextRawDataLine.split(",");
    //qDebug() << rgParts;

    _lastReplayMsecs = rgParts[0].toULongLong();

    _planeCoordinate = QGeoCoordinate(rgParts[1].toDouble(), rgParts[2].toDouble());
    emit planeCoordinateChanged(_planeCoordinate);

    _planeHeading = rgParts[3].toDouble();
    emit planeHeadingChanged(_planeHeading);

    int channelIndex = rgParts[4].toInt();
    double pulseValue = rgParts[6].toDouble();

    if (qIsNaN(_rgPulse[channelIndex])) {
        _rgPulse[channelIndex] = pulseValue;
    } else {
        _rgPulse[channelIndex] = (_rgPulse[channelIndex] * 0.9) + (pulseValue * 0.1);
    }

    emit pulse(nullptr, channelIndex, rgParts[5].toDouble(), _rgPulse[channelIndex], rgParts[7].toInt());

    if (!_replayStream->atEnd()) {
        _nextRawDataLine = _replayStream->readLine();
        qint64 nextMsecs = _nextRawDataLine.split(",")[0].toULongLong();
        //qDebug() << nextMsecs << _lastReplayMsecs << nextMsecs - _lastReplayMsecs;
        if (!_replayPaused) {
            _replayTimer.start((nextMsecs - _lastReplayMsecs) / _replaySpeed);
        }
    }
}

void Pulse::_setPlaneCoordinate(QGeoCoordinate coordinate)
{
    _planeCoordinate = coordinate;
    emit planeCoordinateChanged(coordinate);
}

void Pulse::_setPlaneHeading(double heading)
{
    _planeHeading = heading;
    emit planeHeadingChanged(heading);
}

void Pulse::clearTrajectories(void)
{
    _pulseTrajectories.clearAndDeleteContents();
}

void Pulse::toggleReplay(void)
{
    _replayPaused = !_replayPaused;
    emit replayPausedChanged(_replayPaused);
    if (!_replayPaused) {
        _replayTimer.start(1);
    }
}

void Pulse::stepReplay(void)
{
    _replayTimer.start(1);
}

PulseTrajectory::PulseTrajectory(const QGeoCoordinate& coordinate, double heading, QObject* parent)
    : QObject       (parent)
    , _coordinate   (coordinate)
    , _heading      (heading)
{

}
