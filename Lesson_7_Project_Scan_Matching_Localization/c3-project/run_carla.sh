#!/bin/bash

CARLA_DIR="$(cd "$(dirname "$0")/../CARLA" && pwd)"

# Force NVIDIA RTX 5070 via PRIME render offload
# UCX_TLS=tcp: prevents SIGSEGV in UCX shared-memory transport on Ubuntu 25.10+
__NV_PRIME_RENDER_OFFLOAD=1 \
__GLX_VENDOR_LIBRARY_NAME=nvidia \
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json \
UCX_TLS=tcp \
UCX_POSIX_USE_PROC_LINK=n \
"$CARLA_DIR/CarlaUE4.sh" -vulkan -quality-level=Low -nosound
