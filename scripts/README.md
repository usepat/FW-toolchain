# Run the install-toolchain-dev-env

This script will install all tools needed for building the sonic-firmware repo for both pico and linux build options. It will also install vscode and several usefull extensions as well as importing settings for vscode.
Furthermore it helps with setting up SSH keys for GitHub and cloning the sonic-firmware repo.<br>


Download the script and run it without sudo<br>
Use option -v to get verbose output, use option -f to force reinstall<br>
If the scripts fails, the output will be written into setup-error.log

```bash
wget "https://raw.githubusercontent.com/usepat/toolchain/main/scripts/install-toolchain-dev-env.sh" -O setup-script.sh
bash setup-script.sh
```
After the scripts has run succesfully run:
```bash
source ~/.bashrc
```
