# AutoRclone: Secure GDrive Backup Automation

AutoRclone is a modern, interactive CLI tool that automates Google Drive backups on Linux. Built with a terminal user interface (TUI), it handles one-way and two-way synchronization, native background automation via systemd, and robust Telegram alerting with offline queueing.

## Key Features

* **Interactive UI**: Powered by `charmbracelet/gum` for a modern, frictionless setup experience without touching configuration files.
* **Native Linux Automation**: Automatically generates and configures `systemd` user timers for reliable background execution. No messy cron jobs required.
* **Self-Healing Telegram Alerts**: Get instant backup reports sent directly to your Telegram. If your internet is down during a backup, AutoRclone queues the text messages and log files, sending them automatically once you are back online.
* **Multi-Profile Support**: Create, view, update, and safely delete multiple independent backup profiles and Google Drive remotes.
* **Smart Sync Modes**: Supports One-way Sync (Local to Drive or Drive to Local) and Stateful Two-way Sync (rclone bisync).
* **Zero-Touch Dependencies**: Automatically detects your Linux distribution and installs required packages (rclone, curl, gum) safely.

## Prerequisites

* A Linux environment (Ubuntu, Debian, Fedora, Arch, or openSUSE).
* A Google Drive account.
* (Optional) A Telegram Bot Token and Chat ID for notifications.

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/reck98/autorclone.git
   cd AutoRclone


2. Make the script executable:
```bash
chmod +x autorclone.sh

```


3. Run the installer:
```bash
./autorclone.sh

```



## Usage

When you run the script, you will be greeted by the main menu. Use your arrow keys and Enter to navigate.

* **Create New Profile**: Guides you through selecting a local folder, a Google Drive folder, your sync mode, and your backup interval. It automatically sets up the systemd timers and Telegram alerts.
* **View Profile Settings**: Safely inspect the configuration of any existing profile, including paths and intervals, without making changes.
* **Update Profile**: Modify existing parameters like the backup interval, sync mode, or Telegram credentials. The systemd timers are updated automatically.
* **Delete Profile**: Safely removes a profile, stops and deletes its systemd daemon, and cleans up the environment files.
* **View / Delete Remote**: Manage your underlying rclone Google Drive connections. Deleting a remote will safely prompt you if active profiles are relying on it.

## Architecture and File Paths

AutoRclone safely stores its configurations in your home directory without cluttering root system files. Everything is executed in user-space.

* **Config Directory**: `~/.autorclone/` (Stores `.env` variables and background `.sh` execution scripts).
* **Log Files**: `~/.autorclone/.autorclone_logs/` (Stores isolated logs and offline Telegram queues for each profile. A copy of the latest log is also saved directly to your local sync directory).
* **Systemd Services**: `~/.config/systemd/user/` (Stores the generated `.timer` and `.service` daemon files).

## Uninstallation

To fully remove a specific profile, run the script and select "Delete Profile". This safely disables the background systemd timers, removes the profile configurations, and cleans up the execution scripts.

If you wish to remove AutoRclone entirely:

1. Delete all active profiles via the script menu.
2. Delete the main config directory: `rm -rf ~/.autorclone/`
3. Delete the script file: `rm autorclone.sh`

## Contributing

Contributions, issues, and feature requests are welcome. Feel free to open an issue or submit a pull request if you want to help improve the tool.

## License

This project is licensed under the MIT License.

```

```
