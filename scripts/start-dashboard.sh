#!/bin/bash
# Start the Longterm Memory Dashboard
# This script is called by the LaunchAgent

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT/dashboard"
exec /usr/bin/python3 app.py
