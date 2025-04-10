# Bluetooth to AES67 Streaming Configuration

This directory contains the configuration files needed to set up a Raspberry Pi 3 as a Bluetooth audio receiver that can stream to AES67.

## File Locations

| File | Target Location on Raspberry Pi |
|------|--------------------------------|
| system.pa         | /etc/pulse/system.pa |
| daemon.conf       | /etc/pulse/daemon.conf |
| client.conf       | /etc/pulse/client.conf |
| pulseaudio.service | /etc/systemd/system/pulseaudio.service |
| bluetooth-setup.service | /etc/systemd/system/bluetooth-setup.service |
| bluetooth-agent.service | /etc/systemd/system/bluetooth-agent.service |
| bt-agent.py       | /usr/local/bin/bt-agent.py |
| bt-manager.sh     | /usr/local/bin/bt-manager.sh |
| bluetooth_main.conf | Fragment for /etc/bluetooth/main.conf |
| audio.conf        | /etc/bluetooth/audio.conf |
| agent.conf        | /etc/bluetooth/agent.conf |
| bluetooth-pairing.conf | /etc/dbus-1/system.d/bluetooth-pairing.conf |
| pulse-access.sh   | Helper script to fix PulseAudio access issues |

## Installation Steps

1. Install required packages:
   ```sh
   sudo apt update
   sudo apt upgrade -y
   sudo apt install -y bluez bluez-tools pulseaudio pulseaudio-module-bluetooth python3-dbus python3-gi
   ```

2. Copy configuration files to their respective locations.

3. Make scripts executable:
   ```sh
   sudo chmod +x /usr/local/bin/bt-agent.py
   sudo chmod +x /usr/local/bin/bt-manager.sh
   ```

4. Reload systemd and enable services:
   ```sh
   sudo systemctl daemon-reload
   sudo systemctl enable bluetooth
   sudo systemctl enable bluetooth-agent.service
   sudo systemctl enable bluetooth-setup.service
   sudo systemctl enable pulseaudio.service
   ```

5. Start services:
   ```sh
   sudo systemctl restart bluetooth
   sudo systemctl restart bluetooth-agent.service
   sudo systemctl restart bluetooth-setup.service
   sudo pkill pulseaudio
   sudo systemctl restart pulseaudio.service
   ```

6. Verify status:
   ```sh
   sudo systemctl status bluetooth
   sudo systemctl status bluetooth-agent.service
   sudo systemctl status bluetooth-setup.service
   sudo systemctl status pulseaudio.service
   ```

## Bluetooth Device Configuration

The device will appear as "SonicSphereKA8" and will be configured as a Loudspeaker audio device.

## Testing

You can monitor audio streaming with:
```sh
pactl list sources short
pactl list sink-inputs
```

## Troubleshooting

### "Connection refused" with pactl commands

If you get "Connection refused" errors when running pactl commands, it's because your user doesn't have permission to access the PulseAudio system socket. To fix this:

1. Run the included pulse-access.sh script:
   ```sh
   chmod +x pulse-access.sh
   ./pulse-access.sh
   ```

2. Or manually set up access:
   ```sh
   # Set environment variables for the current session
   export PULSE_RUNTIME_PATH=/var/run/pulse
   export PULSE_COOKIE=/var/run/pulse/.config/pulse/cookie

   # Create symbolic links
   mkdir -p ~/.config/pulse
   ln -sf /var/run/pulse/native ~/.config/pulse/
   ln -sf /var/run/pulse/.config/pulse/cookie ~/.config/pulse/
   ```

3. You can also run commands with sudo:
   ```sh
   sudo -E pactl list sources short
   ```

### Other Issues

If services fail to start properly, check logs:
```sh
sudo journalctl -u bluetooth-setup.service
sudo journalctl -u bluetooth-agent.service
sudo journalctl -u pulseaudio.service
```