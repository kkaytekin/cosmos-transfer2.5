# GLIBC Compatibility Report for Cosmos Transfer 2.5

**Date**: 2026-01-15
**System**: RHEL/CentOS 8.10 (Linux 4.18.0-553.89.1.el8_10.x86_64)
**Issue**: OSError: GLIBC_2.29 not found

---

## System Status

### Current System Libraries

| Library | System Version | Required Version | Status |
|---------|---------------|------------------|--------|
| GLIBC (libm.so.6) | 2.28 | 2.29 | ❌ Missing |
| GLIBCXX (libstdc++.so.6) | 3.4.25 | 3.4.26 | ❌ Missing |
| libcudnn.so.9 | Not found | 9.x | ❌ Missing |

### System Library Locations

- `/lib64/libm.so.6` → `libm-2.28.so`
- `/lib64/libstdc++.so.6` → System version 3.4.25

---

## Problematic Library

### Primary Issue
**File**: `.venv/lib/python3.10/site-packages/transformer_engine/libtransformer_engine.so`

This is a pre-compiled binary wheel from:
```
https://nvidia-cosmos.github.io/cosmos-dependencies/v1.2.0/cu128_torch27/simple
```

### Specific GLIBC 2.29 Symbols Required

Only **2 functions** from GLIBC_2.29 are needed:
- `pow` (power function)
- `log2` (base-2 logarithm)

Both are from `libm.so.6` (math library).

### Complete Dependency Chain

```
libtransformer_engine.so requires:
├── libm.so.6 (GLIBC_2.29) ← MISSING pow, log2
├── libstdc++.so.6 (GLIBCXX_3.4.26) ← MISSING
├── libcudnn.so.9 ← NOT FOUND
├── libcublas.so.12 ✓
├── libcudart.so.12 ✓
├── libcublasLt.so.12 ✓
└── Other system libs (available)
```

---

## Affected Files

### Direct Impact
1. `.venv/lib/python3.10/site-packages/transformer_engine/libtransformer_engine.so`
   - **Action needed**: Replace or provide compatible libm.so.6 and libstdc++.so.6

### Indirect Impact (Imports fail due to above)
2. `.venv/lib/python3.10/site-packages/megatron/core/` (multiple files)
   - Tries to import transformer_engine
   - Crashes with OSError instead of graceful fallback

---

## Version Downgrade Investigation

### Available Versions
Checked NVIDIA cosmos-dependencies repository for all transformer_engine versions:

**For cu128.torch27 (our configuration):**
- transformer_engine 1.13.0
- transformer_engine 2.2
- transformer_engine 2.8.0

### Compatibility Testing

**transformer_engine 1.13.0** (tested):
```bash
# Downloaded and extracted wheel
# Checked GLIBC requirements:
objdump -T libtransformer_engine.so | grep GLIBC_2.29
# Result: GLIBC_2.29 needed for pow, log2

readelf -V libtransformer_engine.so | grep GLIBCXX
# Result: GLIBCXX_3.4.26 needed
```

**Verdict**: ❌ Same GLIBC 2.29 requirement as version 2.2

### Summary
All transformer_engine binaries for cu128.torch27 configuration require:
- GLIBC ≥ 2.29
- GLIBCXX ≥ 3.4.26

**Downgrading transformer_engine does NOT solve the compatibility issue.**

---

## Root Cause Analysis

### Why It Fails
1. NVIDIA compiled transformer-engine wheel on Ubuntu 22.04+ (GLIBC 2.35)
2. Binary is linked against GLIBC 2.29+ symbols
3. Your HPC system has GLIBC 2.28 (RHEL 8.10)
4. Cannot load shared library due to missing symbols

### Why Simple Downgrade Won't Work
**Tested versions for cu128.torch27:**
- ✗ transformer_engine 1.13.0: Requires GLIBC_2.29 (pow, log2) + GLIBCXX_3.4.26
- ✗ transformer_engine 2.2: Requires GLIBC_2.29 (pow, log2) + GLIBCXX_3.4.26
- ✗ transformer_engine 2.8.0: Not tested but likely same issue

**Conclusion:**
- All available transformer-engine builds for cu128.torch27 are compiled against GLIBC 2.29+
- All binaries were built on Ubuntu 22.04+ systems (GLIBC 2.35)
- PyPI wheels use manylinux_2_28 tags but binaries need 2.29+
- This is a **binary compatibility issue**, not a version issue
- **Downgrading transformer_engine version does NOT solve the problem**

---

## Solutions (Ranked by Feasibility)

