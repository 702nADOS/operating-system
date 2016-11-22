# options: x86 arm
TOOLCHAIN_TARGET    ?= arm

# options: see tool/create_builddir
GENODE_TARGET       ?= focnados_panda

BUILD_DIR           ?= /build
TOOLCHAIN_BUILD_DIR ?= $(BUILD_DIR)/toolchain-$(TOOLCHAIN_TARGET)
GENODE_BUILD_DIR    ?= $(BUILD_DIR)/genode-$(GENODE_TARGET)
BUILD_CONF           = $(GENODE_BUILD_DIR)/etc/build.conf

all: ports platform

# ================================================================
# Genode toolchain. Only needs to be done once per target (x86/arm).
toolchain:
	mkdir -p $(TOOLCHAIN_BUILD_DIR)
	cd $(TOOLCHAIN_BUILD_DIR);\
	genode/tool/tool_chain $(TOOLCHAIN_TARGET)
#
# ================================================================


# ================================================================
# Download Genode external sources. Only needs to be done once per system.
ports: foc libports dde_linux

foc:
	$(MAKE) -C genode/repos/base-focnados prepare

libports:
	$(MAKE) -C genode/repos/libports prepare

dde_linux:
	$(MAKE) -C genode/repos/dde_linux prepare
#
# ================================================================


# ================================================================
# Genode build process. Rebuild subtargets as needed.
platform: genode_build_dir

genode_build_dir:
	genode/tool/create_builddir $(GENODE_TARGET) BUILD_DIR=$(GENODE_BUILD_DIR)
	printf 'REPOSITORIES += $$(GENODE_DIR)/repos/libports\n' >> $(BUILD_CONF)
	printf 'REPOSITORIES += $$(GENODE_DIR)/../genode-dom0-HW\n' >> $(BUILD_CONF)
	printf 'REPOSITORIES += $$(GENODE_DIR)/../genode-Taskloader\n' >> $(BUILD_CONF)
	printf 'REPOSITORIES += $$(GENODE_DIR)/../genode-Parser\n' >> $(BUILD_CONF)
	printf 'REPOSITORIES += $$(GENODE_DIR)/repos/dde_linux\n' >> $(BUILD_CONF)

# Delete build directory for all target systems. In some cases, subfolders in the contrib directory might be corrupted. Remove manually and re-prepare if necessary.
clean:
	rm -rf $(BUILD_DIR)
#
# ================================================================


# ================================================================
# Run Genode with an active dom0 server.
run:
	$(MAKE) -C $(GENODE_BUILD_DIR) run/dom0-HW #declare which run file to run
	sudo cp /build/genode-focnados_panda/var/run/dom0-HW/image.elf /var/lib/tftpboot/
	sudo cp /build/genode-focnados_panda/var/run/dom0-HW/modules.list /var/lib/tftpboot/
	sudo cp -R /build/genode-focnados_panda/var/run/dom0-HW/genode /var/lib/tftpboot/
	
#
# ================================================================

# ================================================================
# Requiered packages for relaunched systems
packages:
	sudo apt-get update
	sudo apt-get install libncurses5-dev texinfo autogen autoconf2.64 g++ libexpat1-dev flex bison gperf cmake libxml2-dev libtool zlib1g-dev libglib2.0-dev make pkg-config gawk subversion expect git libxml2-utils syslinux xsltproc yasm iasl lynx unzip qemu
#
# ================================================================

# ================================================================
# VDE setup. Do once per system session. DHCP is optional.
vde: vde-stop
	@vde_switch -d -s /tmp/switch1
	@sudo vde_tunctl -u $(USER) -t tap0
	@sudo ifconfig tap0 192.168.217.254 up
	@sudo route add -host 192.168.217.5 dev tap0
	@vde_plug2tap --daemon -s /tmp/switch1 tap0

vde-stop:
	@-pkill vde_switch
	@-sudo vde_tunctl -d tap0
	@-rm -rf /tmp/switch1

dhcp: dhcp-stop
	@slirpvde -d -s /tmp/switch1 -dhcp

dhcp-stop:
	@-pkill slirpvde

# Cleanup network shenanigans.
clean-network: dhcp-stop vde-stop
#
# ================================================================
