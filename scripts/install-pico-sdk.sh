
echo "Cloning Pico SDK repository"
cd /opt
mkdir pico
cd pico
git clone -b master https://github.com/raspberrypi/pico-sdk.git

echo "Initialising submodules"
cd pico-sdk
git submodule update --init
cd ../../

echo "Set PICO_SDK_PATH to /opt/pico/pico-sdk"
export PICO_SDK_PATH=/opt/pico/pico-sdk