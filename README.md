# NixOffice: Production-Grade NixOS Distribution for Office Environments

## Overview

**NixOffice** is a declarative, reproducible NixOS-based distribution designed specifically for modern office workflows. Built on NixOS 25.05, it emphasizes free and open-source software (FOSS) while providing seamless integration with the Google ecosystem (e.g., Gmail, Docs, Drive, Meet, Calendar). It supports both x86_64 and aarch64 (ARM64) architectures, making it versatile for desktops, laptops, and ARM-based devices like Raspberry Pi or Pinebook.

Key principles:
- **Reproducibility**: Powered by Nix flakes for deterministic builds—identical configurations across machines.
- **Security**: Full-disk LUKS encryption (root and optional swap), firewall by default, and no unfree software to minimize vulnerabilities.
- **Efficiency**: Optimized for resource usage with optional desktop environments (GNOME, KDE Plasma, or both), automatic Nix store optimization, and garbage collection.
- **Productivity**: Pre-configured FOSS tools for email, documents, collaboration, and cloud sync, reducing setup time for IT teams.
- **Flexibility**: Installer allows customization of architecture, desktops, swap, and more during deployment.

NixOffice is MIT-licensed, ensuring it's free for personal, commercial, or enterprise use. It's ideal for small-to-medium offices, remote workers, or open-source advocates seeking a secure, maintainable alternative to Ubuntu or Fedora.

**Target Use Cases**:
- Daily office tasks: Document editing (LibreOffice), web collaboration (Chromium for Google Workspace), email/calendar (Thunderbird/Evolution).
- Secure environments: Encrypted storage for sensitive data, firewall for network protection.
- Diverse hardware: x86 desktops/laptops or ARM for lightweight, power-efficient setups (e.g., Raspberry Pi kiosks for shared calendars).
- IT-managed deployments: Flake-based for consistent rollouts and rollbacks.

**System Requirements**:
- **Hardware**: 4GB+ RAM (8GB+ recommended for dual DEs), 20GB+ disk space. ARM64: Mid-range devices (e.g., Raspberry Pi 4/5 with 4GB+ RAM) for smooth performance.
- **Boot Media**: UEFI/EFI mode preferred; U-Boot for some ARM.
- **Network**: Internet required for initial install (downloads nixpkgs).

## Features

NixOffice delivers a lean, production-ready base with optional extensions. Core components:

### Core System
- **Kernel & Boot**: systemd-boot with EFI support; LUKS-encrypted ext4 root (TRIM-enabled for SSDs).
- **Networking**: NetworkManager for WiFi/Ethernet; Avahi for mDNS (e.g., printer discovery).
- **Audio/Video**: PipeWire for modern audio routing; Bluetooth for peripherals (headsets for Meet calls).
- **Printing**: CUPS enabled for office printers/scanners.
- **Fonts**: Noto and Liberation for crisp document rendering.

### Security & Maintenance
- **Encryption**: LUKS on root (prompt at boot); optional encrypted swap.
- **Firewall**: Enabled with Avahi exceptions.
- **Updates**: `system.autoUpgrade` for non-rebooting patches; flake updates for controlled upgrades.
- **Nix Optimizations**:
  - `auto-optimise-store = true`: Hardlinks duplicate files, saving 20-50% storage.
  - `max-jobs = 4; cores = 2`: Limits rebuilds to prevent overload (adjustable).
  - Automatic GC: Weekly cleanup of old generations (>30 days).

### Desktop Environments (Optional)
- **GNOME**: Native Google Online Accounts integration (Calendar, Drive, Contacts). Wayland-enabled.
- **KDE Plasma 6**: Highly customizable; Dolphin/Ark for file management. Wayland-enabled.
- **Selection**: Choose during install (both, one, or none for minimal X11). SDDM as display manager.
- **Fallback**: If no DE, basic Xserver for lightweight setups (add DEs later via config).

