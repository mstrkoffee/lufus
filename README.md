# Lufus.sh - Linux Windows USB Creator

**Big Boy Edition** - Create bootable Windows USB drives from ISO files on Linux, no Rufus or Ventoy needed.

## Features
- Interactive ISO selection from Downloads folder
- Interactive device selection with safety checks
- Proper GPT/UEFI partition layout for Windows boot
- NTFS support for large Windows install files (>4GB install.wim)
- Works on RHEL, Ubuntu, and other Linux distros

## Requirements
```bash
# RHEL/Fedora/Rocky
sudo dnf install ntfs-3g ntfsprogs parted util-linux

# Debian/Ubuntu
sudo apt install ntfs-3g parted
```

## Usage
```bash
chmod +x lufus.sh
sudo ./lufus.sh
```

## What it does
1. Creates GPT partition table on target USB drive
2. Creates 500MB FAT32 EFI partition for UEFI boot
3. Creates NTFS data partition for Windows installation files
4. Extracts and copies Windows ISO contents to proper partitions
5. Sets up bootable UEFI structure for Windows installer

## Why not just `dd`?
Windows ISOs aren't hybrid images - they need proper filesystem layout and can contain files >4GB that won't fit on FAT32. This script handles it properly.

## Safety Features
- Requires explicit "YES" confirmation before wiping
- Shows device size/model before selection
- Unmounts partitions safely
- Validates ISO and device selection

## License
MIT - Do whatever you want with it

## Author
Built for sysadmins who prefer Linux but occasionally need to deploy Windows servers.
