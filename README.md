# Raspberry Pi 5 AI Camera Recording App

A Flutter application that lets you record video from a Raspberry Pi 5 AI camera with a big button interface. The app uses the native `libcamera-vid` command to record videos and saves them to a predefined directory.

## Features

- Large, easy-to-press recording button
- Integration with Raspberry Pi's libcamera-vid command
- Automatic video saving to predefined directory
- Visual feedback during recording
- Log display for monitoring camera operations

## Prerequisites

- Raspberry Pi 5
- Connected AI camera module
- Raspberry Pi OS with libcamera-apps installed
- Flutter SDK installed on your development machine or on the Raspberry Pi
- GPAC/MP4Box installed for H264 to MP4 conversion (optional)

## Installation

1. Install necessary packages on your Raspberry Pi:
   ```
   sudo apt-get update
   sudo apt-get install libcamera-apps
   sudo apt-get install gpac  # For MP4Box to convert H264 to MP4
   ```

2. Clone this repository:
   ```
   git clone <repository-url>
   cd video
   ```

3. Install Flutter dependencies:
   ```
   flutter pub get
   ```

4. Run the app on Raspberry Pi:
   ```
   flutter run -d linux
   ```

## Configuration

The app saves videos to `/home/pi/videos/` by default on Raspberry Pi.

You can modify the recording parameters in the `_startRecording()` method in `lib/main.dart` to adjust resolution, framerate, and other camera settings.

## Usage

1. Launch the app on your Raspberry Pi
2. Press the large blue "START RECORDING" button to begin recording
3. Press the red "STOP RECORDING" button to stop recording
4. Videos are saved in H264 format and automatically converted to MP4 if MP4Box is installed

## Troubleshooting

If you encounter issues:

- Make sure your AI camera is properly connected to the Raspberry Pi
- Verify that libcamera-apps is installed (`sudo apt-get install libcamera-apps`)
- Check that the videos directory is writable (`chmod -R 777 /home/pi/videos`)
- For MP4 conversion, ensure gpac is installed (`sudo apt-get install gpac`)
- Review the log display at the bottom of the app for error messages

## Using libcamera-vid Command Directly

You can also use the libcamera-vid command directly from the terminal:

```
libcamera-vid --output test.h264 --width 1920 --height 1080 --timeout 10000
```

This will record a 10-second video at 1080p resolution.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Raspberry Pi Foundation
- libcamera project
