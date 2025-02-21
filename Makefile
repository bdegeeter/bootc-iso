# Variables
IMAGE_NAME=bootc-iso
IMAGE_TAG=latest
IMAGE_TAR=$(IMAGE_NAME).tar
ISO_NAME=bootc-anaconda.iso
BOOTC_BUILDER_CONFIG=config.toml  # Ensure this file exists and is configured properly
BOOTC_BUILDER_IMAGE=quay.io/centos-bootc/bootc-image-builder:sha256-b4eb0793837e627b5cd08bbb641ddf7f22b013d5d2f4d7d593ca6261f2126550

# QEMU settings
QEMU_EXEC=qemu-system-aarch64
QEMU_RAM=4G
#QEMU_CPUS=2
QEMU_CPUS=cpus=10,sockets=1,cores=10,threads=1
QEMU_DISK=qemu-disk.img
QEMU_DISK_SIZE=20G  # Adjust disk size as needed
BOOT_ISO=$(PWD)/output/bootiso/install.iso
QEMU_DIR="$(shell dirname "$$(command -v $(QEMU_EXEC))")"
QEMU_EDK2_CODE=/opt/homebrew/Cellar/qemu/9.2.0/share/qemu/edk2-aarch64-code.fd

# Build the bootc image using Podman
build:
	podman build -t $(IMAGE_NAME):$(IMAGE_TAG) -f Containerfile

# Export the bootc image to a tar file for bootc-image-builder
export:
	podman save -o $(IMAGE_TAR) $(IMAGE_NAME):$(IMAGE_TAG)

# Create an Anaconda ISO using the bootc-image-builder container
iso:
	mkdir -p $(PWD)/output
	podman run --rm \
		--name $(IMAGE_NAME)-bootc-image-builder \
		--tty \
		--privileged \
		--security-opt label=type:unconfined_t \
		-v $(PWD):/workspace \
		-v $(PWD)/output:/output \
		-v /var/lib/containers/storage:/var/lib/containers/storage \
		-v $(PWD)/config.json:/config.json:ro \
		--label bootc.image.builder=true \
		$(BOOTC_BUILDER_IMAGE) \
		localhost/$(IMAGE_NAME):$(IMAGE_TAG) \
		--output /output/ \
		--local \
		--type anaconda-iso \
		--target-arch arm64 \
		--rootfs xfs

# Run the ISO in QEMU if qemu-system-x86_64 is available
#-drive file=$(QEMU_DISK),format=qcow2 
run:
	if command -v $(QEMU_EXEC) >/dev/null 2>&1; then \
		if [ ! -f $(QEMU_DISK) ]; then \
			echo "Creating virtual disk $(QEMU_DISK)..."; \
			qemu-img create -f qcow2 $(QEMU_DISK) $(QEMU_DISK_SIZE); \
		fi; \
		echo "Starting QEMU with $(ISO_NAME)..."; \
		$(QEMU_EXEC) \
			-machine virt,gic-version=3 \
			-cpu host \
			-m $(QEMU_RAM) \
			-accel hvf \
			-drive file=$(QEMU_DISK),format=qcow2 \
			-drive if=pflash,format=raw,unit=0,file.filename=$(QEMU_EDK2_CODE),file.locking=off,readonly=on \
			-cdrom $(BOOT_ISO) \
			-usb \
			-device virtio-gpu-pci \
			-device qemu-xhci,id=usb-controller-0 \
			-device intel-hda \
			-device nec-usb-xhci,id=usb-bus \
			-device usb-tablet,bus=usb-bus.0 \
			-device usb-mouse,bus=usb-bus.0 \
			-device usb-kbd,bus=usb-bus.0 \
			-boot d \
			-vga none \
			; \
	else \
		echo "QEMU is not installed. Please install $(QEMU_EXEC)."; \
		exit 1; \
	fi

# Clean up generated files
clean:
	rm -f $(IMAGE_TAR) $(ISO_NAME) $(QEMU_DISK)
	podman rmi $(IMAGE_NAME):$(IMAGE_TAG) -f

.PHONY: build export iso clean