# Kali Phosh for PinePhone and Qcom Phones

```
-----------------------------------------
 _____     _   _____         _
|   | |___| |_|  |  |_ _ ___| |_ ___ ___
| | | | -_|  _|     | | |   |  _| -_|  _|
|_|___|___|_| |__|__|___|_|_|_| |___|_|
 _____
|  _  |___ ___
|   __|  _| . | Image Generator
|__|  |_| |___| by Shubham Vishwakarma

twitter/git: shubhamvis98
-----------------------------------------
```

A huge thanks to Mobian Project and Megi's Kernel Patches.

## Build Instruction
```
#PinePhone
./build.sh -t pinephone

#PinePhone Pro
./build.sh -t pinephonepro

#SDM845
bash set-build-polaris.sh # if you want to build mix2s(polaris)

bash set-build-polaris.sh --off # if you don't want to build mix2s(polaris) but seted

./build.sh -t sdm845 # to build knhp for sdm845 (if you seted the mix2s(polaris) it will build it if you didn't set it will not build it)
```

## Required packages:
    - systemd-container
    - rsync
    - debootstrap
    - qemu-user-static
    - bmap-tools
    - android-sdk-libsparse-utils

Download official Kali Nethunter for PinePhone and PinePhone Pro from Kali download page: https://www.kali.org/get-kali/#kali-mobile

![](https://img.shields.io/github/downloads/Shubhamvis98/kali-pinephone/total?label=Downloads&style=plastic)
