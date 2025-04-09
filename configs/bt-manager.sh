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