### Productivity Tools
All FOSS, installed for the primary user:
- **Browsers**: Chromium (Google sync/extensions), Firefox (alternative).
- **Office Suite**: LibreOffice (Docs/Sheets alternative), Evince/Okular (PDF viewers).
- **Email/Calendar**: Thunderbird (Gmail IMAP), Evolution (native Google sync).
- **Cloud Sync**: rclone (Google Drive mount/sync CLI; GUI via browser).
- **Graphics/Notes**: GIMP (images), Inkscape (vectors), Joplin (notes, Keep alternative).
- **Utilities**: Vim (config editing), Git (version control), VLC (media), Remmina (RDP/VNC for remote access), htop/tree (monitoring).
- **System-Wide**: wget, vim, htop, tree.

**Google Ecosystem Integration**:
- Web: Chromium for full Workspace support.
- Native: GNOME Online Accounts for Calendar/Drive (if GNOME enabled).
- Sync: rclone for automated backups/mounts (e.g., `rclone mount gdrive: ~/Drive`).

### Architecture Support
- **x86_64**: Full features, including CPU microcode (Intel/AMD).
- **aarch64**: Optimized for ARM; skips x86-specific options. Packages like Chromium/LibreOffice available via Nix cache.

## Installation Guide

NixOffice uses a self-contained bash installer embedded in the flake—no separate files needed. It's foolproof with prompts, validation, logging, and error recovery.

### Prerequisites
1. Download NixOS 25.05 ISO:
   - x86_64: https://nixos.org/download.html (Graphical or Minimal).
   - aarch64: https://nixos.org/download.html#nixos-arm (e.g., for Raspberry Pi).
2. Boot the ISO:
   - x86: USB flash drive.
   - ARM: SD card (e.g., Raspberry Pi Imager).
3. Connect to network (e.g., `nmcli dev wifi connect <SSID> password <PASS>`).
4. Enable flakes (if not pre-enabled):
   ```bash
   # Edit /etc/nixos/configuration.nix
   nix.extraOptions = "experimental-features = nix-command flakes";

   # Rebuild
   nixos-rebuild switch
   ```

### Running the Installer
1. Clone or run remotely:
   ```bash
   # Local (if cloned repo)
   nix run .#installer

   # Remote
   nix run github:<your-username>/nixoffice#installer
   ```
2. Follow interactive prompts:
   - **Architecture**: x86_64 (default) or aarch64.
   - **Disk**: Target device (e.g., /dev/sda; lists available disks). **Warning**: Erases all data—confirm with 'YES'.
   - **Hostname**: nixoffice (default).
   - **Timezone**: America/New_York (example); validates against /usr/share/zoneinfo.
   - **Username**: user (default).
   - **Password**: Secure passphrase (confirmed twice).
   - **Swap**: Size in GiB (0 for none; enables LUKS-encrypted swap).
   - **Desktops**: Enable GNOME? (y/n, default y); Enable Plasma? (y/n, default y). Warns if none selected.
   - **CPU (x86 only)**: intel/amd (default intel) for KVM/microcode.
3. The script handles:
   - Partitioning (GPT: 512MiB EFI, optional swap, rest root).
   - LUKS setup (prompt for passphrase).
   - Mounting, hardware detection (`nixos-generate-config`).
   - Config generation (embeds optimized NixOS flake).
   - Installation (`nixos-install --flake`).
   - Password setting and cleanup.
4. Log: /tmp/nixoffice-install.log for debugging.

**Estimated Time**: 10-20 minutes (downloads ~2-4GB).

### Verification
After reboot:
1. Enter LUKS passphrase.
2. Log in as your user.
3. Switch to flake config:
   ```bash
   sudo nixos-rebuild switch --flake /etc/nixos#<hostname>
   ```
4. Test: Open Chromium, add Google account in Settings (GNOME/KDE).

## Post-Installation Configuration

### Google Workspace Setup
- **Browser**: Launch Chromium; sign in to Google for sync.
- **Email/Calendar**: In Thunderbird/Evolution, add Gmail account (IMAP/OAuth).
- **Drive Sync**: 
  ```bash
  rclone config  # Create 'gdrive' remote
  rclone mount gdrive: ~/Drive  # Mount as filesystem
  ```
