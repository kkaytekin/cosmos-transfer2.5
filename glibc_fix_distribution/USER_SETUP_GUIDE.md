# GLIBC Fix Setup Guide for End Users

**For cosmos-transfer2.5 on HLRS HPC System**

This guide is for users who have received the pre-compiled GLIBC compatibility fix. You do NOT need to compile anything yourself.

---

## What You Received

You should have received these files:
- `libglibc_compat_wrapper.so` - Pre-compiled compatibility library (8.3K)
- `glibc_compat_wrapper.c` - Source code (for reference only)
- `glibc_229.map` - Version script (for reference only)
- `USER_SETUP_GUIDE.md` - This file

---

## Step 1: Set Up Micromamba Environment

You have two options:

### Option A: Use the Shared Environment (Recommended)

A pre-configured environment is available at:
```
/lustre/nec/ws3/ws/hpckkuec-cosmos/micromamba-env
```

You can use this directly - no installation needed. Skip to Step 2.

**Or** copy it to your workspace for better performance:
```bash
cp -r /lustre/nec/ws3/ws/hpckkuec-cosmos/micromamba-env /path/to/your/workspace/
```

### Option B: Create Your Own Environment

If you prefer to create your own environment:

**First, install micromamba** (if not already installed):
```bash
# Download micromamba
curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest | tar -xvj bin/micromamba

# Create directory and move binary
mkdir -p ~/.local/bin
mv bin/micromamba ~/.local/bin/
rmdir bin

# Initialize micromamba (adds to ~/.bashrc)
~/.local/bin/micromamba shell init -s bash -p ~/.local/share/mamba

# Reload shell configuration
source ~/.bashrc

# Verify installation
micromamba --version
```

**Then create the environment:**
```bash
micromamba create -n glibc-compat -y
micromamba activate glibc-compat
micromamba install -c conda-forge -y \
  libstdcxx-ng \
  libgcc-ng \
  cudnn \
  patchelf
```

This installs required libraries (~665 MB).

**What these packages provide:**
- `libstdcxx-ng` - Newer C++ standard library (GLIBCXX 3.4.26)
- `libgcc-ng` - GCC runtime library
- `cudnn` - CUDA Deep Neural Network library
- `patchelf` - Tool to modify ELF binaries (used in Step 3)

### Step 2: Copy the Wrapper Library

Copy `libglibc_compat_wrapper.so` to your cosmos-transfer2.5 directory:

```bash
cp libglibc_compat_wrapper.so /path/to/your/cosmos-transfer2.5/
cd /path/to/your/cosmos-transfer2.5/
```

### Step 3: Backup and Patch transformer_engine

There are **two** `.so` files that need patching:

```bash
# Set your paths
COSMOS_DIR=$(pwd)
TE_DIR=".venv/lib/python3.10/site-packages/transformer_engine"

# Set MAMBA_ENV based on which option you chose in Step 1:
# Option A (shared environment):
MAMBA_ENV="/lustre/nec/ws3/ws/hpckkuec-cosmos/micromamba-env"
# Option B (your own environment):
# MAMBA_ENV="$HOME/.local/share/mamba/envs/glibc-compat"

# Backup originals
cp ${TE_DIR}/libtransformer_engine.so ${TE_DIR}/libtransformer_engine.so.backup
cp ${TE_DIR}/transformer_engine_torch.cpython-310-x86_64-linux-gnu.so \
   ${TE_DIR}/transformer_engine_torch.cpython-310-x86_64-linux-gnu.so.backup

# Patch libtransformer_engine.so
${MAMBA_ENV}/bin/patchelf \
  --set-rpath "${COSMOS_DIR}:${MAMBA_ENV}/lib" \
  ${TE_DIR}/libtransformer_engine.so
${MAMBA_ENV}/bin/patchelf \
  --replace-needed libm.so.6 libglibc_compat_wrapper.so \
  ${TE_DIR}/libtransformer_engine.so

# Patch transformer_engine_torch.cpython-310-x86_64-linux-gnu.so
${MAMBA_ENV}/bin/patchelf \
  --set-rpath "${COSMOS_DIR}:${MAMBA_ENV}/lib" \
  ${TE_DIR}/transformer_engine_torch.cpython-310-x86_64-linux-gnu.so
${MAMBA_ENV}/bin/patchelf \
  --replace-needed libm.so.6 libglibc_compat_wrapper.so \
  ${TE_DIR}/transformer_engine_torch.cpython-310-x86_64-linux-gnu.so

echo "✅ Both .so files patched"
```

### Step 4: Create Activation Script

Create a file named `activate_cosmos.sh` in your cosmos-transfer2.5 directory:

```bash
cat > activate_cosmos.sh << 'EOF'
#!/bin/bash

# Check if script is being sourced (not executed)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "ERROR: This script must be sourced, not executed!"
    echo "Usage: source activate_cosmos.sh"
    exit 1
fi

# UPDATE THESE PATHS:
COSMOS_REPO_PATH=<update-with-the-absolute-path-to-your-cosmos-repo-directory>

# Set MAMBA_ENV based on which option you chose in Step 1:
# Option A (shared environment):
MAMBA_ENV="/lustre/nec/ws3/ws/hpckkuec-cosmos/micromamba-env"
# Option B (your own environment):
# MAMBA_ENV="$HOME/.local/share/mamba/envs/glibc-compat"

cd $COSMOS_REPO_PATH

# Load CUDA
module load system/cuda/12.8.1

# Activate Python environment
source .venv/bin/activate

# Set library path to use glibc-compat libraries
export LD_LIBRARY_PATH="${MAMBA_ENV}/lib:${LD_LIBRARY_PATH}"

# Set Hugging Face cache directory
export HF_HOME="$COSMOS_REPO_PATH/huggingface-models"
mkdir -p $HF_HOME

echo "✅ Cosmos environment activated"
echo "You can now run Python scripts with transformer_engine support."
EOF

chmod +x activate_cosmos.sh
```

