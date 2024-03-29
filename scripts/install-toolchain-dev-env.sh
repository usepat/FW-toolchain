#!/bin/bash

# Setup script to configure development environment

LOG_FILE="setup-errors.log"
exec 3>&1          # Preserve stdout in file descriptor 3
VERBOSE=0          # Control verbosity
FORCE_REINSTALL=0  # Control forced reinstallation

# Function to display usage and exit
usage() {
  echo "Usage: $0 [options]" >&2
  echo "Options:" >&2
  echo "  -v  Enable verbose mode" >&2
  echo "  -f  Force reinstall all apt-get packages" >&2
  echo "  -h  Display this help message and exit" >&2
  exit 1
}

# Parse options
while getopts ":vf" opt; do
  case ${opt} in
    v )
      VERBOSE=1
      ;;
    f )
      FORCE_REINSTALL=1
      APT_OPTIONS="--reinstall"  # Set to reinstall packages with apt-get
      ;;
    h )  # Handle help option
      usage
      exit 0
      ;;
    \? )
      usage
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

exec 2>>$LOG_FILE  # Redirect stderr to log file

if [ "$VERBOSE" -eq 0 ]; then
  exec 1>/dev/null  # Suppress stdout if not in verbose mode
fi

# Function to check command execution
check_command() {
    if [ $? -ne 0 ]; then
        echo "Setup failed during: $1 - check $LOG_FILE for details." >&3
        exit 1
    fi
}

# Function to control output based on the VERBOSE option
log() {
  if [ "$VERBOSE" -eq 1 ]; then
    echo "$@" >&3  # Only output to terminal if verbose mode is enabled
  fi
}

ARM_TOOLCHAIN_PATH="/opt/arm-gnu-toolchain-13.2.rel1-x86_64-arm-none-eabi"
PICO_SDK_PATH="/opt/pico/pico-sdk"

# Begin script execution
log "Verbose mode enabled."

echo "Starting system update..." >&3
sudo apt-get update
check_command "System update"

echo "Checking for ARM toolchain..." >&3
sudo apt-get install gcc-arm-none-eabi -y $APT_OPTIONS
check_command "ARM toolchain installation"

# Download and install ARM toolchain if not already installed or if FORCE_REINSTALL is enabled
if [ ! -d "$ARM_TOOLCHAIN_PATH/bin" ] || [ "$FORCE_REINSTALL" -eq 1 ]; then
    echo "Downloading ARM toolchain 13.2.1..." >&3
    wget -P /opt https://developer.arm.com/-/media/Files/downloads/gnu/13.2.rel1/binrel/arm-gnu-toolchain-13.2.rel1-x86_64-arm-none-eabi.tar.xz
    check_command "ARM toolchain download"
  
    echo "Extracting ARM GNU toolchain..." >&3
    sudo tar -xf /opt/arm-gnu-toolchain-13.2.rel1-x86_64-arm-none-eabi.tar.xz -C /opt
    check_command "ARM toolchain extraction"
    
    echo "Cleaning up ARM GNU toolchain tarball..." >&3
    sudo rm /opt/arm-gnu-toolchain-13.2.rel1-x86_64-arm-none-eabi.tar.xz
    check_command "ARM toolchain cleanup"

    # Add PICO_TOOLCHAIN_PATH to ~/.bashrc
    echo 'export PICO_TOOLCHAIN_PATH="/opt/arm-gnu-toolchain-13.2.Rel1-x86_64-arm-none-eabi/bin"' >> ~/.bashrc
    echo 'export PATH="$PATH:$PICO_TOOLCHAIN_PATH"' >> ~/.bashrc
    check_command "PICO toolchain PATH update"
fi

# Installation of Git
sudo apt-get install git -y $APT_OPTIONS
check_command "Git installation"

