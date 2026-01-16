# GLIBC Compatibility Fix - Complete Reproduction Guide

This guide provides step-by-step instructions to fix GLIBC 2.29 compatibility issues for transformer_engine on systems with older GLIBC (e.g., RHEL 8.10 with GLIBC 2.28).

## Problem Summary

- **Issue**: `OSError: GLIBC_2.29 not found` when importing transformer_engine
- **Root Cause**: transformer_engine binaries require GLIBC 2.29 symbols (pow, log2, powf) but system has GLIBC 2.28
- **Solution**: Create a compatibility wrapper library that provides GLIBC 2.27/2.29 symbol versions

## Prerequisites

- Micromamba installed and configured
- GCC compiler
- Access to system CUDA modules (cuda/12.8.1)
- Write access to the cosmos-transfer2.5 directory

---

## Step 1: Create Micromamba Environment

```bash
# Create environment
micromamba create -n glibc-compat -y

# Activate environment
micromamba activate glibc-compat

# Install required libraries
micromamba install -c conda-forge -y \
  sysroot_linux-64=2.39 \
  libstdcxx-ng \
  libgcc-ng \
  cudnn \
  cmake \
  ninja \
  git \
  python=3.10 \
  pip \
  patchelf
```

**Expected output**: Should install ~36 packages including:
- sysroot_linux-64 2.39
- libstdcxx-ng 15.2.0
- cudnn 9.10.2.21
- patchelf 0.17.2

---

## Step 2: Create GLIBC Compatibility Wrapper

### 2.1 Create the C source file

Create `glibc_compat_wrapper.c`:

```c
/*
 * GLIBC Symbol Wrapper for pow, log2, and powf
 * Provides GLIBC_2.27 and GLIBC_2.29 versioned symbols
 */

#include <math.h>

/* Wrapper functions */
double __pow_wrapper(double x, double y) {
    return pow(x, y);
}

double __log2_wrapper(double x) {
    return log2(x);
}

float __powf_wrapper(float x, float y) {
    return powf(x, y);
}

/* Create aliases */
asm(".globl pow");
asm(".set pow, __pow_wrapper");
asm(".globl log2");
asm(".set log2, __log2_wrapper");
asm(".globl powf");
asm(".set powf, __powf_wrapper");
```

### 2.2 Create the version script

Create `glibc_229.map`:

```
GLIBC_2.27 {
    global:
        powf;
    local: *;
};

GLIBC_2.29 {
    global:
        pow;
        log2;
} GLIBC_2.27;
```

### 2.3 Compile the wrapper library

```bash
gcc -shared -fPIC -Wl,--version-script=glibc_229.map \
    -o libglibc_compat_wrapper.so glibc_compat_wrapper.c -lm
```

### 2.4 Verify the wrapper

```bash
objdump -T libglibc_compat_wrapper.so | grep -E "GLIBC_2.27|GLIBC_2.29"
```

**Expected output**:
```
GLIBC_2.27  powf
GLIBC_2.29  pow
GLIBC_2.29  log2
```

---

## Step 3: Patch transformer_engine Library

### 3.1 Backup the original library

```bash
cp .venv/lib/python3.10/site-packages/transformer_engine/libtransformer_engine.so \
   .venv/lib/python3.10/site-packages/transformer_engine/libtransformer_engine.so.backup
```

### 3.2 Set RPATH to include wrapper and conda libraries

```bash
source ~/.bashrc
micromamba activate glibc-compat

patchelf --set-rpath "/lustre/nec/ws3/ws/hpckkuec-cosmos/cosmos-transfer2.5:/zhome/academic/HLRS/hlrs/hpckkuec/.local/share/mamba/envs/glibc-compat/lib:\$ORIGIN" \
  .venv/lib/python3.10/site-packages/transformer_engine/libtransformer_engine.so
```

**Note**: Adjust paths based on your environment:
- First path: Directory containing `libglibc_compat_wrapper.so`
- Second path: micromamba `glibc-compat` environment lib directory

### 3.3 Replace libm.so.6 dependency with wrapper

```bash
patchelf --replace-needed libm.so.6 libglibc_compat_wrapper.so \
  .venv/lib/python3.10/site-packages/transformer_engine/libtransformer_engine.so
```

### 3.4 Verify patching

```bash
ldd .venv/lib/python3.10/site-packages/transformer_engine/libtransformer_engine.so | grep libglibc_compat
```

**Expected output**:
```
libglibc_compat_wrapper.so => /lustre/nec/ws3/ws/hpckkuec-cosmos/cosmos-transfer2.5/libglibc_compat_wrapper.so
```

---

## Step 4: Test the Fix

### 4.1 Load CUDA module

```bash
module load system/cuda/12.8.1
```

### 4.2 Activate Python environment

```bash
source .venv/bin/activate
```

### 4.3 Set library path

```bash
export LD_LIBRARY_PATH="/zhome/academic/HLRS/hlrs/hpckkuec/.local/share/mamba/envs/glibc-compat/lib:${LD_LIBRARY_PATH}"
```

**Note**: Adjust path to your micromamba `glibc-compat` environment

### 4.4 Test import

```bash
python -c "import transformer_engine; print('✅ transformer_engine imported successfully!')"
```

