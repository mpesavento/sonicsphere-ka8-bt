#!/bin/bash

# Create necessary directories
sudo mkdir -p /var/run/pulse/.config/pulse

# Create a cookie file for authentication
sudo touch /var/run/pulse/.config/pulse/cookie

# Set permissions
sudo chmod -R 777 /var/run/pulse
sudo chmod 777 /var/run/pulse/.config/pulse/cookie

# Create a symbolic link to system socket for the current user
mkdir -p ~/.config/pulse
ln -sf /var/run/pulse/native ~/.config/pulse/
ln -sf /var/run/pulse/.config/pulse/cookie ~/.config/pulse/

# Update environment variable for socket path
echo 'export PULSE_RUNTIME_PATH=/var/run/pulse' >> ~/.bashrc
echo 'export PULSE_COOKIE=/var/run/pulse/.config/pulse/cookie' >> ~/.bashrc

# Apply immediately for current session
export PULSE_RUNTIME_PATH=/var/run/pulse
export PULSE_COOKIE=/var/run/pulse/.config/pulse/cookie

echo "PulseAudio access has been configured for the current user."
echo "You may need to restart your shell session or run 'source ~/.bashrc'"