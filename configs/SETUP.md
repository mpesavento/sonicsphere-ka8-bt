# SonicSphere KA8 Bluetooth Setup Guide

This guide provides step-by-step instructions for setting up a Raspberry Pi as a Bluetooth audio receiver that can stream to AES67.

## Prerequisites

- Raspberry Pi 3 or newer (with built-in Bluetooth)
- Fresh installation of Raspberry Pi OS (Bullseye or newer)
- Internet connectivity for package installation
- User account with sudo privileges (we'll use 'sonicsphere')

## 1. Initial System Setup

### Update the System

```bash
# Update package lists and upgrade existing packages
sudo apt update
sudo apt upgrade -y
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
[General]
Enable=Source,Sink,Media,Socket
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
