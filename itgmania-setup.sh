#!/bin/sh

set -e

REPO_DIR="$HOME/itgmania"

echo "Howdy partner :] Just gonna get itgmania set up over here :]"

#
#
# thee zone of linux determination
#
#
if command -v apt >/dev/null 2>&1; then
    echo "Found apt :D"
    
    sudo apt update
    sudo apt upgrade -y
    sudo apt install -y build-essential
    sudo apt install -y git cmake libasound2-dev libgl-dev libglu1-mesa-dev libgtk-3-dev libjack-dev libmad0-dev libpulse-dev libudev-dev libxinerama-dev libx11-dev libxrandr-dev libxtst-dev nasm unzip
    
    echo "Packages installed successfully via apt!"

elif command -v pacman >/dev/null 2>&1; then
    echo "Found pacman :D"
    sudo pacman -Syu --noconfirm
    sudo pacman -Sy --needed --noconfirm git base-devel alsa-lib cmake freetype2 gcc glu gtk3 glfw jack libmad libpulse libusb libx11 libxaw libxinerama libxrandr libxtst mesa nasm zziplib    
    
    echo "Packages installed successfully via pacman"

else
    echo "ERROR: Couldn't find either apt or pacman!"
    echo "This script currently only supports Debian/Ubuntu and Arch-based distributions, such as Linux Mint, Ubuntu, Pop_OS, EndeavourOS, among others"
    
    exit 1
fi

#
#
# check if we already pulled the repository because maybe the user is running this
# script multiple times to update stuff or something
#
#
cd "$HOME"
if [ -d "$REPO_DIR" ]; then
    echo "Repository seem to exist. pulling latest changes..."
    cd "$REPO_DIR"
    git fetch
    git pull
    cd ..
else
    echo "Cloning repository..."
    # shallow clone to save space and avoid any submodule version weirdness
    # when submodules differ between release and beta it can be a nightmare
    git clone --branch beta --single-branch --depth 1 https://github.com/itgmania/itgmania.git
fi

#
# thee zone of itgman building
# make sure to build the latest beta
# but first make sure we are up to date ^_^
#
cd "$REPO_DIR"
# make it a portable build :)
touch Portable.ini

# $800 BOOM
git submodule update --init --recursive
git submodule sync

# game setup
cmake -B build -DWITH_FFMPEG_JOBS="$(nproc)"
cmake --build build --parallel "$(nproc)"

# theme check
echo "Setting up theme..."
cd Themes
found=0
for d in Arrow\ Cloud*; do
    if [ -d "$d" ]; then
        echo "Found existing theme directory: $d — skipping download."
        found=1
        break
    fi
done

if [ "$found" -eq 0 ]; then
    wget -q --show-progress "https://assets.arrowcloud.dance/theme/Arrow%20Cloud%20Theme.zip" -O "Arrow Cloud Theme.zip"
    unzip -q "Arrow Cloud Theme.zip"
    rm -f "Arrow Cloud Theme.zip"
fi

# go up 1 dir so itgmania/itgmania run command works as expected
cd ..


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
