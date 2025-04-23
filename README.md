# Raspberry Pi 5 Camera Recording App

A simple Flutter application for Raspberry Pi 5 that lets you record video from an AI camera with a big button interface. The recorded videos are saved to a predefined directory.

## Features

- Large, easy-to-press recording button
- Live camera preview
- Automatic video saving to predefined directory
- Visual feedback during recording
- Works on Raspberry Pi 5 with connected camera

## Prerequisites

- Raspberry Pi 5
- Connected AI camera or compatible camera module
- Flutter SDK installed on your development machine
- Raspberry Pi OS with Flutter support

## Installation

1. Clone this repository:
   ```
   git clone <repository-url>
   cd video
   ```

2. Install dependencies:
   ```
   flutter pub get
   ```

3. Connect your Raspberry Pi to your development machine or set up Flutter development directly on the Raspberry Pi.

4. Run the app:
   ```
   flutter run -d <device-id>
   ```

## Configuration

The app saves videos to the following locations depending on the platform:
- Raspberry Pi (Linux): `/home/pi/videos/`
- Windows: `Documents\RaspberryPiVideos\`
- Other platforms: Documents directory + `/RaspberryPiVideos/`

You can change the save directory by modifying the `_setupVideoDirectory()` method in `lib/main.dart`.

## Usage

1. Launch the app on your Raspberry Pi
2. Allow camera permissions if prompted
3. Press the large blue "START RECORDING" button to begin recording
4. Press the red "STOP RECORDING" button to stop recording
5. A notification will show the path where your video was saved

## Troubleshooting

If you encounter issues:

- Ensure your camera is properly connected to the Raspberry Pi
- Check that the app has proper permissions to access the camera
- Verify that the storage directory is writable
- Look for error messages in the console output

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Flutter Camera plugin
- Raspberry Pi Foundation
