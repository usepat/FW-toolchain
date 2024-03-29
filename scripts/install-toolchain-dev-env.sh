#!/bin/bash

# Setup script to configure development environment
# Function to handle cleanup before exiting on Ctrl+C or Ctrl+Z
cleanup() {
    echo "Cleaning up before exit..."
    exit 1
}

# Trap Ctrl+C and Ctrl+Z and call the cleanup function
trap cleanup SIGINT SIGTSTP

LOG_FILE="setup-errors.log" 
# Clear the log file at the start of the script
echo "" > "$LOG_FILE"

exec 3>&1  # Preserve original stdout for always-visible messages
exec 4>&2  # Preserve original stderr for logging errors

# Redirect all errors to log file
exec 2>>"$LOG_FILE"


VERBOSE=0          # Control verbosity
FORCE_REINSTALL=0  # Control forced reinstallation

suppress_output() {
    # Suppress stdout if VERBOSE is not set to 1
    if [ "$VERBOSE" -eq 0 ]; then
        exec 1>/dev/null
    fi
    # Continue redirecting stderr to the log file
    exec 2>>"$LOG_FILE"
}

# Function to enable output for read commands or important messages
enable_output() {
    # Restore stdout and stderr to their original destinations
    exec 1>&3
    exec 2>&4
}

# Always-visible logging function
log() {
    echo "$@" >&3  # Use preserved stdout for logs
}

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
      enable_output
      usage
      exit 0
      ;;
    \? )
        enable_output
      usage
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

# Function to check command execution
check_command() {
    if [ $? -ne 0 ]; then
        echo "Setup failed during: $1 - check $LOG_FILE for details." >&3
        exit 1
    fi
}

# Define a function to check if a submodule is initialized
check_submodule_initialized() {
    local submodule_path="$1"
    git submodule status "$submodule_path" | grep -q '^ ' && return 0 || return 1
}

suppress_output 

ARM_TOOLCHAIN_PATH="/opt/arm-gnu-toolchain-13.2.Rel1-x86_64-arm-none-eabi"
PICO_SDK_PATH="/opt/pico/pico-sdk"

# Begin script execution
log "Verbose mode enabled."

log "Starting system update..."
sudo apt-get update
check_command "System update"

log "Checking for ARM toolchain 10.3.1 ..." 
sudo apt-get install gcc-arm-none-eabi -y $APT_OPTIONS
check_command "ARM toolchain 10.3.1 installation"

# Check if ARM toolchain is already installed
log "Checking for ARM toolchain 13.2.1 ..." 
if [ -x "$ARM_TOOLCHAIN_PATH/bin/arm-none-eabi-gcc" ]  && [ "$FORCE_REINSTALL" -eq 0 ]; then
    log "ARM toolchain 13.2.1 is already installed. Skipping download and extraction." 
else
    TOOLCHAIN_URL="https://developer.arm.com/-/media/Files/downloads/gnu/13.2.rel1/binrel/arm-gnu-toolchain-13.2.rel1-x86_64-arm-none-eabi.tar.xz"
    TOOLCHAIN_TAR="/opt/arm-gnu-toolchain-13.2.rel1-x86_64-arm-none-eabi.tar.xz"
    
    log "Downloading ARM toolchain 13.2.1..." 
    sudo wget -O "$TOOLCHAIN_TAR" "$TOOLCHAIN_URL"
    check_command "ARM toolchain download"

    # Check if the toolchain directory already exists and clean it up if FORCE_REINSTALL is set
    if [ -d "$ARM_TOOLCHAIN_PATH" ] && [ "$FORCE_REINSTALL" -eq 1 ]; then
        log "Removing existing ARM toolchain 13.2.1 directory..." 
        sudo rm -rf "$ARM_TOOLCHAIN_PATH"
        check_command "Existing ARM toolchain 13.2.1 directory removal"
    fi
  
    log "Extracting ARM GNU toolchain 13.2.1 ..." 
    sudo tar -xf "$TOOLCHAIN_TAR" -C /opt
    check_command "ARM toolchain extraction 13.2.1"
    
    log "Cleaning up ARM GNU toolchain 13.2.1 tarball..." 
    sudo rm "$TOOLCHAIN_TAR"
    check_command "ARM toolchain 13.2.1 cleanup"

    # Add PICO_TOOLCHAIN_PATH to ~/.bashrc if it's not already added
    grep -qxF "export PICO_TOOLCHAIN_PATH="$ARM_TOOLCHAIN_PATH"/bin" ~/.bashrc || echo "export PICO_TOOLCHAIN_PATH="$ARM_TOOLCHAIN_PATH"/bin" >> ~/.bashrc
    grep -qxF 'export PATH="$PATH:$PICO_TOOLCHAIN_PATH"' ~/.bashrc || echo 'export PATH="$PATH:$PICO_TOOLCHAIN_PATH"' >> ~/.bashrc
    check_command "PICO toolchain PATH update"
fi

# Installation of Git
sudo apt-get install git -y $APT_OPTIONS
check_command "Git installation"

# Check if Pico SDK is already installed
log "Checking for Pico SDK..." 
if [ -d "$PICO_SDK_PATH" ] && check_submodule_initialized "$PICO_SDK_PATH/lib/tinyusb" && [ "$FORCE_REINSTALL" -eq 0 ]; then
    log "Pico SDK and required submodules are already installed and initialized. Skipping installation." 
