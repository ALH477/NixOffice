{
  description = "NixOffice: Optimized determinate NixOS config for production-grade office system";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  outputs = { self, nixpkgs }: let
    supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
    forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);
  in {
    nixosConfigurations = forAllSystems (system: nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        # Placeholder; actual config embedded in script
      ];
    });

    apps = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      installScript = pkgs.writeShellScriptBin "nixos-office-installer" ''
        #!/usr/bin/env bash

        # NixOffice Installation Script (Optimized, with DE Selection)
        # Production-ready, embedded configs, MIT licensed.

        set -euo pipefail

        # Colors
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[1;33m'
        NC='\033[0m'

        # Log file
        LOG=/tmp/nixoffice-install.log
        exec > >(tee -a "$LOG") 2>&1
        echo "$(date): Starting NixOffice installation" >> "$LOG"

        # Check root
        if [[ $EUID -ne 0 ]]; then
            echo -e "$\{RED\}ERROR: Run as root!$\{NC\}"
            exit 1
        fi

        # Check NixOS live
        if ! command -v nixos-install &>/dev/null; then
            echo -e "$\{RED\}ERROR: Run from NixOS live ISO!$\{NC\}"
            exit 1
        fi

        # Check EFI
        if [[ ! -d /sys/firmware/efi ]]; then
            echo -e "$\{RED\}ERROR: Boot in EFI mode! (Note: Some ARM devices use U-Boot; adjust if needed.)$\{NC\}"
            exit 1
        fi

        # Check internet
        echo -e "$\{YELLOW\}Checking internet...$\{NC\}"
        if ! ping -c 3 8.8.8.8 &>/dev/null; then
            echo -e "$\{RED\}ERROR: No internet. Connect and retry.$\{NC\}"
            echo "Tip: nmcli dev wifi list; nmcli dev wifi connect <SSID> password <PASS>"
            exit 1
        fi

        # Prompt architecture
        echo -e "$\{YELLOW\}Enter system architecture (x86_64 or aarch64, default: x86_64):$\{NC\}"
        read -r ARCH
        ARCH=''${ARCH:-x86_64}
        if [[ "$ARCH" != "x86_64" && "$ARCH" != "aarch64" ]]; then
            echo -e "$\{RED\}Invalid architecture!$\{NC\}"
            exit 1
        fi
        SYSTEM="$ARCH-linux"

        # Prompt disk
        echo -e "$\{YELLOW\}Available disks:$\{NC\}"
        lsblk -d -o NAME,SIZE,MODEL,TYPE | grep disk
        echo -e "$\{YELLOW\}Enter target disk (e.g., sda, nvme0n1, mmcblk0 for ARM, default: sda):$\{NC\}"
        read -r DISK_INPUT
        DISK=''${DISK_INPUT:-sda}
        DISK_DEV="/dev/$DISK"
        if [[ ! -b "$DISK_DEV" ]]; then
            echo -e "$\{RED\}ERROR: $DISK_DEV invalid!$\{NC\}"
            exit 1
        fi
        PART_SUFFIX=''${DISK/#*[0-9]/p}
        EFI_PART="$\{DISK_DEV\}$\{PART_SUFFIX\}1"
        ROOT_PART="$\{DISK_DEV\}$\{PART_SUFFIX\}2"
        SWAP_PART="$\{DISK_DEV\}$\{PART_SUFFIX\}3"

        # Confirm erase
        echo -e "$\{RED\}WARNING: Will ERASE $DISK_DEV! Backup data now.$\{NC\}"
        read -p "Type 'YES' to proceed: " CONFIRM
        [[ "$CONFIRM" != "YES" ]] && { echo -e "$\{RED\}Aborted.$\{NC\}"; exit 1; }

        # Prompt hostname
        echo -e "$\{YELLOW\}Enter hostname (default: nixoffice):$\{NC\}"
        read -r HOSTNAME
        HOSTNAME=''${HOSTNAME:-nixoffice}

        # Prompt timezone
        echo -e "$\{YELLOW\}Enter timezone (e.g., America/New_York, default: UTC):$\{NC\}"
        read -r TIMEZONE
        TIMEZONE=''${TIMEZONE:-UTC}
        if [[ ! -f "/usr/share/zoneinfo/$TIMEZONE" ]]; then
            echo -e "$\{RED\}Invalid timezone!$\{NC\}"
            exit 1
        fi

        # Prompt username
        echo -e "$\{YELLOW\}Enter username (default: user):$\{NC\}"
        read -r USERNAME
        USERNAME=''${USERNAME:-user}

        # Prompt password
        echo -e "$\{YELLOW\}Enter password for $USERNAME:$\{NC\}"
        read -s PASSWORD
        echo
        echo -e "$\{YELLOW\}Confirm:$\{NC\}"
        read -s PASSWORD_CONFIRM
        echo
        [[ "$PASSWORD" != "$PASSWORD_CONFIRM" ]] && { echo -e "$\{RED\}Passwords mismatch!$\{NC\}"; exit 1; }

        # Prompt swap size
        echo -e "$\{YELLOW\}Enter swap size in GiB (0 for none, default: 0):$\{NC\}"
        read -r SWAP_SIZE
        SWAP_SIZE=''${SWAP_SIZE:-0}
        if ! [[ $SWAP_SIZE =~ ^[0-9]+$ ]]; then
            echo -e "$\{RED\}Invalid swap size!$\{NC\}"
            exit 1
        fi
        HAS_SWAP=$((SWAP_SIZE > 0))

        # Prompt DEs
        echo -e "$\{YELLOW\}Enable GNOME desktop? (y/n, default: y):$\{NC\}"
        read -r ENABLE_GNOME
        ENABLE_GNOME=''${ENABLE_GNOME:-y}
        if [[ "$ENABLE_GNOME" == "y" ]]; then
            GNOME_ENABLE="true"
        else
            GNOME_ENABLE="false"
        fi

        echo -e "$\{YELLOW\}Enable KDE Plasma desktop? (y/n, default: y):$\{NC\}"
        read -r ENABLE_PLASMA
        ENABLE_PLASMA=''${ENABLE_PLASMA:-y}
        if [[ "$ENABLE_PLASMA" == "y" ]]; then
            PLASMA_ENABLE="true"
        else
            PLASMA_ENABLE="false"
        fi

        if [[ "$ENABLE_GNOME" != "y" && "$ENABLE_PLASMA" != "y" ]]; then
            echo -e "$\{YELLOW\}Warning: No desktop selected. Installing minimal X11; add DEs post-install.$\{NC\}"
        fi

        # CPU type (x86 only)
        CPU_TYPE="none"
        CPU_MODULE=""
        CPU_MICROCODE=""
        if [[ "$ARCH" == "x86_64" ]]; then
            echo -e "$\{YELLOW\}Enter CPU type (intel/amd, default: intel):$\{NC\}"
            read -r CPU_TYPE
            CPU_TYPE=''${CPU_TYPE:-intel}
            if [[ "$CPU_TYPE" != "intel" && "$CPU_TYPE" != "amd" ]]; then
                echo -e "$\{RED\}Invalid CPU type!$\{NC\}"
                exit 1
            fi
            CPU_MODULE="kvm-$CPU_TYPE"
            CPU_MICROCODE="$CPU_TYPE.updateMicrocode"
        else
            echo -e "$\{YELLOW\}ARM64 detected: Skipping x86-specific CPU config.$\{NC\}"
        fi

        # Partition disk
        echo -e "$\{YELLOW\}Partitioning $DISK_DEV...$\{NC\}"
        parted -s "$DISK_DEV" mklabel gpt
        parted -s "$DISK_DEV" mkpart ESP fat32 1MiB 512MiB
        parted -s "$DISK_DEV" set 1 esp on
        if $HAS_SWAP; then
            parted -s "$DISK_DEV" mkpart primary 512MiB $((512 + SWAP_SIZE * 1024))MiB
            parted -s "$DISK_DEV" mkpart primary $((512 + SWAP_SIZE * 1024))MiB 100%
            ROOT_PART="$\{DISK_DEV\}$\{PART_SUFFIX\}3"
            SWAP_PART="$\{DISK_DEV\}$\{PART_SUFFIX\}2"
        else
            parted -s "$DISK_DEV" mkpart primary 512MiB 100%
        fi

        # Format EFI
        mkfs.vfat -F 32 -n BOOT "$EFI_PART"

        # LUKS root
        echo -e "$\{YELLOW\}Setup LUKS on $ROOT_PART (enter passphrase):$\{NC\}"
        cryptsetup luksFormat "$ROOT_PART"
        cryptsetup luksOpen "$ROOT_PART" root
        mkfs.ext4 -L nixos /dev/mapper/root

        # Swap if enabled
        if $HAS_SWAP; then
            cryptsetup -q luksFormat --type luks1 "$SWAP_PART"
            cryptsetup luksOpen "$SWAP_PART" swap
            mkswap /dev/mapper/swap
            SWAP_UUID=$(blkid -s UUID -o value "$SWAP_PART")
        fi

        # Mount
        echo -e "$\{YELLOW\}Mounting...$\{NC\}"
        mount /dev/mapper/root /mnt
        mkdir -p /mnt/boot
        mount "$EFI_PART" /mnt/boot

        # Generate base hardware config
        nixos-generate-config --root /mnt

        # Get UUIDs
        BOOT_UUID=$(blkid -s UUID -o value "$EFI_PART")
        LUKS_UUID=$(blkid -s UUID -o value "$ROOT_PART")

        # Embedded configuration.nix
        cat << 'EOF' > /mnt/etc/nixos/configuration.nix
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.luks.devices = {
    root = {
      device = "/dev/disk/by-uuid/LUKS_UUID_PLACEHOLDER";
      allowDiscards = true;
    };
  };

  networking.hostName = "HOSTNAME_PLACEHOLDER";
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

  time.timeZone = "TIMEZONE_PLACEHOLDER";

  i18n.defaultLocale = "en_US.UTF-8";

  services.xserver.enable = true;

  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;

  services.desktopManager.gnome.enable = GNOME_ENABLE_PLACEHOLDER;
  services.desktopManager.plasma6.enable = PLASMA_ENABLE_PLACEHOLDER;

  services.gnome.gnome-online-accounts.enable = GNOME_ENABLE_PLACEHOLDER;
  services.gnome.gnome-keyring.enable = true;

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = ALSASUPPORT_PLACEHOLDER;
    pulse.enable = true;
  };

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  users.users.USERNAME_PLACEHOLDER = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    packages = with pkgs; [
      vim
      chromium
      firefox
      libreoffice
      thunderbird
      evolution
      rclone
      gimp
      inkscape
      vlc
      git
      dolphin
      ark
      evince
      okular
      joplin-desktop
      remmina
    ];
  };

  environment.systemPackages = with pkgs; [
    vim
    wget
    htop
    tree
  ];

  services.printing.enable = true;

  fonts.packages = with pkgs; [ noto-fonts liberation_ttf ];

  system.autoUpgrade = {
    enable = true;
    allowReboot = false;
  };

  nix = {
    package = pkgs.nixFlakes;
    extraOptions = "experimental-features = nix-command flakes";
    settings.auto-optimise-store = true;
    settings.max-jobs = 4;
    settings.cores = 2;
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  system.stateVersion = "25.05";
}
EOF

        # Embedded hardware-configuration.nix
        cat << 'EOF' > /mnt/etc/nixos/hardware-configuration.nix
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "CPU_MODULE_PLACEHOLDER" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/mapper/root";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/BOOT_UUID_PLACEHOLDER";
      fsType = "vfat";
    };

  # Optional swap
  SWAP_PLACEHOLDER

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "SYSTEM_PLACEHOLDER";
  MICROCODE_PLACEHOLDER
}
EOF

        # Embedded flake.nix
        cat << 'EOF' > /mnt/etc/nixos/flake.nix
{
  description = "NixOffice: Optimized determinate NixOS config for office system";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  outputs = { self, nixpkgs }: {
    nixosConfigurations.HOSTNAME_PLACEHOLDER = nixpkgs.lib.nixosSystem {
      system = "SYSTEM_PLACEHOLDER";
      modules = [
        ./configuration.nix
      ];
    };
  };
}
EOF

        # Apply placeholders
        sed -i "s/LUKS_UUID_PLACEHOLDER/$LUKS_UUID/" /mnt/etc/nixos/configuration.nix
        sed -i "s/HOSTNAME_PLACEHOLDER/$HOSTNAME/" /mnt/etc/nixos/configuration.nix
        sed -i "s/HOSTNAME_PLACEHOLDER/$HOSTNAME/" /mnt/etc/nixos/flake.nix
        sed -i "s/TIMEZONE_PLACEHOLDER/$TIMEZONE/" /mnt/etc/nixos/configuration.nix
        sed -i "s/USERNAME_PLACEHOLDER/$USERNAME/g" /mnt/etc/nixos/configuration.nix
        sed -i "s/CPU_MODULE_PLACEHOLDER/$CPU_MODULE/" /mnt/etc/nixos/hardware-configuration.nix
        sed -i "s/BOOT_UUID_PLACEHOLDER/$BOOT_UUID/" /mnt/etc/nixos/hardware-configuration.nix
        sed -i "s/SYSTEM_PLACEHOLDER/$SYSTEM/" /mnt/etc/nixos/hardware-configuration.nix
        sed -i "s/SYSTEM_PLACEHOLDER/$SYSTEM/" /mnt/etc/nixos/flake.nix
        sed -i "s/GNOME_ENABLE_PLACEHOLDER/$GNOME_ENABLE/" /mnt/etc/nixos/configuration.nix
        sed -i "s/PLASMA_ENABLE_PLACEHOLDER/$PLASMA_ENABLE/" /mnt/etc/nixos/configuration.nix

        if [[ "$ARCH" == "x86_64" ]]; then
            sed -i "s/MICROCODE_PLACEHOLDER/hardware.cpu.$CPU_MICROCODE = lib.mkDefault config.hardware.enableRedistributableFirmware;/" /mnt/etc/nixos/hardware-configuration.nix
            sed -i "s/ALSASUPPORT_PLACEHOLDER/true/" /mnt/etc/nixos/configuration.nix
        else
            sed -i "s/MICROCODE_PLACEHOLDER//" /mnt/etc/nixos/hardware-configuration.nix
            sed -i "s/ALSASUPPORT_PLACEHOLDER/false/" /mnt/etc/nixos/configuration.nix
        fi

        if $HAS_SWAP; then
            sed -i "s/SWAP_PLACEHOLDER/swapDevices = [ { device = \"\/dev\/disk\/by-uuid\/$SWAP_UUID\"; randomEncryption = true; } ];/" /mnt/etc/nixos/hardware-configuration.nix
        else
            sed -i "s/SWAP_PLACEHOLDER//" /mnt/etc/nixos/hardware-configuration.nix
        fi

        # Copy LICENSE
        cat << 'EOF' > /mnt/etc/nixos/LICENSE
