#!/usr/bin/env bash
set -e

RGBDS_DIR="rgbds"
BASE_URL="https://github.com/gbdev/rgbds/releases/download/v0.6.1"

# Detect OS
case "$(uname -s)" in
    Linux)                           OS="Linux";   ARCHIVE="rgbds-0.6.1-linux-x86_64.tar.xz" ;;
    Darwin)                          OS="macOS";   ARCHIVE="rgbds-0.6.1-macos-x86-64.zip" ;;
    MINGW64*|MINGW32*|CYGWIN*|MSYS*) OS="Windows"; ARCHIVE="rgbds-0.6.1-win64.zip" ;;
    *)                               echo "Error: Unsupported OS '$(uname -s)'."; exit 1 ;;
esac

# Detect package manager
detect_pkg_manager() {
    for pm in apt-get dnf pacman zypper brew; do
        command -v "$pm" >/dev/null 2>&1 && { echo "$pm"; return; }
    done
    echo "none"
}

# Map generic dep names to distro-specific package names
resolve_pkg_name() {
    local dep="$1"
    local PM
    PM=$(detect_pkg_manager)
    case "$PM" in
        apt-get)
            case "$dep" in
                libpng) echo "libpng-dev" ;;
                bison)  echo "bison" ;;
                flex)   echo "flex" ;;
                zlib)   echo "zlib1g-dev" ;;
            esac ;;
        dnf)
            case "$dep" in
                libpng) echo "libpng-devel" ;;
                bison)  echo "bison" ;;
                flex)   echo "flex" ;;
                zlib)   echo "zlib-devel" ;;
            esac ;;
        pacman)
            case "$dep" in
                libpng) echo "libpng" ;;
                bison)  echo "bison" ;;
                flex)   echo "flex" ;;
                zlib)   echo "zlib" ;;
            esac ;;
        zypper)
            case "$dep" in
                libpng) echo "libpng16-devel" ;;
                bison)  echo "bison" ;;
                flex)   echo "flex" ;;
                zlib)   echo "zlib-devel" ;;
            esac ;;
        brew)
            case "$dep" in
                libpng) echo "libpng" ;;
                bison)  echo "bison" ;;
                flex)   echo "flex" ;;
                zlib)   echo "zlib" ;;
            esac ;;
        *) echo "$dep" ;;
    esac
}

# Install a package via the detected package manager
install_pkg() {
    local pkg="$1"
    local PM
    PM=$(detect_pkg_manager)

    if [ "$PM" = "none" ]; then
        echo "Error: No supported package manager found. Please install '$pkg' manually."
        exit 1
    fi

    echo "Attempting to install '$pkg' using $PM..."
    case "$PM" in
        apt-get) sudo apt-get install -y "$pkg" ;;
        dnf)     sudo dnf install -y "$pkg" ;;
        pacman)
            if [[ "$(uname -s)" == MINGW64* ]]; then
                pacman -S --noconfirm "$pkg"
            elif [[ "$(uname -s)" == MINGW32* ]]; then
                pacman -S --noconfirm "$pkg"
            elif [[ "$(uname -s)" == MSYS* ]]; then
                pacman -S --noconfirm "$pkg"
            else
                sudo pacman -S --noconfirm "$pkg"
            fi ;;
        zypper)  sudo zypper install -y "$pkg" ;;
        brew)    brew install "$pkg" ;;
    esac
}

# Check for a script dependency, offer to install if missing
check_dep() {
    local cmd="$1"
    local pkg="${2:-$1}"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Warning: '$cmd' is not installed."
        read -r -p "Install '$pkg' now? [y/N] " response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            install_pkg "$pkg"
        else
            echo "Error: '$cmd' is required. Please install it and rerun."
            exit 1
        fi
    fi
}

echo "Checking dependencies..."
check_dep curl
[[ "$ARCHIVE" == *.zip ]] && check_dep unzip || check_dep tar

# Check RGBDS runtime dependencies (Linux and macOS — Windows archive is self-contained)
if [ "$OS" = "Linux" ] || [ "$OS" = "macOS" ]; then
    # Check shared libraries (libpng, zlib)
    if [ "$OS" = "Linux" ]; then
        for dep in libpng zlib; do
            if ! ldconfig -p 2>/dev/null | grep -q "$dep"; then
                pkg=$(resolve_pkg_name "$dep")
                echo "Warning: '$dep' may be missing."
                read -r -p "Attempt to install '$pkg' now? [y/N] " response
                [[ "$response" =~ ^[Yy]$ ]] && install_pkg "$pkg" \
                    || echo "Warning: '$dep' missing — RGBDS binaries may not run."
            fi
        done
    elif [ "$OS" = "macOS" ]; then
        for dep in libpng zlib; do
            if ! brew list "$dep" >/dev/null 2>&1; then
                pkg=$(resolve_pkg_name "$dep")
                echo "Warning: '$dep' may be missing."
                read -r -p "Attempt to install '$pkg' now? [y/N] " response
                [[ "$response" =~ ^[Yy]$ ]] && install_pkg "$pkg" \
                    || echo "Warning: '$dep' missing — RGBDS binaries may not run."
            fi
        done
    fi
    # Check executables (bison, flex) — same on both platforms
    for dep in bison flex; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            pkg=$(resolve_pkg_name "$dep")
            echo "Warning: '$dep' may be missing."
            read -r -p "Attempt to install '$pkg' now? [y/N] " response
            [[ "$response" =~ ^[Yy]$ ]] && install_pkg "$pkg" \
                || echo "Warning: '$dep' missing — RGBDS binaries may not run."
        fi
    done
fi

mkdir -p "$RGBDS_DIR"

[ ! -f "$ARCHIVE" ] \
    && { echo "Downloading RGBDS 0.6.1 for $OS..."; curl -L -o "$ARCHIVE" "$BASE_URL/$ARCHIVE"; } \
    || echo "Archive already exists, skipping download."

echo "Extracting to $RGBDS_DIR/..."
case "$ARCHIVE" in
    *.zip)    unzip -o "$ARCHIVE" -d "$RGBDS_DIR" ;;
    *.tar.xz) tar -xf "$ARCHIVE" -C "$RGBDS_DIR" ;;
esac

rm -f "$ARCHIVE"

# Verify the install by running rgbasm if found in the output dir
RGBASM_BIN=$(find "$RGBDS_DIR" -name "rgbasm" | head -1)
if [ -n "$RGBASM_BIN" ]; then
    if ! "$RGBASM_BIN" --version >/dev/null 2>&1; then
        echo "Warning: RGBDS was extracted but 'rgbasm' failed to run."
        echo "You may be missing a runtime library. Check above warnings."
    fi
fi

echo "Done! RGBDS installed in '$RGBDS_DIR'."