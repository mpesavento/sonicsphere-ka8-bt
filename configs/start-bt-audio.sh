#!/bin/bash

# Log file for debugging
LOG_FILE="/var/log/bt-audio-startup.log"

# Function to log messages
log() {
    echo "$(date): $1" >> $LOG_FILE
}

log "Starting Bluetooth audio setup"

# Make sure Bluetooth is running
log "Ensuring Bluetooth service is running"
sudo systemctl restart bluetooth
sleep 2

# Kill any existing PulseAudio instances
log "Killing any existing PulseAudio instances"
pkill -9 pulseaudio || true
sleep 2

# Check Bluetooth status
log "Checking Bluetooth status"
hciconfig -a >> $LOG_FILE

# Configure Bluetooth settings
log "Setting up Bluetooth"
bluetoothctl -- power on
sleep 1
bluetoothctl -- discoverable on
sleep 1
bluetoothctl -- pairable on
sleep 1

# Set Simple Secure Pairing mode
log "Setting SSP mode"
hciconfig hci0 sspmode 1

# Configure Bluetooth to use NoInputNoOutput pairing
log "Setting up Bluetooth agent for PIN-less pairing"
bluetoothctl -- agent NoInputNoOutput
sleep 1
bluetoothctl -- default-agent
sleep 1

# Set device class to audio speaker
log "Setting device class"
hciconfig hci0 class 0x040414

# Set up user directories and permissions
log "Setting up user directories"
mkdir -p /home/sonicsphere/.config/pulse
touch /home/sonicsphere/.config/pulse/pulse.log
chown -R sonicsphere:sonicsphere /home/sonicsphere/.config/pulse

# Create proper client.conf
log "Creating PulseAudio client configuration"
cat > /home/sonicsphere/.config/pulse/client.conf << EOF
autospawn = yes
daemon-binary = /usr/bin/pulseaudio
EOF
chown sonicsphere:sonicsphere /home/sonicsphere/.config/pulse/client.conf

# Create proper default.pa if it doesn't exist
log "Creating PulseAudio configuration"
cat > /home/sonicsphere/.config/pulse/default.pa << EOF
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
EOF
chown sonicsphere:sonicsphere /home/sonicsphere/.config/pulse/default.pa

# Start dbus-daemon if not running
log "Starting D-Bus daemon if needed"
if ! pgrep dbus-daemon > /dev/null; then
    sudo -u sonicsphere dbus-daemon --session --address=unix:path=/home/sonicsphere/.dbus/session_bus_socket --fork
    export DBUS_SESSION_BUS_ADDRESS=unix:path=/home/sonicsphere/.dbus/session_bus_socket
fi

# Start PulseAudio for the user
log "Starting PulseAudio"
sudo -u sonicsphere DBUS_SESSION_BUS_ADDRESS=unix:path=/home/sonicsphere/.dbus/session_bus_socket pulseaudio --start --exit-idle-time=-1 --log-level=debug --log-target=file:/home/sonicsphere/.config/pulse/pulse.log

# Wait for PulseAudio to initialize
sleep 3

# Verify PulseAudio is running
if pgrep -u sonicsphere pulseaudio > /dev/null; then
    log "PulseAudio started successfully"
else
    log "ERROR: PulseAudio failed to start"
fi

# Restart Bluetooth to ensure proper connection with PulseAudio
log "Restarting Bluetooth"
sudo systemctl restart bluetooth
sleep 2

# Final Bluetooth configuration
log "Final Bluetooth configuration"
bluetoothctl -- power on
bluetoothctl -- discoverable on
bluetoothctl -- pairable on

log "Bluetooth audio setup complete"
exit 0