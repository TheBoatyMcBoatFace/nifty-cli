#!/bin/bash
# set -euo pipefail

show_help() {
  cat <<EOF
Usage: $(basename "$0") [elgato|streamdeck|camerahub|wavelink|--help]

Restart Elgato applications:
  elgato       Restart all Elgato apps: Stream Deck, Camera Hub, and Wave Link
  streamdeck   Restart only Elgato Stream Deck
  camerahub    Restart only Camera Hub
  wavelink     Restart only Wave Link
  --help       Show this help message
EOF
}

restart_app() {
  local name="$1"
  echo "Stopping $name..."
  pkill -f "$name" || true
  sleep 2
  echo "Starting $name..."
  open -a "$name"
  echo "$name restarted."
}

case "${1:-}" in
  --help|-h)
    show_help
    ;;
  elgato)
    restart_app "Stream Deck"
    restart_app "Camera Hub"
    restart_app "Wave Link"
    ;;
  streamdeck)
    restart_app "Stream Deck"
    ;;
  camerahub)
    restart_app "Camera Hub"
    ;;
  wavelink)
    restart_app "Wave Link"
    ;;
  *)
    echo "Unknown option: ${1:-}" >&2
    show_help
    exit 1
    ;;
esac
