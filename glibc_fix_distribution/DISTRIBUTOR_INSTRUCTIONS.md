# Instructions for Distributing the GLIBC Fix

**Quick guide for sharing this fix with other users on HLRS HPC**

---

## What You're Distributing

A pre-compiled compatibility library that fixes GLIBC 2.29 errors for cosmos-transfer2.5.

**Key file**: `libglibc_compat_wrapper.so` (8.3 KB)

---

## Distribution Methods

### Method 1: Share the Entire Directory

Users can copy everything directly from your workspace:

**Tell users to run:**
```bash
cp -r /lustre/nec/ws3/ws/hpckkuec-cosmos/cosmos-transfer2.5/glibc_fix_distribution ~/cosmos_glibc_fix
cd ~/cosmos_glibc_fix
cat USER_SETUP_GUIDE.md  # Read instructions
```

### Method 2: Make Files Group-Readable

If you have a shared group workspace:

```bash
# Make files readable by your group
chmod -R g+rX glibc_fix_distribution/

# Users can then access:
# /lustre/nec/ws3/ws/hpckkuec-cosmos/cosmos-transfer2.5/glibc_fix_distribution/
```

### Method 3: Email/Transfer the Files

Compress and send:

```bash
tar czf cosmos_glibc_fix.tar.gz glibc_fix_distribution/
```

**Files to send**:
- `cosmos_glibc_fix.tar.gz` (very small, ~3-4 KB)

Users extract with:
```bash
tar xzf cosmos_glibc_fix.tar.gz
cd glibc_fix_distribution/
```

---

## What to Tell Users

Send them this message:

---

**Subject: GLIBC Fix for cosmos-transfer2.5 on HLRS**

Hi,

I've prepared a fix for the GLIBC 2.29 compatibility issue you might encounter when using cosmos-transfer2.5 on the HLRS HPC system.

**Quick Setup** (~10 minutes):

1. Copy the fix package:
   ```bash
   cp -r /lustre/nec/ws3/ws/hpckkuec-cosmos/cosmos-transfer2.5/glibc_fix_distribution ~/cosmos_glibc_fix
   cd ~/cosmos_glibc_fix
   ```

2. Follow the instructions in `USER_SETUP_GUIDE.md`

3. Main steps are:
   - Create a micromamba environment with required libraries
   - Copy the pre-compiled .so file to your cosmos directory
   - Patch transformer_engine (2 patchelf commands)
   - Test that it works

The guide has copy-paste commands for everything.

**What this fixes**:
- Error: `OSError: GLIBC_2.29 not found`
- Allows transformer_engine to work on RHEL 8.10

Let me know if you have any issues!

---

## Supporting Users

### Common Questions

**Q: Do I need to compile anything?**
A: No, the .so file is pre-compiled and ready to use.

**Q: Will this work on my laptop/different cluster?**
A: Only if it's the same HLRS RHEL 8.10 system. Different systems need recompilation.

**Q: Is this safe?**
A: Yes, it only provides symbol compatibility. No system modifications needed.

**Q: Do I need sudo/admin rights?**
A: No, everything runs in user space.

### If Users Get Errors

Point them to the troubleshooting section in `USER_SETUP_GUIDE.md`.

Most common issues:
1. **GLIBC_2.29 not found** → Patchelf not applied correctly
2. **libglibc_compat_wrapper.so not found** → Wrong file location
3. **GLIBCXX_3.4.26 not found** → LD_LIBRARY_PATH not set
4. **nvrtc symbols missing** → CUDA module not loaded

---

## Verification Test

Tell users to verify with:

```bash
cd /path/to/their/cosmos-transfer2.5
module load system/cuda/12.8.1
source .venv/bin/activate
export LD_LIBRARY_PATH="$HOME/.local/share/mamba/envs/glibc-compat/lib:${LD_LIBRARY_PATH}"
python -c "import transformer_engine; print('✅ Success!')"
```

Should output: `✅ Success!`

---

## Package Contents

```
glibc_fix_distribution/
├── libglibc_compat_wrapper.so      # Main file (users need this)
├── USER_SETUP_GUIDE.md              # User instructions (give this to users)
├── README.md                         # Package overview
├── DISTRIBUTOR_INSTRUCTIONS.md      # This file
├── glibc_compat_wrapper.c           # Source code (reference)
└── glibc_229.map                    # Version script (reference)
```

**Minimum required**: `libglibc_compat_wrapper.so` + `USER_SETUP_GUIDE.md`

---

## Recompilation (If Needed)

If users are on a different system and need to recompile:

```bash
gcc -shared -fPIC -Wl,--version-script=glibc_229.map \
    -o libglibc_compat_wrapper.so glibc_compat_wrapper.c -lm
```

Requires: GCC compiler and the source files provided.

---

## Technical Documentation

For advanced users or troubleshooting, refer to:
- `../GLIBC_FIX_REPRODUCTION_GUIDE.md` - Complete technical guide
- `../GLIBC_COMPATIBILITY_REPORT.md` - Problem analysis
- `../MICROMAMBA_SETUP.md` - Environment details

---

## Updates

If transformer_engine gets updated or cosmos-transfer2.5 reinstalled:

Users need to **re-patch** transformer_engine (Step 3 in USER_SETUP_GUIDE.md).

The micromamba environment and .so file can be reused.

---

## License

Free to share and use for cosmos-transfer2.5 on HLRS infrastructure.
No warranty provided, but tested and working as of 2026-01-16.
