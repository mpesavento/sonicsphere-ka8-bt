Installing BT connectivity for AES67 streaming output on RPi 3
======================================================

# Find the Raspberry Pi on your local network.
It was written to connect to the `ChateauduFey_guest` wifi account by default

```sh
ping raspberrypi.local
```
Will show the IP addres, if the mDNS is set for the RPi

Scan the network for RPi mac addresses:
```sh
arp -a
```
Will list all clients.
```sh
arp -a | grep b8:27:eb
```
will show the Raspberry pi devices


# ssh in and set up the basics

```sh
ssh sonicsphere@10.72.2.20
```
username: sonicsphere
password: sonicsphere


```sh
# Update your system

sudo apt update
sudo apt upgrade -y

# Install Bluetooth audio packages
sudo apt install -y bluez bluez-tools pulseaudio pulseaudio-module-bluetooth

# Ensure Bluetooth service is running
sudo systemctl enable bluetooth
sudo systemctl start bluetooth
```


Configure PulseAudio for Bluetooth A2DP sink
```sh
sudo nano /etc/pulse/default.pa

# add these lines to the end of the file
load-module module-bluetooth-discover
load-module module-bluetooth-policy
```


-------

# Configure Bluetooth

Change the name of the device.
Edit the Bluetooth configuration file
```sh
sudo nano /etc/bluetooth/main.conf
```
Look for the `[General]` section in the main.conf file and add or modify the line:
`Name = SonicSphereKA8`
If this line is commented out, remove the `#`

The [General] section should look like something like this:
```ini
[General]
Name = SonicSphereKA8

# Major Device Class: Audio/Video (0x04)
# Minor Device Class: Loudspeaker (0x14)
Class = 0x040414
DiscoverableTimeout = 0
PairableTimeout = 0
PageTimeout = 0
JustWorksRepairing = always
AudioFlushTimeout=10

# Prevent automatic connections
AutoConnect=false

# Privacy setting for easier pairing
Privacy=device
```
Note that `AutoEnable=true` should be set to true, and is likely already uncommented in the `[Policy]` section.


Create a custom configuration file for the bluetooth device.
```bash
sudo mkdir -p /etc/bluetooth/
sudo nano /etc/bluetooth/agent.conf
```
Add the following content:
```ini
[Agent]
Capability=NoInputNoOutput
```

Create a D-Bus configuration file to set permissions for the NoInputNoOutput agent.
```bash
sudo nano /etc/dbus-1/system.d/bluetooth-pairing.conf
```
Add the following content:
```xml
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <policy user="root">
    <allow own="org.bluez"/>
    <allow send_destination="org.bluez"/>
    <allow send_interface="org.bluez.Agent1"/>
    <allow send_interface="org.bluez.MediaEndpoint1"/>
    <allow send_interface="org.freedesktop.DBus.ObjectManager"/>
  </policy>
  <policy context="default">
    <allow send_destination="org.bluez"/>
  </policy>
</busconfig>
```



Ensure that the bluetooth setup is persistent as a service. The `bluetoothctl` commands wont stick otherwise.
Edit this file:
`sudo nano /etc/systemd/system/bluetooth-setup.service`

Add the following content
```ini
[Unit]
Description=Bluetooth Setup Service
After=bluetooth.service
Requires=bluetooth.service
Before=pulseaudio.service

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'sleep 2 && /usr/bin/bluetoothctl -- power on'
ExecStart=/bin/sh -c 'sleep 1 && /usr/bin/bluetoothctl -- discoverable on'
# Set Just Works pairing
ExecStart=/bin/sh -c 'sleep 1 && /usr/bin/bluetoothctl -- pairable on'
# Register the agent with a longer sleep to ensure Bluetooth is ready
#ExecStart=/bin/sh -c 'sleep 3 && /usr/bin/bluetoothctl -- agent on'
#ExecStart=/bin/sh -c 'sleep 1 && /usr/bin/bluetoothctl -- agent NoInputNoOutput'
#ExecStart=/bin/sh -c 'sleep 1 && /usr/bin/bluetoothctl -- default-agent'
# Disconnect any connected devices on startup
ExecStart=/bin/sh -c 'sleep 1 && /usr/local/bin/bt-manager.sh disconnect-all || true'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

Create the bt-manager.sh script:
```bash
sudo nano /usr/local/bin/bt-manager.sh
```
Add the following content:
```bash
#!/bin/bash

