/****************************************************************************
 *
 *   (c) 2009-2016 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "STETCPLink.h"
#include "QGCApplication.h"
#include "STETrackerQGCPlugin.h"

#include <QTimer>
#include <QList>
#include <QDebug>
#include <QMutexLocker>
#include <iostream>
#include <QHostInfo>
#include <QSignalSpy>

/// @file
///     @brief TCP link type for SITL support
///
///     @author Don Gagne <don@thegagnes.com>

STETCPLink::STETCPLink(const QString &hostName, quint16 port, int channelIndex)
    : _socket           (nullptr)
    , _hostName         (hostName)
    , _port             (port)
    , _channelIndex     (channelIndex)
    , _socketIsConnected(false)
    , _restartTimer     (nullptr)
{
    _rgExpectedIndex << 0 << 0 << 0 << 0;

    _settings = qobject_cast<STETrackerQGCPlugin*>(qgcApp()->toolbox()->corePlugin())->vhfSettings();

    moveToThread(this);
    _connect();
}

STETCPLink::~STETCPLink()
{
    _disconnect();
    // Tell the thread to exit
    quit();
    // Wait for it to exit
    wait();
}

void STETCPLink::run()
{
    _restartTimer = new QTimer(this);
    _restartTimer->setInterval   (10000);
    _restartTimer->setSingleShot (true);
    connect(_restartTimer, &QTimer::timeout, this, &STETCPLink::_restart);


    _hardwareConnect();
    exec();
}

void STETCPLink::_writeBytes(const QByteArray data)
{

    if (_socket) {
        _socket->write(data);
    }
}

/**
 * @brief Read a number of bytes from the interface.
 *
 * @param data Pointer to the data byte array to write the bytes to
 * @param maxLength The maximum number of bytes to write
 **/
void STETCPLink::readBytes()
{
    if (_socket) {
        qint64 byteCount = _socket->bytesAvailable();
        if (!byteCount) {
            return;
        }

        QByteArray buffer;
        buffer.resize(byteCount);
        _socket->read(buffer.data(), buffer.size());

        // Format should be
        //  int -   send index
        //  int -   channel index
        //  float - pulse value
        //  float - cpu temp
        //  int -   freq
        //  int -   gain
        int expectedSize = (sizeof(int) * 4) + (sizeof(float) * 2);
        if (buffer.size() == expectedSize) {
            struct PulseInfo_s {
                int     sendIndex;
                int     channelIndex;
                float   pulseValue;
                float   cpuTemp;
                int     freq;
                int     gain;
            };
            const struct PulseInfo_s* pulseInfo = (const struct PulseInfo_s*)buffer.constData();

            if (pulseInfo->sendIndex != _rgExpectedIndex[pulseInfo->channelIndex]) {
                qWarning() << "Lost packet channel:expected:actual" << pulseInfo->channelIndex << _rgExpectedIndex[pulseInfo->channelIndex] << pulseInfo->sendIndex;
            }
            _rgExpectedIndex[pulseInfo->channelIndex] = pulseInfo->sendIndex + 1;

            //qDebug() << "Pulse" << pulseInfo->channelIndex << pulseInfo->cpuTemp << pulseInfo->pulseValue << pulseInfo->freq;

            double pulseValue = pulseInfo->pulseValue;
#if 0
            if (_settings->filterMinPulse()->rawValue().toBool() &&
                    pulseInfo->pulseValue < _settings->minValidPulse()->rawValue().toDouble()) {
                pulseValue = 0;
            }
#endif
            emit pulse(this, pulseInfo->channelIndex, pulseInfo->cpuTemp, pulseValue, pulseInfo->gain);
        } else {
            qWarning() << "Bad datagram size actual:expected" << buffer.size() << expectedSize;
        }

        _restartTimer->start();
    }
}


/**
 * @brief Disconnect the connection.
 *
 * @return True if connection has been disconnected, false if connection couldn't be disconnected.
 **/
