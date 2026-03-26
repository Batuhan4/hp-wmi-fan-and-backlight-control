
# Module name
obj-m += hp-wmi.o

# Kernel build directory (respect the kernel we are building for)
TARGET_KERNEL_RELEASE := $(if $(KERNELRELEASE),$(KERNELRELEASE),$(shell uname -r))
KDIR := /lib/modules/$(TARGET_KERNEL_RELEASE)/build

PKGNAME := $(shell grep -oP 'PACKAGE_NAME="\K[^"]+' dkms.conf)
VERSION := $(shell grep -oP 'PACKAGE_VERSION="\K[^"]+' dkms.conf)

# Current directory
PWD := $(shell pwd)

# Detect compatibility APIs in kernel headers
# WMI notify handler changed from u32 event IDs to union acpi_object payloads in newer kernels.
ACPI_HDR := $(KDIR)/include/linux/acpi.h
HPWMI_HAVE_U32_WMI_NOTIFY := $(shell [ -r $(ACPI_HDR) ] && grep -Eq 'typedef[[:space:]]+void[[:space:]]+\(\*wmi_notify_handler\)[[:space:]]*\(u32 value, void \*context\);' $(ACPI_HDR) && echo 1 || echo 0)

# platform_driver.remove transitioned through remove_new before settling on void remove.
PLATFORM_DEVICE_HDR := $(KDIR)/include/linux/platform_device.h
HPWMI_HAVE_PLATFORM_DRIVER_REMOVE_NEW := $(shell [ -r $(PLATFORM_DEVICE_HDR) ] && grep -Eq 'void[[:space:]]+\(\*remove_new\)\(struct platform_device \*\);' $(PLATFORM_DEVICE_HDR) && echo 1 || echo 0)
HPWMI_PLATFORM_DRIVER_REMOVE_RETURNS_INT := $(shell [ -r $(PLATFORM_DEVICE_HDR) ] && grep -Eq 'int[[:space:]]+\(\*remove\)\(struct platform_device \*\);' $(PLATFORM_DEVICE_HDR) && echo 1 || echo 0)

# Detect availability of the devm_platform_profile_register API in kernel headers
PLATFORM_PROFILE_HDR := $(KDIR)/include/linux/platform_profile.h
HPWMI_HAVE_DEVM_PLATFORM_PROFILE := $(shell [ -r $(PLATFORM_PROFILE_HDR) ] && grep -q "devm_platform_profile_register" $(PLATFORM_PROFILE_HDR) && echo 1 || echo 0)

# Propagate feature flags to the module build
ccflags-y += -DHPWMI_HAVE_U32_WMI_NOTIFY=$(HPWMI_HAVE_U32_WMI_NOTIFY)
ccflags-y += -DHPWMI_HAVE_PLATFORM_DRIVER_REMOVE_NEW=$(HPWMI_HAVE_PLATFORM_DRIVER_REMOVE_NEW)
ccflags-y += -DHPWMI_PLATFORM_DRIVER_REMOVE_RETURNS_INT=$(HPWMI_PLATFORM_DRIVER_REMOVE_RETURNS_INT)
ccflags-y += -DHPWMI_HAVE_DEVM_PLATFORM_PROFILE=$(HPWMI_HAVE_DEVM_PLATFORM_PROFILE)

# Default target
all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

# Clean target
clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
	rm -rf *.pkg.tar.zst

install: all
	$(MAKE) -C $(KDIR) M=$(PWD) modules_install
	depmod -a

install-dkms:
	dkms add .
	dkms build -m $(PKGNAME) -v $(VERSION)
	dkms install -m $(PKGNAME) -v $(VERSION)

install-arch:
	makepkg -si

uninstall:
	rm -f /lib/modules/$(shell uname -r)/extra/hp-wmi.ko
	depmod -a

uninstall-dkms:
	dkms remove -m $(PKGNAME) -v $(VERSION) --all
	rm -rf /usr/src/$(PKGNAME)-$(VERSION)

.PHONY: all clean install uninstall install-dkms uninstall-dkms install-arch