MIT License

Copyright (c) 2025 [Your Name or Organization]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

        # Install
        echo -e "${YELLOW}Installing NixOffice ($ARCH)...${NC}"
        nixos-install --flake /mnt/etc/nixos#$HOSTNAME --no-root-passwd || {
            echo -e "${RED}Install failed! See $LOG.${NC}"
            umount -R /mnt
            cryptsetup close root
            $HAS_SWAP && cryptsetup close swap
            exit 1
        }

        # Set password
        echo "$USERNAME:$PASSWORD" | chpasswd -R /mnt

        # Cleanup
        umount -R /mnt
        cryptsetup close root
        $HAS_SWAP && cryptsetup close swap

        echo -e "${GREEN}NixOffice installed! Log: $LOG. License: MIT (see /etc/nixos/LICENSE).${NC}"
        echo -e "${YELLOW}Reboot, enter LUKS passphrase, login as $USERNAME, run: sudo nixos-rebuild switch --flake /etc/nixos#$HOSTNAME${NC}"
        echo -e "${YELLOW}For ARM-specific tweaks (e.g., Raspberry Pi GPU), edit configuration.nix and rebuild.${NC}"
      '';
    in {
      installer = {
        type = "app";
        program = "${installScript}/bin/nixos-office-installer";
      };
    });
  };
}