# Pico SDK Installation
echo "Checking for Pico SDK..." >&3
if [ ! -d "$PICO_SDK_PATH" ] || [ "$FORCE_REINSTALL" -eq 1 ]; then
    echo "Installing the Pico SDK..." >&3
    sudo mkdir -p /opt/pico
    sudo git clone https://github.com/raspberrypi/pico-sdk.git --branch master "$PICO_SDK_PATH"
    check_command "Pico SDK clone"

    cd "$PICO_SDK_PATH" || exit
    git config --global --add safe.directory "$PICO_SDK_PATH"
    git submodule update --init
    check_command "Pico SDK submodules initialization"
    # Add PICO_SDK_PATH to ~/.bashrc
    echo 'export PICO_SDK_PATH="/opt/pico/pico-sdk"' >> ~/.bashrc
    check_command "PICO_SDK_PATH update"
fi

# Additional development tools installation
echo "Installing additional development tools..." >&3
sudo apt-get install doxygen graphviz mscgen dia curl cmake xclip -y $APT_OPTIONS
check_command "Development tools installation"

# Node.js installation or check
if node --version &> /dev/null && [ "$FORCE_REINSTALL" -eq 0 ]; then
    echo "Node.js is already installed. Skipping installation." >&3
else
    echo "Installing Node.js..." >&3
    curl -fsSL https://deb.nodesource.com/setup_current.x | sudo -E bash -
    sudo apt-get install -y nodejs $APT_OPTIONS
    check_command "Node.js installation"
fi

# Visual Studio Code installation or check
if which code > /dev/null && [ "$FORCE_REINSTALL" -eq 0 ]; then
    echo "Visual Studio Code is already installed. Skipping installation." >&3
else
    echo "Installing or reinstalling Visual Studio Code..." >&3
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
    rm -f packages.microsoft.gpg
    sudo apt update
    sudo apt install code -y $APT_OPTIONS
    check_command "Visual Studio Code installation"
fi

# Installation of VS Code extensions
echo "Installing extensions for Visual Studio Code..." >&3
EXTENSIONS=(
  cschlosser.doxdocgen
  gruntfuggly.todo-tree
  jebbs.plantuml
  jeff-hykin.better-cpp-syntax
  marus25.cortex-debug
  matepek.vscode-catch2-test-adapter
  mcu-debug.debug-tracker-vscode
  mcu-debug.memory-view
  mcu-debug.peripheral-viewer
  mcu-debug.rtos-views
  ms-vscode.cmake-tools
  ms-vscode.cpptools
  ms-vscode.cpptools-extension-pack
  ms-vscode.cpptools-themes
  ms-vscode.makefile-tools
  ms-vscode.test-adapter-converter
  ms-vscode.vscode-serial-monitor
  sonarsource.sonarlint-vscode
  twxs.cmake
)
for ext in "${EXTENSIONS[@]}"; do
    if [ "$FORCE_REINSTALL" -eq 1 ]; then
        code --uninstall-extension $ext &>/dev/null
    fi
    code --install-extension $ext &>>$LOG_FILE || {
        echo "Failed to install extension $ext - check $LOG_FILE for details." >&3
    }
done
echo "VS Code extensions installed." >&3

# Configure VS Code settings
echo 'Configuring Visual Studio Code settings...' >&3
echo '{
  "cortex-debug.openocdPath": "${env:PICO_SDK_PATH}/../openocd/src/openocd",
  "cmake.configureOnOpen": true,
  "window.zoomLevel": 1,
  "cpputestTestAdapter.logpanel": true,
  "cpputestTestAdapter.testExecutable": "${workspaceFolder}/test/",
  "cpputestTestAdapter.testExecutablePath": "${workspaceFolder}/test",
  "explorer.confirmDragAndDrop": false,
  "sonarlint.rules": {
      "cpp:S5820": {
          "level": "off"
      }
  },
  "git.openRepositoryInParentFolders": "never",
  "C_Cpp.default.compilerPath": "",
  "cmake.options.statusBarVisibility": "visible",
  "cmake.showOptionsMovedNotification": false,
  "git.autofetch": true
}' > ~/.config/Code/User/settings.json
check_command "VS Code settings configuration"

