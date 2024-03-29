#!/bin/bash

# Setup script to configure development environment

# Log file for storing error messages
LOG_FILE="setup-errors.log"

# Redirect all stderr to log file
exec 2>>$LOG_FILE

# Exit script on error
set -e

# Function to check command execution
check_command() {
    if [ $? -ne 0 ]; then
        echo "Setup failed at command: $1 - check $LOG_FILE for details."
        exit 1
    fi
}

echo "Starting system update..."
sudo apt-get update
check_command "sudo apt-get update"

echo "Installing ARM toolchain..."
sudo apt-get install gcc-arm-none-eabi -y
check_command "sudo apt-get install gcc-arm-none-eabi"

echo "Downloading ARM GNU toolchain..."
sudo wget -P /opt https://developer.arm.com/-/media/Files/downloads/gnu/13.2.rel1/binrel/arm-gnu-toolchain-13.2.rel1-x86_64-arm-none-eabi.tar.xz
check_command "sudo wget -P /opt ARM GNU toolchain"

echo "Extracting ARM GNU toolchain..."
sudo tar -xf /opt/arm-gnu-toolchain-13.2.rel1-x86_64-arm-none-eabi.tar.xz -C /opt
check_command "sudo tar -xf /opt/arm-gnu-toolchain"

echo "Cleaning up ARM GNU toolchain tarball..."
sudo rm /opt/arm-gnu-toolchain-13.2.rel1-x86_64-arm-none-eabi.tar.xz
check_command "sudo rm /opt/arm-gnu-toolchain tarball"

echo "Installing the Pico SDK..."
sudo mkdir -p /opt/pico
sudo git clone https://github.com/raspberrypi/pico-sdk.git --branch master /opt/pico/pico-sdk
check_command "sudo git clone pico-sdk"
cd /opt/pico/pico-sdk || exit
git config --global --add safe.directory /opt/pico/pico-sdk
git submodule update --init
check_command "git submodule update --init"

echo "Adding the SDK and toolchain to PATH..."
echo 'export PICO_SDK_PATH="/opt/pico/pico-sdk"' >> ~/.bashrc
echo 'export PICO_TOOLCHAIN_PATH="/opt/arm-gnu-toolchain-13.2.Rel1-x86_64-arm-none-eabi/bin"' >> ~/.bashrc
echo 'export PATH="$PATH:$PICO_TOOLCHAIN_PATH"' >> ~/.bashrc
source ~/.bashrc
check_command "Updating PATH in .bashrc"

echo "Installing additional development tools..."
sudo apt-get install doxygen graphviz mscgen dia curl cmake xclip -y
check_command "sudo apt-get install development tools"

echo "Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_current.x | sudo -E bash -
sudo apt-get install -y nodejs
check_command "sudo apt-get install nodejs"

echo "Setting up Visual Studio Code..."
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
rm -f packages.microsoft.gpg
sudo apt update
sudo apt install code -y
check_command "sudo apt install code"

echo "Installing extensions for Visual Studio Code..."
for ext in cschlosser.doxdocgen gruntfuggly.todo-tree jebbs.plantuml jeff-hykin.better-cpp-syntax marus25.cortex-debug matepek.vscode-catch2-test-adapter mcu-debug.debug-tracker-vscode mcu-debug.memory-view mcu-debug.peripheral-viewer mcu-debug.rtos-views ms-vscode.cmake-tools ms-vscode.cpptools ms-vscode.cpptools-extension-pack ms-vscode.cpptools-themes ms-vscode.makefile-tools ms-vscode.test-adapter-converter ms-vscode.vscode-serial-monitor sonarsource.sonarlint-vscode twxs.cmake; do
    code --install-extension $ext || { echo "Failed to install extension $ext - check $LOG_FILE for details."; exit 1; }
done

echo "Toolchain installed successfully."

read -p "Do you wish to proceed with Git SSH key setup? (yes/no): " proceed_git_setup

if [[ "$proceed_git_setup" == "yes" ]]; then
    # Git SSH key setup begins
    echo "Starting Git SSH key setup..."

    # Prompt for Git username and email
    read -p "Enter your Git username: " git_username
    read -p "Enter your Git email: " git_email

    # Configure Git with the provided username and email
    git config --global user.name "$git_username"
    git config --global user.email "$git_email"
    check_command "git config username and email"

    # Generate an SSH key for the provided email, with passphrase prompt
    echo -e "\nYou can set an optional passphrase for your SSH key for added security..."
    while true; do
        read -s -p "Enter passphrase (or leave empty for no passphrase): " passphrase
        echo
        read -s -p "Repeat passphrase: " passphrase_repeat
        echo

        if [[ "$passphrase" == "$passphrase_repeat" ]]; then
            break
        else
            echo "Passphrases do not match. Please try again."
        fi
    done
    
    read -p "Do you want to specify a custom name for the SSH key? (yes/no): " custom_key_name_decision
    if [[ "$custom_key_name_decision" == "yes" ]]; then
        read -p "Enter the custom name for your SSH key (e.g., github_ed25519): " ssh_key_name
        ssh_key_path="~/.ssh/${ssh_key_name}"
    else
        ssh_key_name="id_ed25519"
        ssh_key_path="~/.ssh/id_ed25519"
    fi
    
    ssh-keygen -t ed25519 -C "$git_email" -f "$ssh_key_path" -N "$passphrase"
    check_command "ssh-keygen"

    eval "$(ssh-agent -s)"
    ssh-add "$ssh_key_path"
    check_command "ssh-add"

    xclip -selection clipboard < "${ssh_key_path}.pub"
    echo "SSH public key copied to clipboard. Please add it to your GitHub account."

    echo -e "\nVisit https://github.com/settings/keys to add your SSH key."
    read -p "Press enter once you have added your SSH key to GitHub."

    ssh_out=$(ssh -T git@github.com 2>&1)
    if [[ $ssh_out == *"successfully authenticated"* ]]; then
        echo "SSH connection to GitHub verified successfully!"
    else
        echo "SSH connection to GitHub failed. Check $LOG_FILE for details."
        echo "Received response: $ssh_out"
    fi
else
    echo "Skipping Git SSH key setup."
fi

echo "Setup completed successfully."
