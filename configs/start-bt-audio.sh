#!/bin/bash

# Log file for debugging
LOG_FILE="/var/log/bt-audio-startup.log"

# Function to log messages
log() {
    echo "$(date): $1" >> $LOG_FILE
}

log "Starting Bluetooth audio setup script"

# Wait for system to fully boot
sleep 15
log "System boot wait complete"

# Kill any existing PulseAudio instances
log "Killing any existing PulseAudio instances"
pkill -9 pulseaudio || true

# Create necessary directories
log "Creating PulseAudio directories"
mkdir -p /var/run/pulse
chmod -R 777 /var/run/pulse

# Create user pulse config directory if it doesn't exist
log "Setting up user pulse configuration"
sudo mkdir -p /home/sonicsphere/.config/pulse
sudo cp /usr/local/etc/default.pa /home/sonicsphere/.config/pulse/default.pa
sudo chown -R sonicsphere:sonicsphere /home/sonicsphere/.config/pulse

# Start PulseAudio with more conservative settings
log "Starting PulseAudio as user sonicsphere"
sudo -u sonicsphere pulseaudio --start --exit-idle-time=-1 --log-level=debug --log-target=file:/var/log/pulse.log

# Wait for PulseAudio to initialize
sleep 5
log "PulseAudio startup wait complete"

# Configure Bluetooth
log "Configuring Bluetooth"
/usr/bin/bluetoothctl -- power on
sleep 1
/usr/bin/bluetoothctl -- discoverable on
sleep 1
/usr/bin/bluetoothctl -- pairable on
sleep 1

# Configure Bluetooth to use NoInputNoOutput pairing
log "Setting up Bluetooth agent for PIN-less pairing"
/usr/bin/bluetoothctl -- agent NoInputNoOutput
sleep 1
/usr/bin/bluetoothctl -- default-agent
sleep 1

# Set the audio device class
log "Setting Bluetooth device class"
/sbin/hciconfig hci0 class 0x040414

log "Bluetooth audio setup complete"
exit 0