case "$1" in
  list)
    echo "Paired devices:"
    bluetoothctl devices | cut -d ' ' -f 2-
    ;;
  connect)
    if [ -z "$2" ]; then
      echo "Usage: bt-manager.sh connect <device_address>"
      exit 1
    fi
    echo "Connecting to $2..."
    bluetoothctl connect $2
    ;;
  disconnect)
    if [ -z "$2" ]; then
      echo "Usage: bt-manager.sh disconnect <device_address>"
      exit 1
    fi
    echo "Disconnecting from $2..."
    bluetoothctl disconnect $2
    ;;
  disconnect-all)
    echo "Disconnecting all devices..."
    for device in $(bluetoothctl devices | cut -d ' ' -f 2); do
      echo "Disconnecting $device..."
      bluetoothctl disconnect $device
    done
    ;;
  *)
    echo "Usage: bt-manager.sh [list|connect|disconnect|disconnect-all]"
    ;;
esac
```

Make it executable:
```bash
sudo chmod +x /usr/local/bin/bt-manager.sh
```


Create a separate simple agent script to handle pairing without a pin.
First make sure the python packages are installed:
```
sudo apt-get install -y python3-dbus python3-gi
```
They are typically already installed

Set up the agent script:
```bash
sudo nano /usr/local/bin/bt-agent.py
```
Add the following content:
```python
#!/usr/bin/python3

import dbus
import dbus.service
import dbus.mainloop.glib
from gi.repository import GLib
import sys

BUS_NAME = 'org.bluez'
AGENT_PATH = '/org/bluez/agent'
AGENT_INTERFACE = 'org.bluez.Agent1'
ADAPTER_PATH = '/org/bluez/hci0'

class Agent(dbus.service.Object):
    @dbus.service.method(AGENT_INTERFACE, in_signature="os", out_signature="")
    def AuthorizeService(self, device, uuid):
        print("AuthorizeService: %s, %s" % (device, uuid))
        return

    @dbus.service.method(AGENT_INTERFACE, in_signature="o", out_signature="s")
    def RequestPinCode(self, device):
        print("RequestPinCode: %s" % (device))
        return "0000"

    @dbus.service.method(AGENT_INTERFACE, in_signature="o", out_signature="u")
    def RequestPasskey(self, device):
        print("RequestPasskey: %s" % (device))
        return 0

    @dbus.service.method(AGENT_INTERFACE, in_signature="ouq", out_signature="")
    def DisplayPasskey(self, device, passkey, entered):
        print("DisplayPasskey: %s, %06u entered %u" % (device, passkey, entered))

    @dbus.service.method(AGENT_INTERFACE, in_signature="os", out_signature="")
    def DisplayPinCode(self, device, pincode):
        print("DisplayPinCode: %s, %s" % (device, pincode))

    @dbus.service.method(AGENT_INTERFACE, in_signature="ou", out_signature="")
    def RequestConfirmation(self, device, passkey):
        print("RequestConfirmation: %s, %06d" % (device, passkey))
        return

    @dbus.service.method(AGENT_INTERFACE, in_signature="o", out_signature="")
    def RequestAuthorization(self, device):
        print("RequestAuthorization: %s" % (device))
        return

    @dbus.service.method(AGENT_INTERFACE, in_signature="", out_signature="")
    def Cancel(self):
        print("Cancel")

if __name__ == '__main__':
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()
    agent = Agent(bus, AGENT_PATH)
    obj = bus.get_object(BUS_NAME, "/org/bluez")
    manager = dbus.Interface(obj, "org.bluez.AgentManager1")
    manager.RegisterAgent(AGENT_PATH, "NoInputNoOutput")
    print("Agent registered")
    manager.RequestDefaultAgent(AGENT_PATH)
    print("Default agent requested")
    mainloop = GLib.MainLoop()
    mainloop.run()

```

Make it executable:
```bash
sudo chmod +x /usr/local/bin/bt-agent.py
```

Create a service for the agent:
```bash
sudo nano /etc/systemd/system/bluetooth-agent.service
```
Add the following content:
```ini
[Unit]
Description=Bluetooth Agent
After=bluetooth.service
Before=bluetooth-setup.service
Requires=bluetooth.service

[Service]
Type=simple
ExecStart=/usr/local/bin/bt-agent.py
Restart=on-failure

[Install]
WantedBy=multi-user.target
```




**Autostart pulseaudio**
Enable the service
```sh
sudo nano /etc/systemd/system/pulseaudio.service
```

Enter the following content:
```ini
[Unit]
Description=PulseAudio Sound System
After=bluetooth.service bluetooth-setup.service
Requires=bluetooth.service
StartLimitIntervalSec=30
StartLimitBurst=5


