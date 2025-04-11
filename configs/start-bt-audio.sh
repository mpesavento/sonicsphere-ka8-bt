#!/bin/bash

# Log file for debugging
LOG_FILE="/var/log/bt-audio-startup.log"

# Function to log messages
log() {
    echo "$(date): $1" >> $LOG_FILE
}

log "Starting Bluetooth audio setup"

# Kill any existing PulseAudio instances
log "Killing any existing PulseAudio instances"
pkill -9 pulseaudio || true
sleep 2

# Make sure Bluetooth is stopped
log "Stopping Bluetooth service"
systemctl stop bluetooth
sleep 2

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

# Create proper default.pa
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

# Create sink for the analog audio output (3.5mm jack)
load-module module-alsa-sink sink_name=analog_output device=hw:0,0 sink_properties="device.description='Analog Output'"

# Route audio from rtp_sink to analog_output
load-module module-loopback source=rtp_sink.monitor sink=analog_output latency_msec=5

# Set default
set-default-sink rtp_sink
EOF
chown sonicsphere:sonicsphere /home/sonicsphere/.config/pulse/default.pa

# Start PulseAudio for the user
log "Starting PulseAudio"
sudo -u sonicsphere pulseaudio --start --exit-idle-time=-1 --log-level=debug --log-target=file:/home/sonicsphere/.config/pulse/pulse.log

# Wait for PulseAudio to initialize
sleep 3

# Verify PulseAudio is running
if pgrep -u sonicsphere pulseaudio > /dev/null; then
    log "PulseAudio started successfully"
else
    log "ERROR: PulseAudio failed to start"
    exit 1
fi

# Now check if the bluetooth modules are loaded
if sudo -u sonicsphere pactl list modules | grep -q bluetooth; then
    log "Bluetooth modules loaded successfully"
else
    log "ERROR: Bluetooth modules failed to load"
    # Try to load them manually
    sudo -u sonicsphere pactl load-module module-bluetooth-policy
    sudo -u sonicsphere pactl load-module module-bluetooth-discover
    sleep 2
fi

# Start Bluetooth and configure it
log "Starting and configuring Bluetooth"
sudo systemctl start bluetooth
sleep 2

# Configure Bluetooth settings
bluetoothctl -- power off
sleep 1
bluetoothctl -- system-alias SonicSphereKA8
sleep 1
bluetoothctl -- agent NoInputNoOutput
bluetoothctl -- default-agent
sleep 1

# Set device class to audio speaker
log "Setting device class"
hciconfig hci0 class 0x040414
hciconfig hci0 sspmode 1

# Turn on Bluetooth
bluetoothctl -- power on
sleep 1
bluetoothctl -- discoverable on
bluetoothctl -- pairable on

log "Bluetooth audio setup complete"
exit 0