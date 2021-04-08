# Automated kernel builder

originaly from (https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-kernel)

I have always pressed the same 2 key for building and (waiting ~20min) to create an anykernel zip. so to get ride of this two key pressed i move all the scripts part into my version of build.sh + little tricks and cool stuff, enjoy :)

## HOWTO

git clone this repo to the kernel folder, then :
```bash
cd kernel_builder
bash build.sh
Usage : build.sh -c <config_file_name> [-e]
    -h : show this help
    -c : config file name to compile/edit
    -e : edit the config before compiling
    -o : output of the anykernel zip (only accept absolute path)
    -u : update repo
```

Edited config file saved in `kernel_builder/saved/`
## TESTED KERNEL
[kimocoder](https://github.com/kimocoder) :

- [android_kernel_oneplus_oneplus6](https://github.com/kimocoder/android_kernel_oneplus_oneplus6)

[johanlike](https://github.com/johanlike) :

- [DJY-Nethunter-Andrax-Kernel-Source](https://github.com/johanlike/DJY-Nethunter-Andrax-Kernel-Source)

[acai66](https://github.com/acai66) :

- [op6-op6t-nethunter-kernel](https://github.com/acai66/op6-op6t-nethunter-kernel)

## TODO
- rework update
  - -u functioning
  - fix when new update in other branch
- handle error
- add multiple-toolchains