[Service]
Type=forking
User=root
Environment=XDG_RUNTIME_DIR=/run/user/0
ExecStartPre=/bin/sh -c 'mkdir -p /var/run/pulse; chown -R pulse:pulse /var/run/pulse'
ExecStartPre=/bin/sh -c 'pkill pulseaudio || true'
ExecStartPre=/bin/sh -c 'rm -f /var/run/pulse/*.pid'
ExecStart=/usr/bin/pulseaudio --system --daemonize
ExecStop=/usr/bin/pulseaudio --kill
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
```

Configure PulseAudio for system-wide mode:
```sh
sudo nano /etc/pulse/system.pa
```
Replace the content with the following:
```
#!/usr/bin/pulseaudio -nF

# Load core protocols
load-module module-dbus-protocol
load-module module-native-protocol-unix auth-anonymous=1

# Load Bluetooth modules
load-module module-bluetooth-policy
load-module module-bluetooth-discover

# Load udev detection for audio devices
.ifexists module-udev-detect.so
load-module module-udev-detect
.endif

# Create a null sink as fallback
load-module module-null-sink sink_name=sink_null
load-module module-null-source source_name=source_null

# Automatically restore **volume**
load-module module-device-restore
load-module module-stream-restore
load-module module-card-restore

# Automatically switch to newly-connected devices
load-module module-switch-on-port-available

# Enable positioned event sounds
load-module module-position-event-sounds

# Allow resampling
load-module module-filter-heuristics
load-module module-filter-apply
```

Create proper permissions for the PulseAudio socket:
```sh
sudo nano /etc/pulse/daemon.conf
```
Add the following lines:
```ini
daemonize = yes
system-instance = yes
allow-module-loading = yes
allow-exit = no
exit-idle-time = -1
flat-volumes = no
high-priority = yes
nice-level = -11
realtime-scheduling = yes
realtime-priority = 5
resample-method = src-sinc-best-quality
avoid-resampling = no
enable-remixing = yes
remixing-use-all-sink-channels = yes
enable-lfe-remixing = yes
default-sample-format = s16le
default-sample-rate = 44100
alternate-sample-rate = 48000
default-sample-channels = 2
default-fragments = 8
default-fragment-size-msec = 10
deferred-volume-safety-margin-usec = 1000
log-level = notice
```
Add the pulse user to the relevant groups:
```sh
sudo usermod -a -G pulse-access sonicsphere
```


Create an audio.conf file:
```sh
sudo nano /etc/bluetooth/audio.conf
```
Add the following content:
```ini
[General]
Enable=Source,Sink,Media,Socket
```

Create a proper client configuration
```sh
sudo mkdir -p /etc/pulse
sudo nano /etc/pulse/client.conf
```
Add the following content:
```ini
autospawn = no
daemon-binary = /bin/true
default-server = /var/run/pulse/native
```

Increase the bluetooth buffer sizes to prevent audio glitches:
```sh
sudo nano /etc/bluetooth/main.conf
```
Add the following lines:
```ini
[General]
AudioFlushTimeout=10
```


Restart and enable all services:
```sh
sudo systemctl daemon-reload
sudo systemctl restart bluetooth
sudo systemctl restart bluetooth-agent.service
sudo systemctl restart bluetooth-setup.service

# Kill any leftover PulseAudio instances
sudo pkill pulseaudio
# Start the system service
sudo systemctl restart pulseaudio.service
```

Check that the services are running:
```sh
sudo systemctl status bluetooth
sudo systemctl status bluetooth-setup.service
sudo systemctl status bluetooth-agent.service
sudo systemctl status pulseaudio.service
```



Verify bluetooth status:
```sh
sudo hciconfig hci0 class
sudo hciconfig -a
```






### Test bluetooth streaming

**version 1**
Start pulseaudio
```sh
pulseaudio --start
```
Connect headphones to 3.5mm jack, connect to bluetooth, confirm that it is playing music.

**version 2**
Command line monitoring
```sh
# Install pavucontrol if not already installed
sudo apt install -y pavucontrol

# Monitor audio levels in terminal
pactl list sources short
pactl list sink-inputs

# Use pavumeter to visually see audio levels
sudo apt install -y pavumeter
pavumeter
```

**version 3**
use aplay to test audio
```sh
# List all audio devices
aplay -l

# Check audio levels
alsamixer
```
