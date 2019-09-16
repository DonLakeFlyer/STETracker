#pragma once

#include <QString>
#include <QList>
#include <QMap>
#include <QMutex>
#include <QUdpSocket>
#include <QMutexLocker>
#include <QQueue>
#include <QByteArray>
#include <QThread>

#include "STETCPLink.h"
#include "Pulse.h"

class UDPCLient {
public:
    UDPCLient(const QHostAddress& address_, quint16 port_)
        : address(address_)
        , port(port_)
    {}
    UDPCLient(const UDPCLient* other)
        : address(other->address)
        , port(other->port)
    {}
    QHostAddress    address;
    quint16         port;
};

class STEUDPLink : public QThread
{
    Q_OBJECT

public:
    STEUDPLink(Pulse* pulse);
    ~STEUDPLink();

    bool    isConnected             () const;

    // Thread
    void    run                     ();

signals:
    void pulse(int channelIndex, float cpuTemp, float pulseValue, int gain);

public slots:
    void setGain(int gain);
    void setFreq(int freq);

private slots:
    void    _readBytes  (void);
    void    _writeBytes (const QByteArray data);

private:
    bool    _connect                (void);
    void    _disconnect             (void);

    bool    _isIpLocal              (const QHostAddress& add);
    bool    _hardwareConnect        ();
    void    _writeDataGram          (const QByteArray data, const UDPCLient* target);

    Pulse*                  _pulse;
    bool                    _running;
    QUdpSocket*             _socket;
    bool                    _connectState;
    QList<UDPCLient*>       _sessionTargets;
    QList<QHostAddress>     _localAddresses;
    QList<int>              _rgExpectedIndex;
    QList<STETCPLink*>      _rgTCPLinks;
};

