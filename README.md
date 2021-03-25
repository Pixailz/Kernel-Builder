# Automated kernel builder

originaly from (https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-kernel)

I have always pressed the same 2 key for building and creating an anykernel zip in this script. so to get ride of this two key pressed (waiting ~20min for just creating an anykernel zip) i move all the scripts part into my build.sh + little tricks and cool stuff, enjoy :)

## HOWTO

git clone this repo to the kernel folder
cd on it and do `bash build.sh`

## TESTED KERNEL
[kimocoder](https://github.com/kimocoder) :

- [android_kernel_oneplus_oneplus6](https://github.com/kimocoder/android_kernel_oneplus_oneplus6)

[johanlike](https://github.com/johanlike) :

- [DJY-Nethunter-Andrax-Kernel-Source](https://github.com/johanlike/DJY-Nethunter-Andrax-Kernel-Source)

## TODO
- improve banner
  - add the kernel builder (like: kimo or johan)
- fix make_clog()