else
    log "Installing the Pico SDK..." 
    sudo mkdir -p /opt/pico
    if [ ! -d "$PICO_SDK_PATH/.git" ]; then
        sudo git clone https://github.com/raspberrypi/pico-sdk.git --branch master "$PICO_SDK_PATH"
        check_command "Pico SDK clone"
    else
        log "Pico SDK repository already exists. Pulling latest changes..." 
        cd "$PICO_SDK_PATH" || exit
        sudo git pull origin master
        check_command "Pico SDK pull"
    fi

    cd "$PICO_SDK_PATH" || exit
    git config --global --add safe.directory "$PICO_SDK_PATH"
    if [ ! -f "$PICO_SDK_PATH/lib/tinyusb/README.md" ]; then
        sudo git submodule update --init
        check_command "Pico SDK submodules initialization"
    fi

    # Add PICO_SDK_PATH to ~/.bashrc if it's not already added
    grep -qxF "export PICO_SDK_PATH="$PICO_SDK_PATH"" ~/.bashrc || echo "export PICO_SDK_PATH="$PICO_SDK_PATH"" >> ~/.bashrc
    check_command "PICO_SDK_PATH update"
fi

# Additional development tools installation
log "Installing additional development tools..." 
sudo apt-get install doxygen graphviz mscgen dia curl cmake xclip -y $APT_OPTIONS
check_command "Development tools installation"

# Node.js installation or check
if node --version &> /dev/null && [ "$FORCE_REINSTALL" -eq 0 ]; then
    log "Node.js is already installed. Skipping installation." 
else
    log "Installing Node.js..." 
    curl -fsSL https://deb.nodesource.com/setup_current.x | sudo -E bash -
    sudo apt-get install -y nodejs $APT_OPTIONS
    check_command "Node.js installation"
fi

# Visual Studio Code installation or check
if which code > /dev/null && [ "$FORCE_REINSTALL" -eq 0 ]; then
    log "Visual Studio Code is already installed. Skipping installation." 
else
    log "Installing or reinstalling Visual Studio Code..." 
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
    rm -f packages.microsoft.gpg
    sudo apt update
    sudo apt install code -y $APT_OPTIONS
    check_command "Visual Studio Code installation"
fi

# Installation of VS Code extensions
log "Installing extensions for Visual Studio Code..." 
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
    sudo code --install-extension $ext &>>"$LOG_FILE" || {
        log "Failed to install extension $ext - check $LOG_FILE for details." 
    }
done
log "VS Code extensions installed." 

# Configure VS Code settings
log 'Configuring Visual Studio Code settings...' 
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

log "Toolchain and environment setup completed successfully." 
enable_output
read -p "Do you wish to proceed with Git SSH key setup? (yes/no): " proceed_git_setup 

if [[ "$proceed_git_setup" == "yes" ]]; then
    # Git SSH key setup begins
    log "Starting Git SSH key setup..." 

    # Prompt for Git username and email
    read -p "Enter your Git username: " git_username 
    read -p "Enter your Git email: " git_email 

    # Configure Git with the provided username and email
    git config --global user.name "$git_username"
    git config --global user.email "$git_email"
    check_command "git config username and email"

    # Generate an SSH key for the provided email, with passphrase prompt
    log -e "\nYou can set an optional passphrase for your SSH key for added security..." 
    while true; do
        read -s -p "Enter passphrase (or leave empty for no passphrase): " passphrase 
        log 
        read -s -p "Repeat passphrase: " passphrase_repeat 
        log 

        if [[ "$passphrase" == "$passphrase_repeat" ]]; then
            break
        else
            log "Passphrases do not match. Please try again." 
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
    log "SSH public key copied to clipboard. Please add it to your GitHub account." 

    log -e "\nVisit https://github.com/settings/keys to add your SSH key." 
    while true; do
        read -p "Type 'done' once you have added your SSH key to GitHub: " user_input 
        if [[ "$user_input" == "done" ]]; then
            break
        else
            log "Please type 'done' after you have added your SSH key to GitHub." 
        fi
    done

    ssh_out=$(ssh -T git@github.com 2>&1)
    if [[ $ssh_out == *"successfully authenticated"* ]]; then
        log "SSH connection to GitHub verified successfully!" 
    else
        log "SSH connection to GitHub failed. Check $LOG_FILE for details." 
        log "Received response: $ssh_out" 
    fi
else
    log "Skipping Git SSH key setup." 
fi
log "Setup git successfully." 

read -p "Do you wish to clone the 'sonic-firmware' repository? (yes/no): " clone_repo_decision 

if [[ "$clone_repo_decision" == "yes" ]]; then
    # Ask for the directory to clone into
    read -p "Enter the full path where you want to clone 'sonic-firmware': " clone_path 
    mkdir -p "$clone_path" && cd "$clone_path"
    check_command "mkdir and cd into $clone_path"

    suppress_output 
    
    # Clone the repository
    log "Cloning 'sonic-firmware' into $clone_path..." 
    git clone git@github.com:usepat/sonic-firmware.git
    check_command "git clone sonic-firmware"

    # Change directory into the cloned repository
    cd sonic-firmware
    check_command "cd sonic-firmware"

    # Checkout the development branch and update submodules
    log "Checking out the 'development' branch..." 
    git checkout development
    check_command "git checkout development"

    log "Updating submodules..." 
    git pull
    check_command "git pull"

    git submodule update --init --recursive --remote
    check_command "git submodule update"
    
    log "Repository 'sonic-firmware' is ready for use." 
else
    log "Skipping repository cloning." 
fi
log "Setup completed successfully. Run 'source ~/.bashrc' to apply the changes, or restart your machine." 
