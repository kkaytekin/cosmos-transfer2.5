# GLIBC Compatibility Fix Distribution Package

**For cosmos-transfer2.5 on HLRS HPC System (RHEL 8.10)**

---

## Package Contents

This package contains everything needed to fix the GLIBC 2.29 compatibility issue for transformer_engine.

### Files Included

1. **libglibc_compat_wrapper.so** (8.3 KB)
   - Pre-compiled compatibility wrapper library
   - Provides GLIBC_2.27 (powf) and GLIBC_2.29 (pow, log2) symbols
   - **This is the main file users need**

2. **USER_SETUP_GUIDE.md**
   - Step-by-step setup instructions for end users
   - Assumes pre-compiled .so file is provided
   - **Give this to your users**

3. **glibc_compat_wrapper.c** (source code)
   - Source code for the wrapper library
   - For reference and audit purposes only
   - Users do NOT need to compile this

4. **glibc_229.map** (version script)
   - Symbol versioning script used during compilation
   - For reference only

5. **README.md** (this file)
   - Package overview

---

## How to Distribute

### Option 1: Direct File Sharing

Share this entire `glibc_fix_distribution/` directory with users:

```bash
# Users can copy from your workspace:
cp -r /lustre/nec/ws3/ws/hpckkuec-cosmos/cosmos-transfer2.5/glibc_fix_distribution ~/
```

### Option 2: Minimal Distribution

Users only need 2 files:
- `libglibc_compat_wrapper.so` (required)
- `USER_SETUP_GUIDE.md` (instructions)

```bash
# Minimal copy
cp glibc_fix_distribution/libglibc_compat_wrapper.so ~/
cp glibc_fix_distribution/USER_SETUP_GUIDE.md ~/
```

---

## User Instructions Summary

Tell your users to:

1. **Copy the .so file** to their cosmos-transfer2.5 directory
2. **Create micromamba environment** with required libraries
3. **Patch transformer_engine** using patchelf (instructions in USER_SETUP_GUIDE.md)
4. **Create activation script** for daily use
5. **Test** that transformer_engine imports successfully

Estimated setup time: **10-15 minutes**

Full instructions are in `USER_SETUP_GUIDE.md`.

---

## System Requirements

Users must be on the **same HPC system** (HLRS RHEL 8.10) for the pre-compiled .so file to work.

The .so file is compiled for:
- Architecture: x86_64
- System: Linux RHEL 8.10
- GLIBC: 2.28 (system version)

If users are on a different system, they need to recompile using the source files provided.

---

## What This Fixes

**Problem**:
```
OSError: /lib64/libm.so.6: version `GLIBC_2.29' not found
(required by .../transformer_engine/libtransformer_engine.so)
```

**Solution**:
Provides missing GLIBC 2.29 symbols without requiring system GLIBC upgrade.

**Technical Details**:
- transformer_engine binaries require GLIBC 2.29
- HPC system has GLIBC 2.28
- Wrapper library provides 2.29 symbols → redirects to 2.28 implementations
- Functions are identical, only symbol versions differ

---

## Verification

After users complete setup, they should be able to:

```bash
source activate_cosmos.sh
python -c "import transformer_engine; print('✅ Success!')"
```

If this works, the fix is installed correctly.

---

## Support Files

Full technical documentation is available in the parent directory:
- `GLIBC_FIX_REPRODUCTION_GUIDE.md` - Complete compilation and setup guide
- `GLIBC_COMPATIBILITY_REPORT.md` - Technical analysis and solution details
- `MICROMAMBA_SETUP.md` - Micromamba environment details

---

## License & Attribution

This fix was developed for cosmos-transfer2.5 on HLRS HPC infrastructure.

**Components**:
- libglibc_compat_wrapper.so - Custom wrapper (MIT-style, free to use)
- Micromamba packages - conda-forge (BSD/MIT licenses)
- patchelf - GNU GPL v3

**Date Created**: 2026-01-16
