#!/bin/bash
# Run cloud_loc localization client.
# Requires CARLA to be running (./run_carla.sh in another terminal).
#
# Controls (in the 3D Viewer window):
#   Up arrow    — accelerate
#   Down arrow  — brake / reverse
#   Left arrow  — steer left
#   Right arrow — steer right
#   a           — re-center camera view
#
# The simulation ends when you drive >=170m.
# "Passed!" = max pose error stayed <1.2m (green text).
# "Try Again" = max pose error exceeded 1.2m (red text).

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# UCX_TLS=tcp: prevents SIGSEGV in UCX shared-memory transport on Ubuntu 25.10+
UCX_TLS=tcp \
UCX_POSIX_USE_PROC_LINK=n \
"$SCRIPT_DIR/cloud_loc"
