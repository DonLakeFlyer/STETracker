#include <QtGlobal>
#include <QTimer>
#include <QList>
#include <QDebug>
#include <QMutexLocker>
#include <QNetworkProxy>
#include <QNetworkInterface>
#include <iostream>
#include <QHostInfo>
#include <QDateTime>

#include "STEUDPLink.h"

#define REMOVE_GONE_HOSTS 0

static bool contains_target(const QList<UDPCLient*> list, const QHostAddress& address, quint16 port)
{
    for(UDPCLient* target: list) {
        if(target->address == address && target->port == port) {
            return true;
        }
    }
    return false;
}

STEUDPLink::STEUDPLink(Pulse* pulse)
    : _pulse        (pulse)
    , _running      (false)
    , _socket       (Q_NULLPTR)
    , _connectState (false)
{
    connect(this, &STEUDPLink::pulse, _pulse, &Pulse::pulse);

    for (const QHostAddress &address: QNetworkInterface::allAddresses()) {
        _localAddresses.append(QHostAddress(address));
    }
    moveToThread(this);
    _connect();

    _rgExpectedIndex << 0 << 0 << 0 << 0;
}

STEUDPLink::~STEUDPLink()
{
    _disconnect();
    // Tell the thread to exit
    _running = false;
    // Clear client list
    qDeleteAll(_sessionTargets);
    _sessionTargets.clear();
    quit();
    // Wait for it to exit
    wait();
    this->deleteLater();
}

void STEUDPLink::run()
{
    if (_hardwareConnect()) {
        exec();
    }
    if (_socket) {
        _socket->close();
    }
}

bool STEUDPLink::_isIpLocal(const QHostAddress& add)
{
    // In simulation and testing setups the vehicle and the GCS can be
    // running on the same host. This leads to packets arriving through
    // the local network or the loopback adapter, which makes it look
    // like the vehicle is connected through two different links,
    // complicating routing.
    //
    // We detect this case and force all traffic to a simulated instance
    // onto the local loopback interface.
    // Run through all IPv4 interfaces and check if their canonical
    // IP address in string representation matches the source IP address
    //
    // On Windows, this is a very expensive call only Redmond would know
    // why. As such, we make it once and keep the list locally. If a new
    // interface shows up after we start, it won't be on this list.
    for (const QHostAddress &address: _localAddresses) {
        if (address == add) {
            // This is a local address of the same host
            return true;
        }
    }
    return false;
}

void STEUDPLink::_writeBytes(const QByteArray data)
{
    if (!_socket) {
        return;
    }

    // Send to all connected systems
    for(UDPCLient* target: _sessionTargets) {
        _writeDataGram(data, target);
    }
}

void STEUDPLink::_writeDataGram(const QByteArray data, const UDPCLient* target)
{
    //qDebug() << "UDP Out" << target->address << target->port;
    if(_socket->writeDatagram(data, target->address, target->port) < 0) {
        qWarning() << "Error writing to" << target->address << target->port;
    }
}