- **Meet**: Use Chromium (hardware acceleration via PipeWire).

### Customizations
- **Add Unfree Software** (e.g., Zoom for Meet alternatives):
  Edit `/etc/nixos/configuration.nix`:
  ```nix
  nixpkgs.config.allowUnfree = true;
  users.users.<username>.packages = with pkgs; [ zoom-us ];
  ```
  Rebuild: `sudo nixos-rebuild switch --flake /etc/nixos#<hostname>`.
- **Disable DE**: Set `services.desktopManager.gnome.enable = false;` (or plasma6).
- **ARM-Specific** (e.g., Raspberry Pi 4/5):
  ```nix
  # In configuration.nix
  boot.loader.raspberryPi.enable = true;  # U-Boot if non-EFI
  boot.kernelPackages = pkgs.linuxPackages_rpi4;  # Pi 4 kernel
  hardware.raspberry-pi."4".fkms-3d.enable = true;  # GPU acceleration
  ```
- **Backups**: Add to config:
  ```nix
  services.borgbackup.jobs = {
    home = {
      paths = [ "/home/<username>" ];
      repo = "gdrive:borg-repo";  # Via rclone
    };
  };
  ```
- **VPN/Remote Access**: Enable OpenVPN or SSH:
  ```nix
  services.sshd.enable = true;
  services.openvpn.servers.office = { ... };  # Your config
  ```

### Maintenance
- **Updates**:
  - Channel (auto): Handled by `system.autoUpgrade`.
  - Flake: `nix flake update /etc/nixos && sudo nixos-rebuild switch --flake /etc/nixos#<hostname>`.
- **Rollback**: `nixos-rebuild switch --rollback` if issues.
- **Monitoring**: Use htop; check logs with `journalctl -u nixos-upgrade`.
- **Garbage Collection**: Automatic weekly; manual: `nix-collect-garbage -d`.

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| **Boot Failure (LUKS)** | Wrong passphrase | Boot ISO, `cryptsetup luksOpen /dev/<disk>2 root`, mount, chroot, reset. |
| **Installer Errors** | Network/Disk | Check `/tmp/nixoffice-install.log`; retry after `ping 8.8.8.8`. |
| **No Display** | DE Disabled | Edit config, set `services.desktopManager.gnome.enable = true;`, rebuild. |
| **ARM Performance Slow** | Low RAM/GPU | Disable Wayland (`services.displayManager.sddm.wayland.enable = false;`); add Pi-specific hardware. |
| **Package Missing** | Not in nixpkgs | Search `nix search nixpkgs <pkg>`; add to `users.users.<username>.packages`. |
| **Flake Update Fails** | Pin conflict | `nix flake lock --update-input nixpkgs`. |
| **Bluetooth/Printing Issues** | Hardware | `systemctl restart bluetooth`; `systemctl restart cups`. |

For hardware quirks, run `nixos-generate-config` in live ISO and merge into `/etc/nixos/hardware-configuration.nix`.

## Known Limitations
- **Google Drive**: rclone is CLI-focused; no native desktop client (use browser for GUI).
- **Low-End ARM**: Desktops may lag; test with single DE or minimal X11.
- **Unfree**: Disabled by default; enable manually for proprietary tools.
- **No GUI Installer**: CLI-based for precision; suitable for sysadmins.

## Contributing & Support
- **Repository**: Fork https://github.com/<your-username>/nixoffice.
- **Issues**: Report bugs/feature requests on GitHub.
- **Community**: Discuss on NixOS Discourse or Reddit (r/NixOS).
- **Extensions**: Add modules (e.g., VSCode via `pkgs.vscodium`) and PR.

## License
NixOffice is distributed under the MIT License. See [LICENSE](LICENSE) for full text. Copyright (c) 2025 [Your Name or Organization]. No warranties provided—use at your own risk.

---

*Last Updated: October 24, 2025*  
For questions, open a GitHub issue or consult the NixOS manual (`man configuration.nix`).
