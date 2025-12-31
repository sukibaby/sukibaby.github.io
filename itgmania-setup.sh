#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'
umask 022

REPO_DIR="${HOME}/itgmania"

die() {
    echo "ERROR: $*" >&2
    exit 1
}

have() { command -v "$1" >/dev/null 2>&1; }

cpu_jobs() {
    local jobs
    jobs="$(getconf _NPROCESSORS_ONLN 2>/dev/null || true)"
    if [[ -z "${jobs}" ]] || ! [[ "${jobs}" =~ ^[0-9]+$ ]] || (( jobs < 1 )); then
        jobs=1
    fi
    printf '%s' "${jobs}"
}

as_root() {
    if [[ "$(id -u)" -eq 0 ]]; then
        "$@"
    elif have sudo; then
        sudo "$@"
    else
        die "sudo is required (or run this script as root)."
    fi
}

on_error() {
    local exit_code=$?
    local line_no=${BASH_LINENO[0]:-?}
    local cmd=${BASH_COMMAND:-?}
    echo "ERROR: command failed (exit ${exit_code}) at line ${line_no}: ${cmd}" >&2
    exit "${exit_code}"
}
trap on_error ERR

echo "Howdy partner :] Just gonna get itgmania set up over here :]"

if [[ "$(uname -s)" != "Linux" ]]; then
    die "This setup script currently only supports Linux."
fi

# Apt-only support
if have apt-get; then
    echo "Found apt-get :D"

    as_root apt-get update

    packages=(
        build-essential
        git cmake
        libasound2-dev libgl-dev libglu1-mesa-dev libgtk-3-dev libjack-dev libmad0-dev libpulse-dev
        libudev-dev libxinerama-dev libx11-dev libxrandr-dev libxtst-dev
        nasm unzip wget
    )

    if ! as_root apt-get install -y "${packages[@]}"; then
        echo "apt-get install failed; attempting a one-time apt-get upgrade then retrying..." >&2
        as_root apt-get upgrade -y
        as_root apt-get install -y "${packages[@]}"
    fi

    echo "Packages installed successfully via apt-get!"
else
    die "Couldn't find apt-get. This script only supports Debian/Ubuntu-family distros."
fi

#
#
# check if we already pulled the repository because maybe the user is running this
# script multiple times to update stuff or something
#
#
cd "$HOME"
export GIT_TERMINAL_PROMPT=0

if [[ -d "$REPO_DIR" ]]; then
    echo "Repository seems to exist; pulling latest changes..."
    if ! git -C "$REPO_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        die "${REPO_DIR} exists but is not a git repository. Move it aside or delete it and re-run."
    fi
    git -C "$REPO_DIR" fetch --prune
    git -C "$REPO_DIR" pull --ff-only
else
    echo "Cloning repository..."
    # shallow clone to save space and reduce initial network usage
    git clone --branch beta --single-branch --depth 1 https://github.com/itgmania/itgmania.git "$REPO_DIR"
fi

# enter repo
cd "$REPO_DIR"

# make it a portable build :)
touch Portable.ini

git submodule sync --recursive
git submodule update --init --recursive

# game setup
JOBS="$(cpu_jobs)"
cmake -B build -DWITH_FFMPEG_JOBS="${JOBS}"
cmake --build build --parallel "${JOBS}"

# theme check
echo "Setting up theme..."
cd Themes

shopt -s nullglob
found=0
for d in "Arrow Cloud"*; do
    if [[ -d "$d" ]]; then
        echo "Found existing theme directory: $d — skipping download."
        found=1
        break
    fi
done

if [[ "$found" -eq 0 ]]; then
    tmpdir="$(mktemp -d)"
    theme_zip="${tmpdir}/Arrow Cloud Theme.zip"
    cleanup_theme_tmp() { rm -rf "${tmpdir}"; }
    trap cleanup_theme_tmp EXIT

    wget --https-only --tries=3 --timeout=30 -q --show-progress \
        "https://assets.arrowcloud.dance/theme/Arrow%20Cloud%20Theme.zip" \
        -O "${theme_zip}"

    unzip -q "${theme_zip}" -d "${tmpdir}/theme"
    # Extracted content is theme-controlled; move into Themes as-is.
    # (If it already exists, user chose to replace by deleting beforehand.)
    cp -R "${tmpdir}/theme"/* .
fi

# go up 1 dir so itgmania/itgmania run command works as expected
cd "$HOME"


# cool art...
cat << 'EOF'

   ___  ____  _  ________
  / _ \/ __ \/ |/ / __/ /
 / // / /_/ /    / _//_/ 
/____/\____/_/|_/___(_)  
                         

ITGMANIA IS READY TO GO!!!
Arrow Cloud zmod is installed also
 (you will need to switch the theme manually
  on your first run of the game.)

To run ITGmania you can open any terminal and type

 itgmania/itgmania

and the game will start.

IMPORTANT NOTE
(Unless you are using Linux Mint, in which case this warning doesn't apply)
ITGmania does not suport Wayland yet
You may have to log in as X11 for the keyboard to work in full screen


EOF