**Expected output**:
```
✅ transformer_engine imported successfully!
```

---

## Step 5: Create Activation Script (Optional)

For convenience, update `activate_glibc_compat.sh`:

```bash
#!/bin/bash
# Activate GLIBC compatibility environment

# Load CUDA module
module load system/cuda/12.8.1

# Activate Python virtual environment
source .venv/bin/activate

# Set library path for GLIBCXX and cudnn
export LD_LIBRARY_PATH="/zhome/academic/HLRS/hlrs/hpckkuec/.local/share/mamba/envs/glibc-compat/lib:${LD_LIBRARY_PATH}"

echo "✅ GLIBC compatibility environment activated"
echo ""
echo "Environment ready for cosmos-transfer2.5"
echo "You can now run Python scripts with transformer_engine support."
```

Usage:
```bash
source activate_glibc_compat.sh
python your_script.py
```

---

## Quick Copy-Paste Setup

For quick reproduction, run these commands in sequence:

```bash
# Step 1: Create micromamba environment
micromamba create -n glibc-compat -y
micromamba activate glibc-compat
micromamba install -c conda-forge -y sysroot_linux-64=2.39 libstdcxx-ng libgcc-ng cudnn cmake ninja git python=3.10 pip patchelf

# Step 2: Create wrapper source files
cat > glibc_compat_wrapper.c << 'EOF'
#include <math.h>
double __pow_wrapper(double x, double y) { return pow(x, y); }
double __log2_wrapper(double x) { return log2(x); }
float __powf_wrapper(float x, float y) { return powf(x, y); }
asm(".globl pow"); asm(".set pow, __pow_wrapper");
asm(".globl log2"); asm(".set log2, __log2_wrapper");
asm(".globl powf"); asm(".set powf, __powf_wrapper");
EOF

cat > glibc_229.map << 'EOF'
GLIBC_2.27 {
    global: powf;
    local: *;
};
GLIBC_2.29 {
    global: pow; log2;
} GLIBC_2.27;
EOF

# Step 3: Compile wrapper
gcc -shared -fPIC -Wl,--version-script=glibc_229.map -o libglibc_compat_wrapper.so glibc_compat_wrapper.c -lm

# Step 4: Backup and patch transformer_engine
cp .venv/lib/python3.10/site-packages/transformer_engine/libtransformer_engine.so \
   .venv/lib/python3.10/site-packages/transformer_engine/libtransformer_engine.so.backup

patchelf --set-rpath "$(pwd):/zhome/academic/HLRS/hlrs/hpckkuec/.local/share/mamba/envs/glibc-compat/lib:\$ORIGIN" \
  .venv/lib/python3.10/site-packages/transformer_engine/libtransformer_engine.so

patchelf --replace-needed libm.so.6 libglibc_compat_wrapper.so \
  .venv/lib/python3.10/site-packages/transformer_engine/libtransformer_engine.so

# Step 5: Test
module load system/cuda/12.8.1
source .venv/bin/activate
export LD_LIBRARY_PATH="/zhome/academic/HLRS/hlrs/hpckkuec/.local/share/mamba/envs/glibc-compat/lib:${LD_LIBRARY_PATH}"
python -c "import transformer_engine; print('✅ Success!')"
```

---

## Troubleshooting

### Issue: `GLIBC_2.29 not found` still appears

**Solution**: Verify patchelf was applied correctly:
```bash
ldd .venv/lib/python3.10/site-packages/transformer_engine/libtransformer_engine.so | grep libglibc_compat
```

If not found, re-run the patchelf commands.

### Issue: `undefined symbol: nvrtcGetCUBINSize`

**Solution**: Load CUDA module before running:
```bash
module load system/cuda/12.8.1
```

### Issue: `libstdc++.so.6: version GLIBCXX_3.4.26 not found`

**Solution**: Ensure LD_LIBRARY_PATH includes micromamba lib:
```bash
export LD_LIBRARY_PATH="/zhome/academic/HLRS/hlrs/hpckkuec/.local/share/mamba/envs/glibc-compat/lib:${LD_LIBRARY_PATH}"
```

---

## Files Created

1. `glibc_compat_wrapper.c` - Wrapper source code
2. `glibc_229.map` - Symbol version script
3. `libglibc_compat_wrapper.so` - Compiled wrapper library
4. `activate_glibc_compat.sh` - Environment activation script

## Verification Checklist

- [ ] Micromamba `glibc-compat` environment created
- [ ] libglibc_compat_wrapper.so compiled with GLIBC_2.27 and GLIBC_2.29 symbols
- [ ] libtransformer_engine.so backed up
- [ ] libtransformer_engine.so patched with patchelf
- [ ] CUDA module loaded
- [ ] LD_LIBRARY_PATH set correctly
- [ ] transformer_engine imports without errors

---

## Summary

This fix works by:
1. Creating a wrapper library that provides GLIBC 2.27/2.29 versioned symbols (pow, log2, powf)
2. These symbols redirect to the system's GLIBC 2.2.5 implementations (which are functionally identical)
3. Patching transformer_engine to use the wrapper instead of system libm
4. Providing newer libstdc++ (GLIBCXX 3.4.26) from conda
5. Loading CUDA runtime from system modules

The solution is non-invasive and doesn't require root access or system library modifications.
