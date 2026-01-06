#!/bin/bash
# Lufus.sh - Linux USB Formatter (Big Boy Edition)
# Creates proper Windows bootable USB without Rufus

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Lufus.sh - Linux USB Formatter ===${NC}\n"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (sudo ./Lufus.sh)${NC}"
    exit 1
fi

# Check for required tools
if ! command -v mkfs.ntfs &> /dev/null; then
    echo -e "${RED}Error: mkfs.ntfs not found${NC}"
    echo -e "${YELLOW}Install with: sudo apt install ntfs-3g${NC}"
    echo -e "${YELLOW}or : sudo dnf install ntfs-3g${NC}"
    exit 1
fi

# Get the user who invoked sudo
if [ -n "$SUDO_USER" ]; then
    ACTUAL_USER="$SUDO_USER"
else
    ACTUAL_USER="$USER"
fi

ISO_DIR="/home/$ACTUAL_USER/Downloads"

# List ISO files
echo -e "${YELLOW}Available ISO files in $ISO_DIR:${NC}"
mapfile -t ISOS < <(find "$ISO_DIR" -maxdepth 1 -type f -name "*.iso" 2>/dev/null)

if [ ${#ISOS[@]} -eq 0 ]; then
    echo -e "${RED}No ISO files found in $ISO_DIR${NC}"
    exit 1
fi

for i in "${!ISOS[@]}"; do
    SIZE=$(du -h "${ISOS[$i]}" | cut -f1)
    echo "  [$i] $(basename "${ISOS[$i]}") - $SIZE"
done

echo -e -n "\n${GREEN}Select ISO number:${NC} "
read -r ISO_NUM

if ! [[ "$ISO_NUM" =~ ^[0-9]+$ ]] || [ "$ISO_NUM" -ge ${#ISOS[@]} ]; then
    echo -e "${RED}Invalid selection${NC}"
    exit 1
fi

SELECTED_ISO="${ISOS[$ISO_NUM]}"
echo -e "${GREEN}Selected: $(basename "$SELECTED_ISO")${NC}\n"

# List block devices
echo -e "${YELLOW}Available block devices:${NC}"
lsblk -d -o NAME,SIZE,TYPE,TRAN | grep -E "disk|NAME"
echo ""

mapfile -t DEVICES < <(lsblk -d -n -o NAME,SIZE,TYPE,TRAN | grep "disk" | awk '{print $1}')

for i in "${!DEVICES[@]}"; do
    DEV="${DEVICES[$i]}"
    SIZE=$(lsblk -d -n -o SIZE "/dev/$DEV")
    TRAN=$(lsblk -d -n -o TRAN "/dev/$DEV")
    MODEL=$(lsblk -d -n -o MODEL "/dev/$DEV" | xargs)
    echo "  [$i] /dev/$DEV - $SIZE - $TRAN - $MODEL"
done

echo -e -n "\n${GREEN}Select device number:${NC} "
read -r DEV_NUM

if ! [[ "$DEV_NUM" =~ ^[0-9]+$ ]] || [ "$DEV_NUM" -ge ${#DEVICES[@]} ]; then
    echo -e "${RED}Invalid selection${NC}"
    exit 1
fi

SELECTED_DEV="/dev/${DEVICES[$DEV_NUM]}"
echo -e "${YELLOW}Selected: $SELECTED_DEV${NC}\n"

# Confirm
echo -e "${RED}WARNING: This will DESTROY all data on $SELECTED_DEV${NC}"
echo -e "ISO: $(basename "$SELECTED_ISO")"
echo -e "Device: $SELECTED_DEV"
echo -e -n "\n${YELLOW}Type 'YES' to continue:${NC} "
read -r CONFIRM

if [ "$CONFIRM" != "YES" ]; then
    echo -e "${RED}Aborted${NC}"
    exit 1
fi

echo -e "\n${GREEN}Starting USB creation...${NC}\n"

# Unmount any mounted partitions
echo "Unmounting any mounted partitions..."
umount ${SELECTED_DEV}* 2>/dev/null || true

# Wipe device
echo "Wiping device..."
wipefs -a "$SELECTED_DEV"

# Create GPT partition table
echo "Creating GPT partition table..."
parted -s "$SELECTED_DEV" mklabel gpt

# Create EFI partition (500MB)
echo "Creating EFI partition..."
parted -s "$SELECTED_DEV" mkpart primary fat32 1MiB 501MiB
parted -s "$SELECTED_DEV" set 1 esp on

# Create main data partition
echo "Creating data partition..."
parted -s "$SELECTED_DEV" mkpart primary ntfs 501MiB 100%

# Wait for kernel to recognize partitions
sleep 2
partprobe "$SELECTED_DEV"
sleep 2

# Format partitions
echo "Formatting EFI partition (FAT32)..."
mkfs.vfat -F32 "${SELECTED_DEV}1"

echo "Formatting data partition (NTFS)..."
mkfs.ntfs -f "${SELECTED_DEV}2"

# Create mount points
MOUNT_BASE="/tmp/lufus_$$"
mkdir -p "$MOUNT_BASE"/{iso,usb,efi}

# Mount ISO
echo "Mounting ISO..."
mount -o loop "$SELECTED_ISO" "$MOUNT_BASE/iso"

# Mount USB partitions
echo "Mounting USB partitions..."
mount "${SELECTED_DEV}2" "$MOUNT_BASE/usb"
mount "${SELECTED_DEV}1" "$MOUNT_BASE/efi"

# Copy files
echo "Copying files to data partition (this may take a while)..."
cp -r "$MOUNT_BASE/iso/"* "$MOUNT_BASE/usb/"

echo "Copying EFI boot files..."
cp -r "$MOUNT_BASE/iso/efi/"* "$MOUNT_BASE/efi/"

# Sync and unmount
echo "Syncing..."
sync

echo "Unmounting..."
umount "$MOUNT_BASE/iso"
umount "$MOUNT_BASE/usb"
umount "$MOUNT_BASE/efi"

# Cleanup
rmdir "$MOUNT_BASE"/{iso,usb,efi}
rmdir "$MOUNT_BASE"

echo -e "\n${GREEN}=== Done! ===${NC}"
echo -e "${GREEN}Your bootable USB is ready on $SELECTED_DEV${NC}"
echo -e "${YELLOW}You can now safely remove the USB drive${NC}\n"
