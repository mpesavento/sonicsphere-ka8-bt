# SonicSphere KA8 Bluetooth Setup Guide

This guide provides step-by-step instructions for setting up a Raspberry Pi as a Bluetooth audio receiver that can stream to AES67.

## Prerequisites

- Raspberry Pi 3 or newer (with built-in Bluetooth)
- Fresh installation of Raspberry Pi OS (Bullseye or newer)
- Internet connectivity for package installation
- User account with sudo privileges (we'll use 'sonicsphere')

## 1. Initial System Setup

### Find your Rasberry Pi

```bash
ping raspberrypi.local
```
or
```bash
arp -a | grep "b8:27:eb"
```
to scan your network for the Raspberry Pi.

We keep getting the same IP address for our Raspberry Pi.:
```bash
10.72.2.49
```

Connect via SSH:
```bash
ssh sonicsphere@10.72.2.49
```
and use the obvious password.


### Update the System

```bash
# Update package lists and upgrade existing packages
sudo apt update && sudo apt upgrade -y
```

### Install Required Packages

```bash
# Install Bluetooth and PulseAudio packages
sudo apt install -y bluez bluez-tools bluez-hcidump pulseaudio pulseaudio-module-bluetooth

# Install Python D-Bus interface for Bluetooth agent
sudo apt install -y python3-dbus python3-gi

# Optional utilities for audio testing and debugging
sudo apt install -y pavucontrol pavumeter
```

## 2. Configure Bluetooth

### Set Up Bluetooth Device Properties

Create or modify the main Bluetooth configuration file:

```bash
sudo nano /etc/bluetooth/main.conf
```

Add or modify the following in the `[General]` section:

```ini
[General]
Name = SonicSphereKA8
Class = 0x040414
DiscoverableTimeout = 0
PairableTimeout = 0
JustWorksRepairing = always
FastConnectable = true
```

> Note: The Class value `0x040414` sets the device as an Audio/Video device (0x04) with Loudspeaker subclass (0x14).

### Create Audio Configuration for Bluetooth

```bash
sudo nano /etc/bluetooth/audio.conf
```

Add:

```ini
78=8
```

## 3. Configure PulseAudio

### Create User Configuration Directories

```bash
# Create directories for the user configuration
mkdir -p /home/sonicsphere/.config/pulse
touch /home/sonicsphere/.config/pulse/pulse.log
sudo chown -R sonicsphere:sonicsphere /home/sonicsphere/.config/pulse
```

### Create PulseAudio Configuration Files

Create the main configuration file:

```bash
sudo nano /home/sonicsphere/.config/pulse/default.pa
```

Add:
```
#!/usr/bin/pulseaudio -nF

# Load system defaults
.include /etc/pulse/default.pa

# Override modules for Bluetooth
load-module module-bluetooth-policy
load-module module-bluetooth-discover
load-module module-switch-on-connect

# Create a null sink for audio output
load-module module-null-sink sink_name=rtp_sink sink_properties="device.description='RTP Output'"

# Set default
set-default-sink rtp_sink

```

## 4. Configure Audio Output

### Configure PulseAudio for 3.5mm Jack Output

Modify the PulseAudio configuration to route audio to the 3.5mm jack:

```bash
sudo nano /home/sonicsphere/.config/pulse/default.pa
```

Add these lines after the "Create a null sink" section:

```ini
# Create sink for the analog audio output (3.5mm jack)
load-module module-alsa-sink sink_name=analog_output device=hw:0,0 sink_properties="device.description='Analog Output'"

# Route audio from rtp_sink to analog_output
load-module module-loopback source=rtp_sink.monitor sink=analog_output latency_msec=5

# Set default
set-default-sink rtp_sink
```

## 5. Create Bluetooth Auto-Connect Agent

Create a custom agent script that allows Bluetooth devices to pair without a PIN:

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

AGENT_INTERFACE = "org.bluez.Agent1"
AGENT_PATH = "/test/agent"

class Agent(dbus.service.Object):
    @dbus.service.method(AGENT_INTERFACE, in_signature="", out_signature="")
    def Release(self):
        print("Release")

    @dbus.service.method(AGENT_INTERFACE, in_signature="os", out_signature="")
    def AuthorizeService(self, device, uuid):
        print("AuthorizeService (%s, %s)" % (device, uuid))
        return

    @dbus.service.method(AGENT_INTERFACE, in_signature="o", out_signature="s")
    def RequestPinCode(self, device):
        print("RequestPinCode (%s)" % (device))
        return "0000"

    @dbus.service.method(AGENT_INTERFACE, in_signature="o", out_signature="u")
    def RequestPasskey(self, device):
        print("RequestPasskey (%s)" % (device))
        return 0

    @dbus.service.method(AGENT_INTERFACE, in_signature="ouq", out_signature="")
    def DisplayPasskey(self, device, passkey, entered):
        print("DisplayPasskey (%s, %06u entered %u)" % (device, passkey, entered))

    @dbus.service.method(AGENT_INTERFACE, in_signature="os", out_signature="")
    def DisplayPinCode(self, device, pincode):
        print("DisplayPinCode (%s, %s)" % (device, pincode))

    @dbus.service.method(AGENT_INTERFACE, in_signature="ou", out_signature="")
    def RequestConfirmation(self, device, passkey):
        print("RequestConfirmation (%s, %06d)" % (device, passkey))
        return

    @dbus.service.method(AGENT_INTERFACE, in_signature="o", out_signature="")
    def RequestAuthorization(self, device):
        print("RequestAuthorization (%s)" % (device))
        return

    @dbus.service.method(AGENT_INTERFACE, in_signature="", out_signature="")
    def Cancel(self):
        print("Cancel")

if __name__ == '__main__':
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()
    agent = Agent(bus, AGENT_PATH)
    obj = bus.get_object("org.bluez", "/org/bluez")
    manager = dbus.Interface(obj, "org.bluez.AgentManager1")
    manager.RegisterAgent(AGENT_PATH, "NoInputNoOutput")
    print("Agent registered")
    manager.RequestDefaultAgent(AGENT_PATH)
    print("Default agent requested")
    mainloop = GLib.MainLoop()
    mainloop.run()
```

Make the script executable:

```bash
sudo chmod +x /usr/local/bin/bt-agent.py
```

## 5.5 Coupy the start-bt-audio.sh script
```bash
# First, create the file on your Raspberry Pi
sudo nano /usr/local/bin/start-bt-audio.sh
```
Then paste the full contents of the script from `start-bt-audio.sh` into the file.

Make the script executable:

```bash
sudo chmod +x /usr/local/bin/start-bt-audio.sh
```
This script handles:
- Setting up Bluetooth in discoverable mode
- Creating the necessary PulseAudio configuration
- Starting PulseAudio properly in a headless environment
- Enabling Bluetooth to connect to PulseAudio

This script is referenced by the bt-audio.service that we'll create in the next step.



## 6. Create and Enable Systemd Service

Create a systemd service file to automatically start the Bluetooth audio service at boot:

```bash
sudo nano /etc/systemd/system/bt-audio.service
```

Add the following content:

```ini
[Unit]
Description=Bluetooth Audio Service
After=bluetooth.service network.target
Conflicts=pulseaudio.service pulseaudio.socket

[Service]
Type=simple
User=root
ExecStartPre=/usr/bin/pkill -9 pulseaudio || true
ExecStartPre=/bin/systemctl stop bluetooth
ExecStart=/bin/bash /home/sonicsphere/start-bt-audio.sh
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

Enable and start the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable bt-audio.service
sudo systemctl start bt-audio.service
```

You can check the status of the service with:

```bash
sudo systemctl status bt-audio.service
```

## 7. Auto-Start Bluetooth Agent

Create a systemd service for the Bluetooth agent:

```bash
sudo nano /etc/systemd/system/bt-agent.service
```

Add the following content:

```ini
[Unit]
Description=Bluetooth Agent Service
After=bluetooth.service
Wants=bluetooth.service

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /usr/local/bin/bt-agent.py
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

Enable and start the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable bt-agent.service
sudo systemctl start bt-agent.service
```

## 8. Testing the Setup

### Check Service Status

```bash
# Check if services are running
sudo systemctl status bt-audio.service
sudo systemctl status bt-agent.service
```

### Test Bluetooth Discovery

From another device (like your smartphone), open Bluetooth settings and scan for devices. You should see "SonicSphereKA8" in the list.

### Test Audio Playback

1. Pair your smartphone with SonicSphereKA8 (no PIN should be required)
2. Play audio on your smartphone
3. The audio should play through the Raspberry Pi's 3.5mm jack

### Checking Logs

If you encounter any issues, check the logs:

```bash
# check bluetooth logs
sudo journalctl -u bluetooth | tail -50


# Check Bluetooth service logs
sudo journalctl -u bluetooth.service

# Check custom service logs
sudo journalctl -u bt-audio.service
sudo journalctl -u bt-agent.service

# Check the custom log file
sudo cat /var/log/bt-audio-startup.log

# Check PulseAudio logs
cat /home/sonicsphere/.config/pulse/pulse.log
```

To check the process of bluetooth connection, you can enable bluetooth debug mode
```bash
sudo btmon
```


## 9. Future AES67 Configuration

For AES67 output (to be implemented):

1. Install additional packages:
   ```bash
   sudo apt install -y alsa-utils
   ```

2. Configure the PulseAudio RTP module for AES67 output (exact configuration depends on your AES67 implementation)