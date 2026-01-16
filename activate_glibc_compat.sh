#!/bin/bash
# Activate GLIBC compatibility environment for cosmos-transfer2.5
# This script provides newer GLIBCXX (3.4.26) and CUDA libraries
# to resolve transformer_engine compatibility issues on RHEL 8.10

# Load CUDA module
module load system/cuda/12.8.1

# Activate Python virtual environment
source .venv/bin/activate

# Set environment path for conda libraries
ENV_PATH="/zhome/academic/HLRS/hlrs/hpckkuec/.local/share/mamba/envs/glibc-compat"

# Add conda libraries to LD_LIBRARY_PATH
# Provides: GLIBCXX 3.4.26 (libstdc++.so.6), libcudnn.so.9
export LD_LIBRARY_PATH="${ENV_PATH}/lib:${LD_LIBRARY_PATH}"

echo "✅ GLIBC compatibility environment activated"
echo ""
echo "Loaded modules:"
echo "  - CUDA 12.8.1"
echo ""
echo "Python environment:"
echo "  - Virtual environment: .venv"
echo ""
echo "Provided libraries:"
echo "  - GLIBCXX 3.4.26 (libstdc++.so.6)"
echo "  - libcudnn.so.9"
echo "  - GLIBC 2.27/2.29 symbols (via libglibc_compat_wrapper.so)"
echo ""
echo "You can now run Python scripts with transformer_engine support."
