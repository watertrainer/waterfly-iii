# APK Build Instructions

## Build Information

This document describes how to build the APK for the `add-transaction-bookmarking-again` branch.

### Branch Details
- **Feature Branch**: `add-transaction-bookmarking-again`
- **Build Date**: January 29, 2026
- **Build Type**: Debug APK
- **APK Size**: 171 MB
- **APK Location**: `build/app/outputs/flutter-apk/app-debug.apk`

### Build Process

The APK was successfully built using the following steps:

1. **Environment Setup**:
   - Flutter SDK (latest stable version)
   - Android SDK with Platform 31 and 33
   - CMake 3.22.1
   - Java 17

2. **Build Command**:
   ```bash
   flutter build apk --debug
   ```

3. **Build Fixes Applied**:
   - Modified `android/app/build.gradle.kts` to make keystore signing configuration conditional
   - This allows building without signing keys for debug builds

### Build Output

- **APK File**: `app-debug.apk`
- **SHA1 Checksum**: Available in `app-debug.apk.sha1`
- **Build Time**: ~10 minutes (including SDK downloads)

### Note on APK Distribution

Due to GitHub's 100MB file size limit and LFS upload restrictions on public forks, the APK binary cannot be directly committed to the repository. However, the APK has been successfully built and is available locally.

To reproduce this build:
1. Checkout the `add-transaction-bookmarking-again` branch
2. Run `flutter pub get` to install dependencies
3. Run `flutter build apk --debug` to build the APK
4. Find the APK at `build/app/outputs/flutter-apk/app-debug.apk`

### Build Configuration Changes

The following changes were made to support building without signing keys:

**File**: `android/app/build.gradle.kts`

Changed the signing configuration to be conditional:
- Only applies release signing if `key.properties` file exists
- Allows debug builds to proceed without signing configuration

This ensures the project can be built in CI/CD environments without requiring signing keys.
