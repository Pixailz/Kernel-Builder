# Automated kernel builder

originaly from (https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-kernel)

I have always pressed the same 2 key for building and (waiting ~20min) to create an anykernel zip. so to get ride of this two key pressed i move all the scripts part into my version of build.sh + little tricks and cool stuff, enjoy :)

## HOWTO

git clone this repo to the kernel folder
cd on it and do `bash build.sh <config_file_name>`

Edited config file saved in `kernel_builder/saved/`
## TESTED KERNEL
[kimocoder](https://github.com/kimocoder) :

- [android_kernel_oneplus_oneplus6](https://github.com/kimocoder/android_kernel_oneplus_oneplus6)

[johanlike](https://github.com/johanlike) :

- [DJY-Nethunter-Andrax-Kernel-Source](https://github.com/johanlike/DJY-Nethunter-Andrax-Kernel-Source)

[acai66](https://github.com/acai66) :

- [op6-op6t-nethunter-kernel](https://github.com/acai66/op6-op6t-nethunter-kernel)

## TODO
- add a saved folder, to keep the config in safe place