void STETCPLink::_disconnect(void)
{
    if (_socket) {
        _socketIsConnected = false;
        _socket->disconnectFromHost(); // Disconnect tcp
        _socket->waitForDisconnected();
        _socket->deleteLater(); // Make sure delete happens on correct thread
        _socket = NULL;
    }
}

/**
 * @brief Connect the connection.
 *
 * @return True if connection has been established, false if connection couldn't be established.
 **/
bool STETCPLink::_connect(void)
{
    if (isRunning())
    {
        quit();
        wait();
    }
    start(HighPriority);
    return true;
}

bool STETCPLink::_hardwareConnect()
{
    Q_ASSERT(_socket == NULL);

    qDebug() << "TCP attempting connect to" << _hostName << _channelIndex;

    _socket = new QTcpSocket();

    QSignalSpy errorSpy(_socket, static_cast<void (QTcpSocket::*)(QAbstractSocket::SocketError)>(&QTcpSocket::error));
    _socket->connectToHost(_hostName, _port);

    connect(_socket, &QTcpSocket::readyRead,    this, &STETCPLink::readBytes);
    connect(_socket, &QTcpSocket::connected,    this, &STETCPLink::_connected);
    connect(_socket, &QTcpSocket::disconnected, this, &STETCPLink::_disconnected);

    QObject::connect(_socket, static_cast<void (QTcpSocket::*)(QAbstractSocket::SocketError)>(&QTcpSocket::error),          this, &STETCPLink::_socketError);
    QObject::connect(_socket, static_cast<void (QTcpSocket::*)(QAbstractSocket::SocketState)>(&QTcpSocket::stateChanged),   this, &STETCPLink::_stateChanged);

    // Give the socket a second to connect to the other side otherwise error out
    if (_socket->waitForConnected(5000)) {
        _socketIsConnected = true;
        _socket->setSocketOption(QAbstractSocket::KeepAliveOption, 1);
    } else {
        // Whether a failed connection emits an error signal or not is platform specific.
        // So in cases where it is not emitted, we emit one ourselves.
        if (errorSpy.count() == 0) {
            qWarning() << "TCP link did not connect" << _hostName << _channelIndex;
        }
        delete _socket;
        _socket = nullptr;
    }

    return true;
}

void STETCPLink::_socketError(QAbstractSocket::SocketError socketError)
{
    Q_UNUSED(socketError);
    qWarning() << "TCP socket error host:Error" << _hostName << _port  << _channelIndex << _socket->errorString();
    _restart();
}

void STETCPLink::_stateChanged(QAbstractSocket::SocketState socketState)
{
    //qDebug() << "TCP socket state change" << socketState;
}


void STETCPLink::waitForBytesWritten(int msecs)
{
    Q_ASSERT(_socket);
    _socket->waitForBytesWritten(msecs);
}

void STETCPLink::waitForReadyRead(int msecs)
{
    Q_ASSERT(_socket);
    _socket->waitForReadyRead(msecs);
}

void STETCPLink::_restart(void)
{
    qDebug() << "Restarting TCP link" << _hostName << _channelIndex;
    _disconnect();
    _hardwareConnect();
}

void STETCPLink::_connected(void)
{
    qDebug() << "TCP Connected" << _hostName << _channelIndex;
    _restartTimer->start();
}

void STETCPLink::_disconnected(void)
{
    qDebug() << "TCP Disconnected" << _hostName << _channelIndex;
}


void STETCPLink::setGain(int gain)
{
    QByteArray bytes;
    int command[2];
    command[0] = 1;
    command[1] = gain;
    bytes.setRawData((const char *)&command, sizeof(command));
    _writeBytes(bytes);
}

void STETCPLink::setFreq(int freq)
{
    qDebug() << "STETCPLink::setFreq" << freq;
    QByteArray bytes;
    int command[2];
    command[0] = 2;
    command[1] = freq;
    bytes.setRawData((const char *)&command, sizeof(command));
    _writeBytes(bytes);
}
