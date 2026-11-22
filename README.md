# HyperOS-to-A155F bring-up workspace

This repository provides a **source-driven, guarded bring-up scaffold** for investigating a HyperOS system donor against the Galaxy A15 4G stock vendor stack. It does not contain firmware images or assert a bootable port. No device-specific partition sizes, donor build identifiers, stock firmware revision, VINTF reports, or SELinux policy sources were supplied, so producing a safe flashable image is not possible yet. Never flash a guessed image: a cross-OEM system can fail at early init, destroy modem/calibration data, or leave the phone unbootable.

## 1. Build & partition architecture

Workspace directories are `base_a155f/`, `donor_emerald/`, `work/`, `patches/`, and `out/` (created by `scripts/workspace.sh`). Put **user-acquired, exact-model** firmware archives under `inputs/base/` and `inputs/donor/`; the toolchain extracts into the workspace. Keep proprietary firmware out of Git.

| Logical content | Source/intent | Format and sizing |
|---|---|---|
| `system`, `product`, `system_ext` | Donor HyperOS, after compatibility work | Preserve each source's filesystem initially; determine with `file`, `blkid`, `dump.erofs`/`debugfs`. |
| `mi_ext` | Donor | Do not create a new logical partition by default. Merge only after inspecting paths, labels, ownership, overlays, and references; proposed staging path is `work/mi_ext_merge/`. Do not blindly overlay or discard collisions. |
| `vendor`, `odm` | Exact SM-A155F stock | Keep byte-for-byte for initial experiments; Samsung MTK vendor HALs, modem support, calibration and device-specific configs are not donor replacements. |
| `boot`, `vendor_boot`, `dtbo`, `vbmeta` | Exact SM-A155F stock | Keep original backups. No automatic FBE, AVB, kernel cmdline, or ramdisk mutation is performed. |
| `super` | Target stock metadata and capacity | Read actual device and firmware metadata; no exact physical byte budget can be inferred from the model name. `lpdump` and `lpmake` metadata must agree with the target's group, slot, alignment, and partition limits. |

Do not assume `system_ext` or `mi_ext` is present as a target logical partition, that target uses a particular slot scheme, or that the donor's filesystem can be rebuilt with the available host tools. Determine actual image sizes and target `super` size from matching firmware and device dumps before designing a layout. The sum of logical allocations plus metadata/alignment must fit the physical super image and group maximum.

## 2. Automated unpack, patch & repack pipeline

### Host prerequisites

Linux host, Python 3, `unzip`, `7z` (or `bsdtar`), `file`, Android `lpunpack`/`lpdump`/`lpmake`, and (as applicable) `payload-dumper-go`, `simg2img`, `avbtool`, `magiskboot`, `debugfs`, `dump.erofs`, `mkfs.erofs`, `mke2fs`. Install tools from trusted distro/AOSP sources and record versions. `scripts/check-tools.sh` checks the basic commands.

1. Run `scripts/workspace.sh`; place the matching Samsung AP/CSC archive and exact emerald OTA/fastboot archive in `inputs/`.
2. Run `scripts/extract.sh base|donor ARCHIVE`. It extracts archive members into a dedicated staging folder and unpacks a `super.img` when `lpunpack` is available. For payload-based OTA, first run a trusted payload dumper yourself; the script reports this explicitly rather than guessing OTA semantics.
3. Inspect every image, metadata dump, build fingerprint, mount flags, VINTF and policy before changing anything. Save reports in `work/reports/` and preserve immutable originals.
4. Apply only audited text overlays from `patches/overlays/` to a **copy**. `scripts/patch_props.py` changes explicitly listed keys in a selected prop file and makes a `.bak`; it does not invent values or alter framework jars, SELinux policy, fstab, boot images, or AVB metadata.
5. Rebuild filesystem images only after confirming source type, contexts, fs_config, block size and size budget. `scripts/assemble-super.sh` intentionally refuses to generate super without a reviewed, target-specific lpmake argument file and all required images. This scaffold cannot validate bootability or create a flash archive.

Example:

```sh
scripts/workspace.sh
scripts/check-tools.sh
scripts/extract.sh base inputs/base/AP_A155F.tar.md5
scripts/extract.sh donor inputs/donor/emerald.zip
python3 scripts/patch_props.py --file work/staging/system/build.prop \
  --set ro.sf.lcd_density=420
```

The density example is illustrative, not a confirmed A155F value. Use values observed from the exact target build. `--set` is repeatable; see `--help`.

### Safe patch policy