**IMPORTANT**: You must use `source` to run this script:
```bash
source activate_cosmos.sh    # Correct ✅
./activate_cosmos.sh         # Wrong ❌ (runs in subshell, changes are lost)
```

**Important**: Edit `activate_cosmos.sh` and update:
1. `COSMOS_REPO_PATH` - Your cosmos-transfer2.5 directory path
2. `MAMBA_ENV` - Uncomment the correct option based on Step 1

### Step 5: Test It Works

```bash
source activate_cosmos.sh
python -c "import transformer_engine; print('✅ Success!')"
```

**Expected output**: `✅ Success!`

---

## Daily Usage

Every time you want to use cosmos-transfer2.5:

```bash
source /path/to/your/cosmos-transfer2.5/activate_cosmos.sh
python your_script.py
```

The activation script automatically changes to your cosmos directory.

---

## For PBS Job Submissions

Add these lines at the beginning of your job script:

```bash
#!/bin/bash
#PBS [your normal PBS directives]

# Activate cosmos environment (automatically changes to cosmos directory)
source /path/to/your/cosmos-transfer2.5/activate_cosmos.sh

# Your Python commands
python your_training_script.py
```

---

## Verification Commands

### Check if wrapper library is found:
```bash
ldd .venv/lib/python3.10/site-packages/transformer_engine/libtransformer_engine.so | grep libglibc_compat
```

**Should show**: Path to `libglibc_compat_wrapper.so`

### Check if conda libraries are available:
```bash
ls ~/.local/share/mamba/envs/glibc-compat/lib/libstdc++.so.6
```

**Should exist**: File found

### Test transformer_engine import:
```bash
module load system/cuda/12.8.1
source .venv/bin/activate
export LD_LIBRARY_PATH="$HOME/.local/share/mamba/envs/glibc-compat/lib:${LD_LIBRARY_PATH}"
python -c "import transformer_engine; print('✅ Works!')"
```

**Should output**: `✅ Works!`

---

## Troubleshooting

### ❌ Error: `GLIBC_2.29 not found`

**Problem**: Patching not applied correctly

**Solution**: Re-run Step 3 (Backup and Patch)

### ❌ Error: `libglibc_compat_wrapper.so: cannot open shared object file`

**Problem**: Wrapper library not in correct location

**Solution**:
1. Ensure `libglibc_compat_wrapper.so` is in your cosmos-transfer2.5 directory
2. Verify RPATH includes current directory:
   ```bash
   micromamba run -n glibc-compat patchelf --print-rpath \
     .venv/lib/python3.10/site-packages/transformer_engine/libtransformer_engine.so
   ```
   Should include your cosmos-transfer2.5 path

### ❌ Error: `GLIBCXX_3.4.26 not found`

**Problem**: Conda library path not set

**Solution**: Ensure LD_LIBRARY_PATH is set:
```bash
export LD_LIBRARY_PATH="$HOME/.local/share/mamba/envs/glibc-compat/lib:${LD_LIBRARY_PATH}"
```

### ❌ Error: `undefined symbol: nvrtcGetCUBINSize`

**Problem**: CUDA module not loaded

**Solution**: Load CUDA module:
```bash
module load system/cuda/12.8.1
```

---

## What This Fix Does

This fix resolves a compatibility issue where:
- transformer_engine (compiled on Ubuntu 22.04) requires GLIBC 2.29
- HLRS HPC system (RHEL 8.10) has GLIBC 2.28

The wrapper library (`libglibc_compat_wrapper.so`) provides the missing GLIBC 2.29 symbols by redirecting to the system's GLIBC 2.28 implementations (which are functionally identical).

No system modifications required - everything runs in user space.

---

## Files Location Summary

After setup, your cosmos-transfer2.5 directory should contain:
```
cosmos-transfer2.5/
├── libglibc_compat_wrapper.so     # Compatibility wrapper
├── activate_cosmos.sh              # Environment activation script
├── .venv/                          # Python virtual environment
│   └── lib/python3.10/site-packages/transformer_engine/
│       ├── libtransformer_engine.so        # Patched library
│       └── libtransformer_engine.so.backup # Original backup
└── [other cosmos files...]
```

Micromamba environment:
```
~/.local/share/mamba/envs/glibc-compat/
└── lib/
    ├── libstdc++.so.6   # GLIBCXX 3.4.26
    └── libcudnn*.so.9   # cuDNN 9.x libraries
```

---

## Need Help?

If you encounter issues not covered here, check the original technical documentation:
- `GLIBC_FIX_REPRODUCTION_GUIDE.md` - Full technical details
- `GLIBC_COMPATIBILITY_REPORT.md` - Problem analysis and solution

Or contact the person who provided you with this fix.
