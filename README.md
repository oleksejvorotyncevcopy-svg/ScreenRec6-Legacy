
# ScreenRec6 

A lightweight, high-performance screen recording tweak designed specifically for **iOS 6** (optimized for 6.1.3). 

ScreenRec6 is built to run smoothly on legacy A5 devices (iPhone 4S, iPad 2/3, iPod Touch 5) with limited RAM (512MB - 1GB) by utilizing hardware-accelerated memory pools and native SpringBoard injection. It seamlessly integrates into **SBSettings** for quick access.

## Features

* **SBSettings Native Integration:** Control recording directly from the classic SBSettings drop-down window.
* **Universal Resolution Support:** Dynamically calculates device bounds and retina scale (resolutions are automatically `mod 16` aligned to prevent H.264 codec crashes).
* **High-Performance Memory Management:** Bypasses heavy memory allocation (churn) by utilizing `CVPixelBufferPool` to reuse video memory buffers during capture.
* **Optional Audio Recording:** Prompts the user before recording. Captures microphone audio with precise A/V Host Time synchronization, preventing audio/video drift.
* **Smart Audio Routing:** Automatically enables `AVAudioSessionCategoryOptionMixWithOthers` during recording so system audio/music isn't interrupted, and cleanly restores the audio session upon stopping.
* **Dynamic File Naming:** Saves videos directly to `/var/mobile/Documents/` with timestamped filenames (e.g., `ScreenRecord_YYYY-MM-DD_HH-mm-ss.mp4`).

## Architecture

The project is structured as an Aggregate Theos project containing two main components:
1. **Core Tweak (`Tweak.xm`):** Injects directly into `SpringBoard`. Handles the `AVAssetWriter` lifecycle, frame capturing via `UIGetScreenImage()`, and audio processing via `AVCaptureSession`.
2. **SBSettings Toggle (`Toggle.dylib`):** A dynamic library loaded by SBSettings that communicates with the Core Tweak via `NSNotificationCenter` (`com.vorotyntsev.screenrec6.toggle`).

## Requirements

**For Users:**
* A Jailbroken iOS 6.x device.
* **SBSettings** installed from Cydia.
* **iFile** or similar file manager to view the saved `.mp4` files.

**For Developers:**
* macOS environment (Monterey+ supported).
* [Theos](https://github.com/theos/theos) installed and configured.
* Patched iOS 6.1 SDK (due to modern Xcode dropping 32-bit architecture support).

## Building & Installation

1. Clone the repository:
   ```bash
   git clone [https://github.com/YOUR_USERNAME/ScreenRec6.git](https://github.com/YOUR_USERNAME/ScreenRec6.git)
   cd ScreenRec6

```

2. Point Theos to your jailbroken device's IP address (ensure OpenSSH is installed on the device):
```bash
export THEOS_DEVICE_IP=192.168.1.xxx

```


3. Build and install:
```bash
make package install

```


*Note: Default SSH password for iOS is `alpine`.*

## Project Structure

```text
ScreenRec6/
├── Makefile                # Root Makefile (Aggregate)
├── Tweak.xm                # Core Recording Engine (SpringBoard Hook)
├── control                 # Debian Package Metadata
├── layout/                 # SBSettings Themes & Icons
│   └── var/mobile/Library/SBSettings/Themes/Default/ScreenRecToggle/
│       ├── on.png & off.png       # Standard Icons
│       └── on@2x.png & off@2x.png # Retina Icons
└── toggle/                 # SBSettings Subproject
    ├── Makefile            # Toggle Library Makefile
    └── Toggle.m            # Broadcasts NSNotification to SpringBoard

```

## Usage

1. Open the **SBSettings** app from your SpringBoard.
2. Navigate to **Set Window Toggles** and enable `ScreenRecToggle`.
3. Swipe the status bar to open the SBSettings drop-down.
4. Tap the record icon. An iOS Alert will prompt you to choose between **"With Audio"** or **"Without Audio"**.
5. To stop recording, tap the toggle again.
6. Navigate to `/var/mobile/Documents/` using iFile to view your `ScreenRecord_...mp4` files.

## Known Limitations

* Writing 30 FPS on an A5 chip (iPhone 4S) causes thermal throttling and frame drops. The tweak is hardcoded to **15 FPS** (`frameInterval = 4`) to ensure system stability.
* Internal system audio (games/music) is recorded via the hardware microphone. True IPC internal audio routing via `mediaserverd` is not implemented in this version.

## License

This project is open-sourced under the [MIT License](https://www.google.com/search?q=LICENSE).
