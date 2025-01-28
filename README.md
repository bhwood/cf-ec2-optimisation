# Ubuntu Memory Optimisation Script (Docker-Aware)

This script is designed to optimise memory usage on Ubuntu systems, with additional configuration tailored for Docker environments. It includes system-level tuning, Docker-specific settings, and a daily cleanup routine to ensure optimal performance.

---

## Features

1. **System Memory Optimisation**
   - Adjusts kernel memory management settings (e.g., `vm.swappiness`, `vm.dirty_ratio`).
   - Configures file handle and user process limits for improved performance.

2. **Docker-Specific Optimisations**
   - Enables network optimisations (`net.ipv4.ip_forward`, `bridge-nf-call-iptables`).
   - Sets Docker daemon memory limits and logging options.

3. **System Cleanup**
   - Cleans up unused packages, cached files, and systemd journal logs.
   - Creates a daily cron job for Docker data cleanup and journal log trimming.

4. **Systemd Configuration**
   - Optimises the size of systemd journal files.
   - Configures memory limits for the Docker service.

5. **Safety Mechanisms**
   - Includes rollback functionality for Docker configuration in case of a failure.

---

## Usage

### Prerequisites
- The script **must be run as root** or with `sudo`:
  ```bash
  sudo ./ubuntu_optimise.sh
  ```

### Steps Performed
1. **Memory Management Configuration**  
   Updates kernel memory settings in `/etc/sysctl.d/99-memory-optimise.conf` and applies the changes.

2. **System Limits for Docker**  
   Creates `/etc/security/limits.d/docker.conf` to increase file handle and process limits.

3. **Systemd Journal Optimisation**  
   Configures systemd journald limits in `/etc/systemd/journald.conf.d/size.conf` and restarts the journal service.

4. **Docker Daemon Optimisation**  
   Updates `/etc/docker/daemon.json` to configure logging, ulimits, and storage settings.

5. **System Cleanup**  
   - Runs `apt-get clean` and `apt-get autoremove` to free up disk space.
   - Creates a daily cron job for Docker and journal cleanup in `/etc/cron.daily/docker-cleanup`.

6. **Docker Service Limits**  
   Configures Docker service memory limits in `/etc/systemd/system/docker.service.d/memory-limits.conf` and reloads systemd.

### Post-Execution
After running the script:
- **Reboot your system** for all changes to take effect:
  ```bash
  sudo reboot
  ```

- Record the memory usage output displayed at the end of the script. Compare this with the memory usage after reboot to confirm the optimisations.

---

## Rollback Mechanism

In case of issues with Docker:
- The script automatically rolls back to a minimal Docker configuration if the Docker service fails to restart after applying changes.
- A backup of the original `/etc/docker/daemon.json` is saved as `/etc/docker/daemon.json.bak`.

---

## Daily Cleanup Job

The script sets up a cron job at `/etc/cron.daily/docker-cleanup` to:
- Remove unused Docker data:
  ```bash
  docker system prune -f --volumes
  ```
- Trim systemd journal logs:
  ```bash
  journalctl --vacuum-size=100M
  ```

---

## Tested On
- Ubuntu 24.04+
- Docker Engine v19.03+  

---

## License

This script is open-source and available under the MIT License.

---

## Disclaimer

Use this script at your own risk. While it has been tested, improper use may affect system performance or stability. Always review the script before running it in a production environment.