No blanket signature-verification bypass, Xiaomi device-check bypass, forced permissive SELinux, disabling FBE, or disabling AVB is provided. These weaken device security and can break compatibility; any engineering-only test requires a separately reviewed, recoverable device-specific patch and explicit consent. Do not repack/flash stock boot components based on generic instructions. VINTF must be validated using actual target and donor manifests/matrices and `checkvintf`; SELinux requires compiling and analyzing the actual combined policy, not editing guessed allow rules. Framework JAR changes require source/build-aware patches and regression tests; this repo makes none.

## 3. Cross-OEM subsystem patch manifest

Treat the following as investigation targets, not already solved patches. Keep Samsung vendor/HAL/configuration and compare each service contract against the donor framework before proceeding.

| Area | Inspect and adapt (only with captured target data) |
|---|---|
| Display/brightness/90 Hz | Target panel mode, SurfaceFlinger composer/HWC, display config, brightness sysfs permissions and overlay-supported modes. Confirm actual sysfs path; `/sys/class/backlight/panel/brightness` is unverified. |
| Fingerprint | Samsung fingerprint HAL service instance, framework interface version, keyguard integration and enrollment/authentication logs. Do not substitute a Xiaomi HAL. |
| RIL/SIM/IMS | Keep target modem/RIL and carrier configuration; verify dual-SIM, data, voice, IMS and emergency calls. Avoid donor telephony overlays until proven compatible. |
| Audio | Preserve target audio HAL, policy, mixer paths and calibration; test routes, microphones, call audio and volume curves. |
| Camera | Preserve target camera provider, sensor configuration and blobs; validate camera IDs, preview, video, flash and permissions. |
| NFC/sensors/Wi-Fi/BT/GPS | Retain target firmware/configs and check service instances, permissions, regulatory settings and suspend behavior. |
| Framework/VINTF/SELinux | Compare interface versions, VNDK/APEX dependencies and vendor/system policy compatibility. Generate `checkvintf` and policy compiler reports from the exact artifacts. No generic JAR edits are safe. |

Record every proposed change, source revision, before/after hash, test, and rollback path under `patches/` before creating a candidate build.

## 4. Flashing & first-boot bring-up guide

**No flashable output is produced by this repository. Do not flash until the exact target, partition map, image sizes, AVB state, recovery path, and complete stock rollback package have been verified.** Initial testing should use a recoverable engineering device, not a daily-driver. Preserve EFS/NV/calibration data; never erase or overwrite those partitions.

After a separately reviewed build is available, validate hashes and partition mapping, ensure Odin stock firmware is locally available, and use only a device-specific installation procedure vetted by an A155F maintainer. Do not use `fastboot flash` assumptions on Samsung download-mode devices. Confirm the model and bootloader revision; Samsung rollback protection may prevent downgrading.

Capture immediately after boot (host has Android platform-tools):

```sh
adb wait-for-device
adb logcat -b all -d > first-boot-logcat.txt
adb shell dmesg > first-boot-dmesg.txt   # may be denied on production builds
adb shell getprop > first-boot-getprop.txt
adb shell cat /proc/last_kmsg > last-kmsg.txt 2>&1 || true
adb pull /sys/fs/pstore/ ./pstore/       # if available
```

If ADB never appears, use recovery/download-mode logs and pstore where accessible; do not repeatedly force reboot. Test matrix: boot/decryption; display/touch/brightness/refresh; Wi-Fi; Bluetooth; SIM 1/2, data, calls and IMS; earpiece/speaker/mic/headset; camera/photo/video/flash; fingerprint; sensors/GPS; USB/MTP/ADB; suspend, charging, thermal behavior and reboot. Mark each pass/fail with logs and build hashes.

### Stock rollback

Use a complete, matching SM-A155F stock package (BL/AP/CP/CSC) for the device's current or permitted bootloader revision. Verify package checksums and model before entering Download Mode. Restore with Samsung Odin using the correct slots and a known-good cable/host; CSC choice can wipe data. Never load a port `super`/`vbmeta` into stock rollback. Follow Samsung's on-device prompts and verify stock boot, baseband, IMEI, and hardware. If Download Mode is unavailable, stop and seek qualified device-specific recovery support; do not improvise partition writes.

## Repository scripts

- `scripts/workspace.sh`: create the directory layout.
- `scripts/check-tools.sh`: basic host-tool check.
- `scripts/extract.sh`: archive inventory and best-effort image extraction; originals stay in input paths.
- `scripts/patch_props.py`: explicit, backup-preserving property edits.
- `scripts/assemble-super.sh`: guarded lpmake wrapper, requires a reviewed argument file and explicit confirmation.

This is a scaffold for collecting and processing real artifacts. Exact partition architecture and runnable repacking arguments require the supplied matching firmware and `lpdump`/filesystem measurements; the repository deliberately does not fabricate them.
