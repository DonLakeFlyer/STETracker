#include "Pulse.h"

#include <QDebug>
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QTime>

#include <cmath>

Pulse::Pulse(bool captureRawData)
    : _replayStream     (nullptr)
    , _captureRawData   (captureRawData)
    , _planeHeading     (0)
{
    _replayTimer.setSingleShot(true);
    _replayTimer.setTimerType(Qt::PreciseTimer);

    connect(&_replayTimer, &QTimer::timeout, this, &Pulse::_readNextPulse);
}

Pulse::~Pulse()
{
    _replayFile.close();
    delete _replayStream;
}

void Pulse::setFreq(int freq)
{
    //qDebug() << "Pulse::setFreq" << freq;
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
    QDir    writeDir(QStandardPaths::writableLocation(QStandardPaths::DownloadLocation));
    QFile   file1(writeDir.filePath(QStringLiteral("pulse.csv")));
    QFile   file2(writeDir.filePath(QStringLiteral("rawData.csv")));
    file1.remove();
    file2.remove();
}


void Pulse::pulseTrajectory(const QGeoCoordinate coord, double travelHeading, double pulseHeading)
{
    if (_captureRawData) {
        QDir    writeDir(QStandardPaths::writableLocation(QStandardPaths::DownloadLocation));
        QFile   file(writeDir.filePath(QStringLiteral("pulse.csv")));

        qDebug() << writeDir;
        if (file.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
            file.write((QStringLiteral("%1,%2,%3,%4\n").arg(coord.latitude(),0,'f',6).arg(coord.longitude(),0,'f',6).arg(travelHeading).arg(pulseHeading)).toUtf8().constData());
        } else {
            qDebug() << "Pulse file open failed" << writeDir << writeDir.exists() << file.fileName() << file.errorString();
        }
        //qDebug() << coord << travelHeading << pulseHeading;
    }
}

void Pulse::rawData(double lat, double lon, int channel, double pulse)
{
    qDebug() << "rawDat" << lat << lon;
    if (_captureRawData) {
        QDir    writeDir(QStandardPaths::writableLocation(QStandardPaths::DownloadLocation));
        QFile   file(writeDir.filePath(QStringLiteral("rawData.csv")));

        if (file.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
            file.write((QStringLiteral("%1,%2,%3,%4,%5\n").arg(QDateTime::currentMSecsSinceEpoch()).arg(lat).arg(lon).arg(channel).arg(pulse)).toUtf8().constData());
        } else {
            qDebug() << "Raw data file open failed" << writeDir << writeDir.exists() << file.fileName() << file.errorString();
        }
    }
}

void Pulse::startReplay(void)
{
    QDir    writeDir(QStandardPaths::writableLocation(QStandardPaths::DownloadLocation));

    _replayFile.setFileName(writeDir.filePath(QStringLiteral("rawData.csv")));

    if (_replayFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        _replayStream = new QTextStream(&_replayFile);
        _nextRawDataLine = _replayStream->readLine();
        _readNextPulse();
    } else {
        qDebug() << "Replay file open failed" << writeDir << writeDir.exists() << _replayFile.fileName() << _replayFile.errorString();
    }
}

void Pulse::_readNextPulse(void)
{
    QStringList rgParts = _nextRawDataLine.split(",");
    //qDebug() << rgParts;

    _lastReplayMsecs = rgParts[0].toLong();
    emit pulse(rgParts[3].toInt(), 0, rgParts[4].toDouble());

    _planeCoordinate = QGeoCoordinate(rgParts[1].toDouble(), rgParts[2].toDouble());
    emit planeCoordinateChanged(_planeCoordinate);

    if (!_replayStream->atEnd()) {
        _nextRawDataLine = _replayStream->readLine();
        qint64 nextMsecs = _nextRawDataLine.split(",")[0].toLong();
        //qDebug() << nextMsecs << _lastReplayMsecs << nextMsecs - _lastReplayMsecs;
        _replayTimer.start(nextMsecs - _lastReplayMsecs);
    }
}