void STEUDPLink::_readBytes()
{
    if (!_socket) {
        return;
    }

    while (_socket->hasPendingDatagrams())
    {
        QByteArray      datagram;
        QHostAddress    sender;
        quint16         senderPort;
        int             channelIndex;

        datagram.resize(static_cast<int>(_socket->pendingDatagramSize()));

        _socket->readDatagram(datagram.data(), datagram.size(), &sender, &senderPort);

        // Format should be
        //  int -   send index
        //  int -   channel index
        //  float - pulse value
        //  float - cpu temp
        //  int -   freq
        //  int -   gain
        int expectedSize = (sizeof(int) * 4) + (sizeof(float) * 2);
        if (datagram.size() == expectedSize) {
            struct PulseInfo_s {
                int     sendIndex;
                int     channelIndex;
                float   pulseValue;
                float   cpuTemp;
                int     freq;
                int     gain;
            };
            const struct PulseInfo_s* pulseInfo = (const struct PulseInfo_s*)datagram.constData();

            channelIndex = pulseInfo->channelIndex;
            if (pulseInfo->sendIndex == _rgExpectedIndex[pulseInfo->channelIndex] - 1) {
                qDebug() << "Multi-send";
                return;
            }
            if (pulseInfo->sendIndex != _rgExpectedIndex[pulseInfo->channelIndex]) {
                qWarning() << "Lost packet channel:expected:actual" << pulseInfo->channelIndex << _rgExpectedIndex[pulseInfo->channelIndex] << pulseInfo->sendIndex;
            }
            _rgExpectedIndex[pulseInfo->channelIndex] = pulseInfo->sendIndex + 1;

            //qDebug() << "Pulse" << pulseInfo->channelIndex << pulseInfo->cpuTemp << pulseInfo->pulseValue << pulseInfo->freq;
            emit pulse(false, pulseInfo->channelIndex, pulseInfo->cpuTemp, pulseInfo->pulseValue, pulseInfo->gain);
        } else {
            qWarning() << "Bad datagram size actual:expected" << datagram.size() << expectedSize;
            return;
        }

        QHostAddress asender = sender;
        if (_isIpLocal(sender)) {
            asender = QHostAddress(QString("127.0.0.1"));
        }

        // Something goes wrong with a connection if we connect too fast, so we stagger then out
        static int lastTime = 0;
        int currentTime = QDateTime::currentSecsSinceEpoch();

        if (!contains_target(_sessionTargets, asender, senderPort) && currentTime - lastTime > 5) {
            lastTime = currentTime;
            qDebug() << "UDP connected" << channelIndex << asender << senderPort;
#if 0
            qDebug() << "TCP connecting to" << channelIndex << asender << 50000;

            // This is a new connection. Crank up the TCP connection for it.

            STETCPLink* tcpLink = new STETCPLink(asender.toString(), 50000);
            //connect(_pulse, &Pulse::setGainSignal, &_udpLink, &STEUDPLink::setGain);
            //connect(_pulse, &Pulse::setFreqSignal, &_udpLink, &STEUDPLink::setFreq);
            connect(tcpLink, &STETCPLink::pulse, _pulse, &Pulse::pulse);
            _rgTCPLinks.append(new STETCPLink(asender.toString(), 50000));
#endif

            UDPCLient* target = new UDPCLient(asender, senderPort);
            _sessionTargets.append(target);
        }
    }
}

void STEUDPLink::_disconnect(void)
{
    _running = false;
    quit();
    wait();
    if (_socket) {
        // Make sure delete happen on correct thread
        _socket->deleteLater();
        _socket = Q_NULLPTR;
    }
    _connectState = false;
}

bool STEUDPLink::_connect(void)
{
    if (this->isRunning() || _running) {
        _running = false;
        quit();
        wait();
    }
    _running = true;
    start(NormalPriority);
    return true;
}

bool STEUDPLink::_hardwareConnect()
{
    if (_socket) {
        delete _socket;
        _socket = Q_NULLPTR;
    }
    QHostAddress host = QHostAddress::AnyIPv4;
    _socket = new QUdpSocket(this);
    _socket->setProxy(QNetworkProxy::NoProxy);
    _connectState = _socket->bind(host, 5007, QAbstractSocket::ReuseAddressHint | QUdpSocket::ShareAddress);
    if (_connectState) {
        _socket->joinMulticastGroup(QHostAddress("224.0.0.1"));
        _socket->setSocketOption(QAbstractSocket::SendBufferSizeSocketOption,     64 * 1024);
        _socket->setSocketOption(QAbstractSocket::ReceiveBufferSizeSocketOption, 128 * 1024);
        QObject::connect(_socket, &QUdpSocket::readyRead, this, &STEUDPLink::_readBytes);
    } else {
        qWarning() << "UDP Link Error binding UDP port" << _socket->errorString();
    }
    return _connectState;
}

void STEUDPLink::setGain(int gain)
{
    QByteArray bytes;
    int command[2];
    command[0] = 1;
    command[1] = gain;
    bytes.setRawData((const char *)&command, sizeof(command));
    //_writeBytes(bytes);
}

void STEUDPLink::setFreq(int freq)
{
    QByteArray bytes;
    int command[2];
    command[0] = 2;
    command[1] = freq;
    bytes.setRawData((const char *)&command, sizeof(command));
    //_writeBytes(bytes);
}