### 1. Container-Based (RECOMMENDED)
Use Singularity/Apptainer container with bundled GLIBC 2.35+

**Check availability:**
```bash
module avail singularity
```

**If available:**
```bash
singularity build cosmos.sif docker://nvcr.io/nvidia/pytorch:25.10-py3
singularity exec --nv cosmos.sif [your command]
```

### 2. Provide Newer Libraries in User Space
Use conda/mamba to install newer libm and libstdc++ in user space, then use LD_LIBRARY_PATH or patchelf.

**Required libraries to source:**
- `libm.so.6` with GLIBC_2.29+ symbols
- `libstdc++.so.6` with GLIBCXX_3.4.26+
- `libcudnn.so.9`

**Approach:**
```bash
# Install miniconda/mamba
# Install libraries
conda install -c conda-forge libstdcxx-ng glibc

# Point to conda libraries
export LD_LIBRARY_PATH=$CONDA_PREFIX/lib:$LD_LIBRARY_PATH
```

### 3. Build from Source
Build transformer-engine from source on your system.

**Limitation**: Only works if source code doesn't use GLIBC 2.29-specific features (likely does).

### 4. Ask HPC Support
Request Singularity setup or updated GLIBC module from system administrators.

---

## Technical Details for Patchelf Approach

If you want to use patchelf to point to user-space libraries:

### Files to Patch
```bash
libtransformer_engine.so
```

### Required Commands
```bash
# Check current RPATH
patchelf --print-rpath .venv/lib/python3.10/site-packages/transformer_engine/libtransformer_engine.so

# Add user-space library path (if you have compatible libs)
patchelf --set-rpath "/path/to/newer/libs:$ORIGIN" \
  .venv/lib/python3.10/site-packages/transformer_engine/libtransformer_engine.so
```

### Libraries Needed
1. `libm.so.6` with GLIBC_2.29+
2. `libstdc++.so.6` with GLIBCXX_3.4.26+
3. `libcudnn.so.9`

**Warning**: Patchelf alone doesn't provide the libraries. You still need to source them from:
- Conda/Mamba environment
- Newer system (copy from Ubuntu 22.04+)
- Build from source

---

## Solution Implemented ✅

**Date**: 2026-01-16
**Status**: Successfully resolved

### Approach Used
Created a GLIBC compatibility wrapper library that provides GLIBC_2.27 and GLIBC_2.29 symbol versions.

### Key Components
1. **Wrapper Library** (`libglibc_compat_wrapper.so`)
   - Provides GLIBC_2.29 symbols: pow, log2
   - Provides GLIBC_2.27 symbols: powf
   - Redirects to system's GLIBC_2.2.5 implementations

2. **Micromamba Environment** (`glibc-compat`)
   - Provides GLIBCXX 3.4.26 (libstdc++.so.6)
   - Provides libcudnn.so.9

3. **Patchelf Modifications**
   - Modified libtransformer_engine.so RPATH
   - Replaced libm.so.6 dependency with wrapper library

### Files Created
- `glibc_compat_wrapper.c` - Wrapper source code
- `glibc_229.map` - Symbol version script
- `libglibc_compat_wrapper.so` - Compiled wrapper library
- `activate_glibc_compat.sh` - Environment activation script
- `GLIBC_FIX_REPRODUCTION_GUIDE.md` - Complete step-by-step guide

### Verification
```bash
source activate_glibc_compat.sh
python -c "import transformer_engine; print('✅ Success!')"
```

**Result**: ✅ transformer_engine imports successfully

See `GLIBC_FIX_REPRODUCTION_GUIDE.md` for complete reproduction instructions.

---

## Next Steps (Original - No Longer Needed)

1. **Check for Singularity**: `module avail singularity`
2. **If no Singularity**: Install miniconda and try conda-based solution
3. **If conda fails**: Contact HPC support for containerization help

---

## Verification Commands

```bash
# Check what GLIBC versions a binary needs
readelf -V /path/to/binary.so | grep "Version needs"

# Check what symbols from GLIBC_2.29 are used
objdump -T /path/to/binary.so | grep GLIBC_2.29

# Check system GLIBC version
ldd --version
strings /lib64/libm.so.6 | grep GLIBC_2

# Check library dependencies
ldd /path/to/binary.so
```

---

## Documentation References

- **Cosmos Setup Requirements**: `docs/setup.md:18` explicitly states `glibc>=2.35` required
- **Transformer Engine Version**: `2.2+cu128.torch27`
- **Megatron Core Version**: `0.14.0`
