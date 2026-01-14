# Linux System Maintenance

An automated **Linux system maintenance Bash script** that keeps your system **updated, clean, optimized, and healthy** with a single command.

Designed to be **cron-safe**, **TTY-aware**, and visually clean, this script is suitable for both servers and desktop systems.

---

## ✨ Features

* 🔄 **System Updates**

  * Automatically detects your package manager
  * Applies full system upgrades

* 🧹 **Smart Cleanup**

  * Removes unused and orphaned packages
  * Cleans package caches
  * Estimates removed packages

* 🗄️ **Disk Optimization**

  * Journal log vacuuming (last 7 days)
  * TRIM unused disk blocks (if supported)
  * Disk space comparison (before vs after)

* 🩺 **System Health Checks**

  * Detects failed `systemd` services
  * Displays affected service names

* 🖥️ **User-Friendly UI**

  * Clean terminal layout
  * Spinner for long-running tasks
  * Color-coded output
  * Execution time per task
  * Final summary report

* 🔐 **Safe & Reliable**

  * Keeps `sudo` alive during execution
  * CI / cron compatible
  * Graceful interrupt handling

---

## 🐧 Supported Linux Distributions

The script automatically detects your OS using `/etc/os-release`.

Supported families:

| Distro Family   | Package Manager |
| --------------- | --------------- |
| Debian / Ubuntu | `apt`           |
| Fedora / RHEL   | `dnf`           |
| Arch Linux      | `pacman`        |

> Most derivatives of these distributions should work without modification.

---

## 📦 Requirements

* Bash 4+
* `sudo`
* `systemd`
* `jq` (required for service health checks)

Install `jq` if missing:

```bash
# Debian / Ubuntu
sudo apt install jq

# Fedora
sudo dnf install jq

# Arch
sudo pacman -S jq
```

---

## Usage

### 1. Clone the Repository

```bash
git clone https://github.com/jeong5758/Linux-System-Maintenance.git
```

### 2.  Enter the Directory

```bash
cd linux-system-maintenance
```

### 3. Make the Script Executable

```bash
chmod +x linux-system-maintenance-V.1.sh
```

### 4. Run the Script

```bash
sudo ./linux-system-maintenance-V.1.sh
```

The script will:

* Ask for `sudo` **once**
* Keep `sudo` alive automatically
* Show progress with a spinner
* Display a detailed summary when finished

---

## Install as a System Command (Recommended)

Run the script from anywhere like a built-in Linux command.

### Option 1: Install to `/usr/local/bin`

```bash
sudo cp linux-system-maintenance-V.1.sh /usr/local/bin/update
sudo chmod +x /usr/local/bin/update
```

Now run:

```bash
sudo update
```

---

### Option 2: Custom Command Name

```bash
sudo cp linux-system-maintenance-V.1.sh /usr/local/bin/<custom-name>
sudo chmod +x /usr/local/bin/<custom-name>
```

Run with:

```bash
sudo <custom-name>
```

---

## 🧾 Example Summary Output

```
Updates available   5
Updates applied     5
Packages removed    3 (estimate)
Disk recovered      420 MB
Services failed     0
```

---

## ⚠️ Notes & Safety

* Designed for **interactive terminals**, but safe for:

  * cron jobs
  * SSH sessions
  * CI environments
* TRIM runs only if supported
* Failed services are **reported**, not restarted automatically

---

## 📄 License

This project is licensed under the **MIT License**.

---

## 👤 Author

**Jeong**

---

## ⭐ Contributions

Issues, suggestions, and pull requests are welcome.
If you find this useful, consider giving it a ⭐!

---