echo "Toolchain and environment setup completed successfully." >&3

read -p "Do you wish to proceed with Git SSH key setup? (yes/no): " proceed_git_setup

if [[ "$proceed_git_setup" == "yes" ]]; then
    # Git SSH key setup begins
    echo "Starting Git SSH key setup..." >&3

    # Prompt for Git username and email
    read -p "Enter your Git username: " git_username
    read -p "Enter your Git email: " git_email

    # Configure Git with the provided username and email
    git config --global user.name "$git_username"
    git config --global user.email "$git_email"
    check_command "git config username and email"

    # Generate an SSH key for the provided email, with passphrase prompt
    echo -e "\nYou can set an optional passphrase for your SSH key for added security..." >&3
    while true; do
        read -s -p "Enter passphrase (or leave empty for no passphrase): " passphrase
        echo >&3
        read -s -p "Repeat passphrase: " passphrase_repeat
        echo >&3

        if [[ "$passphrase" == "$passphrase_repeat" ]]; then
            break
        else
            echo "Passphrases do not match. Please try again." >&3
        fi
    done
    
    read -p "Do you want to specify a custom name for the SSH key? (yes/no): " custom_key_name_decision
    if [[ "$custom_key_name_decision" == "yes" ]]; then
        read -p "Enter the custom name for your SSH key (e.g., github_ed25519): " ssh_key_name
        ssh_key_path="$HOME/.ssh/${ssh_key_name}"
    else
        ssh_key_name="id_ed25519"
        ssh_key_path="$HOME/.ssh/id_ed25519"
    fi
    
    ssh-keygen -t ed25519 -C "$git_email" -f "$ssh_key_path" -N "$passphrase"
    check_command "ssh-keygen"

    eval "$(ssh-agent -s)"
    ssh-add "$ssh_key_path"
    check_command "ssh-add"

    xclip -selection clipboard < "${ssh_key_path}.pub"
    echo "SSH public key copied to clipboard. Please add it to your GitHub account." >&3

    echo -e "\nVisit https://github.com/settings/keys to add your SSH key." >&3
    read -p "Press enter once you have added your SSH key to GitHub."

    ssh_out=$(ssh -T git@github.com 2>&1)
    if [[ $ssh_out == *"successfully authenticated"* ]]; then
        echo "SSH connection to GitHub verified successfully!" >&3
    else
        echo "SSH connection to GitHub failed. Check $LOG_FILE for details." >&3
        echo "Received response: $ssh_out" >&3
    fi
else
    echo "Skipping Git SSH key setup." >&3
fi
echo "Setup git successfully." >&3

read -p "Do you wish to clone the 'sonic-firmware' repository? (yes/no): " clone_repo_decision >&3

if [[ "$clone_repo_decision" == "yes" ]]; then
    # Ask for the directory to clone into
    read -p "Enter the full path where you want to clone 'sonic-firmware': " clone_path >&3
    mkdir -p "$clone_path" && cd "$clone_path"
    check_command "mkdir and cd into $clone_path"
    
    # Clone the repository
    echo "Cloning 'sonic-firmware' into $clone_path..." >&3
    git clone git@github.com:usepat/sonic-firmware.git
    check_command "git clone sonic-firmware"

    # Change directory into the cloned repository
    cd sonic-firmware
    check_command "cd sonic-firmware"

    # Checkout the development branch and update submodules
    echo "Checking out the 'development' branch..." >&3
    git checkout development
    check_command "git checkout development"

    echo "Updating submodules..." >&3
    git pull
    check_command "git pull"

    git submodule update --init --recursive --remote
    check_command "git submodule update"
    
    echo "Repository 'sonic-firmware' is ready for use." >&3
else
    echo "Skipping repository cloning." >&3
fi
echo "Setup completed successfully." >&3
