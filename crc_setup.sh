#!/bin/bash

set -e

echo "[*] Detecting OS type..."

if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
else
    echo "Unable to detect OS. Exiting."
    exit 1
fi

install_yum_prereqs() {
    echo "[*] Installing dependencies for YUM-based system..."

    sudo dnf install -y NetworkManager \
                        libvirt \
                        virt-install \
                        qemu-kvm \
                        virt-viewer \
                        virt-top \
                        libvirt-daemon-config-network \
                        libvirt-daemon-kvm \
                        libvirt-daemon-driver-qemu \
                        libvirt-daemon-driver-lxc \
                        dnsmasq \
                        cockpit \
                        jq \
                        wget \
                        tar \
                        xz \
                        git \
                        podman \
                        iptables \
                        selinux-policy \
                        virtiofsd

    echo "[*] Enabling and starting libvirtd and NetworkManager..."
    sudo systemctl enable --now libvirtd NetworkManager
}

install_debian_prereqs() {
    echo "[*] Installing dependencies for Debian-based system..."

    sudo apt-get update
    sudo apt-get install -y network-manager \
                            libvirt-daemon-system \
                            libvirt-clients \
                            qemu-kvm \
                            virt-manager \
                            dnsmasq \
                            jq \
                            wget \
                            tar \
                            xz-utils \
                            git \
                            podman \
                            iptables \
                            virtiofsd

    echo "[*] Adding current user to libvirt and kvm groups..."
    sudo usermod -aG libvirt "$(whoami)"
    sudo usermod -aG kvm "$(whoami)"

    echo "[*] Enabling and starting libvirtd and NetworkManager..."
    sudo systemctl enable --now libvirtd NetworkManager
}

case "$DISTRO" in
    ubuntu|debian)
        install_debian_prereqs
        ;;
    rhel|centos|fedora|rocky|almalinux)
        install_yum_prereqs
        ;;
    *)
        echo "Unsupported distribution: $DISTRO"
        exit 1
        ;;
esac

# Setup CRC
echo "[*] Setting up CRC from local GitHub clone..."

# Check if repo exists
if [ ! -d "crc_setup" ]; then
    echo "[*] Cloning your CRC setup repo..."
    git clone https://github.com/arunvel1988/crc_setup
fi

cd crc_setup

# Extract CRC binary
echo "[*] Extracting CRC binary..."
tar -xf crc-linux-amd64.tar.xz
sudo mv crc-linux-*/crc /usr/local/bin/
chmod +x /usr/local/bin/crc

# Check if pull-secret file exists
PULL_SECRET=$(find . -type f -name "pull-secret*" | head -n 1)
if [ -z "$PULL_SECRET" ]; then
    echo "[x] pull-secret file not found in crc_setup directory."
    exit 1
fi

echo "[*] Configuring CRC with pull-secret..."
crc config set pull-secret-file "$(realpath $PULL_SECRET)"

echo "[*] Running crc setup..."
crc setup

echo "[*] Starting CRC (this may take some time)..."
crc start

echo "[✓] CRC setup completed successfully."

echo
echo "[!] NOTE: If this is your first time using libvirt, you may need to reboot or re-login for group changes to take effect."
