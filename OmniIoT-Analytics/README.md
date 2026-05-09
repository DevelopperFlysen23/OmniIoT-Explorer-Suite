# OmniIoT Analytics

**OmniIoT Analytics** is a powerful and modular MATLAB application designed for the visualization and analysis of IoT data. Originally built to explore ThingSpeak channels, it has been refactored for better performance, modularity, and a modern user experience.

![Preview](resources/preview.png)

## Key Features

- **Multi-Mode Analysis**: Compare recent data with historical periods (Time Compare) or stack multiple channels side-by-side (Channel Compare).
- **Modular Architecture**: Built with a decoupled design, separating the UI from data fetching logic (ThingSpeakClient).
- **Customizable Themes**: Includes a high-contrast dark "Midnight" theme designed for modern dashboards.
- **Dynamic Controls**: Smart UI that auto-updates when settings change.
- **Data Retiming**: Resample irregular IoT data to minutely, hourly, or daily intervals on the fly.
- **Export Ready**: Framework included for future expansion to PDF and image exports.

## Getting Started

### Prerequisites

- MATLAB R2021a or later.
- ThingSpeak Support Toolbox (for ThingSpeak data access).

### Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/OmniIoT-Analytics.git
   ```
2. Add the `toolbox` folder to your MATLAB path.
3. Run the application:
   ```matlab
   app = OmniIoTAnalyst;
   ```

## Project Structure

- `toolbox/OmniIoTAnalyst.m`: Main application class (UI and orchestration).
- `toolbox/ThingSpeakClient.m`: Dedicated client for interacting with the ThingSpeak REST API.
- `resources/`: Assets and icons for the application.

## How to Use

1. **Analysis Mode**: Choose "Time" to compare a single channel across two periods, or "Channel" to compare different sensors.
2. **Channel ID**: Enter your ThingSpeak Channel ID (e.g., `38629`).
3. **Data Selection**: Pick your start date, duration (e.g., 3 days), and any historical offset.
4. **Update**: Click the green **UPDATE** button to fetch and plot data.
5. **Auto-Update**: Once plotted, changing most controls will automatically refresh the dashboard.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request or open an issue for new features (like support for Adafruit IO or Blynk).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
*Note: This project was inspired by and refactored from the IoT Data Explorer by MathWorks.*
