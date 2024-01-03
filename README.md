# toolchain

this toolchain contains two scripts to download and setup the pico sdk and the arm-gnu-toolchain.
This repository is also a github action, that is used to install this on the github CI.

The toolchain will set two enviroment variables:
 - PICO_SDK_PATH: will be set to /opt/pico/pico-sdk
 - ARM_GNU_TOOLCHAIN_PATH: will be set to the /opt/$arm_gnu_toolchain/bin folder 

The github action and the install-arm-gnu-toolchain file also take a param that sets the version of the arm-gnu-toolchain
