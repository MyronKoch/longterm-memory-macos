#!/bin/bash
# Wrapper script to ensure Python is found correctly by Chrome

# Log to file for debugging
exec 2>>/tmp/longterm_memory_chrome_host.log
echo "$(date): Starting native host" >&2
echo "Python path: /opt/homebrew/bin/python3" >&2
echo "Script path: $HOME/Documents/GitHub/longterm-memory-macos/browser-extension/native-host/longterm_memory_host.py" >&2

/opt/homebrew/bin/python3 $HOME/Documents/GitHub/longterm-memory-macos/browser-extension/native-host/longterm_memory_host.py "$@"

echo "$(date): Native host exited with code $?" >&2
