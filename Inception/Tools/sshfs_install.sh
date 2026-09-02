#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Script: sshfs_install.sh
# Purpose: Download and install SSHFS into user-space (~/.local/bin) without root.
# ==============================================================================

INSTALL_PREFIX="${1:-$HOME/.local}"
BIN_DIR="${INSTALL_PREFIX}/bin"
MAN_DIR="${INSTALL_PREFIX}/share/man/man1"
TEMP_DIR="$(mktemp -d /tmp/sshfs_install_XXXXXX)"

cleanup() {
    rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

echo "==> Target install directory: ${BIN_DIR}"
mkdir -p "${BIN_DIR}" "${MAN_DIR}"

# 1. Download the SSHFS .deb package from Ubuntu/Debian repositories without root
echo "==> Downloading sshfs package..."
(
    cd "${TEMP_DIR}"
    apt-get download sshfs
)

# 2. Extract the package contents into a temporary directory
echo "==> Extracting package..."
(
    cd "${TEMP_DIR}"
    dpkg -x ./*.deb ./extracted
)

# 3. Copy binary and manual page into user prefix
echo "==> Installing binary and man page..."
cp "${TEMP_DIR}/extracted/usr/bin/sshfs" "${BIN_DIR}/"
chmod +x "${BIN_DIR}/sshfs"

if compgen -G "${TEMP_DIR}/extracted/usr/share/man/man1/*.1.gz" > /dev/null || compgen -G "${TEMP_DIR}/extracted/usr/share/man/man1/*.1" > /dev/null; then
    cp "${TEMP_DIR}/extracted/usr/share/man/man1/"* "${MAN_DIR}/" 2>/dev/null || true
fi

# 4. Verify installation
echo "==> Verifying installation..."
if "${BIN_DIR}/sshfs" -V; then
    echo ""
    echo "✔ Successfully installed sshfs to ${BIN_DIR}/sshfs"
else
    echo "❌ sshfs installation check failed."
    exit 1
fi

# 5. Check if PATH includes the binary directory
if [[ ":$PATH:" != *":${BIN_DIR}:"* ]]; then
    echo ""
    echo "Note: '${BIN_DIR}' is not in your current PATH."
    echo "Add it by running:"
    echo "  export PATH=\"${BIN_DIR}:\$PATH\""
    echo "Or add it to your ~/.bashrc / ~/.zshrc."
fi
