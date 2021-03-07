#!/sbin/sh
# Move safe apps from system to data partition to free up space for installation

tmp=$(readlink -f "$0")
tmp=${tmp%/*/*}
. "$tmp/env.sh"


console=$(cat /tmp/console)
[ "$console" ] || console=/proc/$$/fd/1

print() {
	echo "ui_print - $1" > $console
	echo
}

get_bb() {
    cd $tmp/tools
    BB_latest=`(ls -v busybox_nh-* 2>/dev/null || ls busybox_nh-*) | tail -n 1`
    BB=$tmp/tools/$BB_latest #Use NetHunter Busybox from tools
    chmod 755 $BB #make busybox executable
    echo $BB
    cd - >/dev/null
}

# Free space we require on /system (in Megabytes)
SpaceRequired=50
SYSTEM="/system"

MoveableApps="
QuickOffice
CloudPrint2
YouTube
PlusOne
PlayGames
Drive
Music2
Maps
Magazines
Newsstand
Currents
Photos
Books
Street
Hangouts
KoreanIME
GoogleHindiIME
GooglePinyinIME
iWnnIME
Keep
FaceLock
Wallet
HoloSpiralWallpaper
BasicDreams
PhaseBeam
LiveWallpapersPicker
"

IFS="
"
MNT=/system
SA=$MNT/app
DA=/data/app
AndroidV=$(grep 'ro.build.version.release' ${SYSTEM}/build.prop | cut -d'=' -f2)
#twrp df from /sbin doesn't has -m flag so we use busybox instead and use df from it
BB=$(get_bb)
FreeSpace=$($BB df -m $MNT | tail -n 1 | tr -s ' ' | cut -d' ' -f4)
case $AndroidV in 
       4) android_ver="kitkat";;
       5) android_ver="lolipop";;
       6) android_ver="marshmallow";;
       7) android_ver="nougat";;
       8) android_ver="oreo";;
       9) android_ver="pie";;
      10) android_ver="Q";;
      11) android_ver="R";;
esac

if [ -z $FreeSpace ]; then
	print "Warning: Could not get free space status, continuing anyway!"
	exit 0
else 
print "Free space (before): $FreeSpace MB"
fi

if [ "$FreeSpace" -gt "$SpaceRequired" ]; then
	exit 0
else 
if [ "$AndroidV" -gt "7" ];then 
print "Android Version: $android_ver"
print "Starting from Oreo,we can't move apps from /system to /data, continuing anyway!"
exit 0
else
for app in $MoveableApps; do
	if [ "$FreeSpace" -gt "$SpaceRequired" ]; then
		break
	fi
	if [ -d "$SA/$app/" ]; then
		if [ -d "$DA/$app/" ] || [ -f "$DA/$app.apk" ]; then
			print "Removing $SA/$app/ (extra)"
			rm -rf "$SA/$app/"
		else
			print "Moving $app/ to $DA"
			mv "$SA/$app/" "$DA/"
		fi
	fi
	if [ -f "$SA/$app.apk" ]; then
		if [ -d "$DA/$app/" ] || [ -f "$DA/$app.apk" ]; then
			print "Removing $SA/$app.apk (extra)"
			rm -f "$SA/$app.apk"
		else
			print "Moving $app.apk to $DA"
			mv "$SA/$app.apk" "$DA/"
		fi
	fi
done

print "Free space (after): $FreeSpace MB"

if [ ! "$FreeSpace" -gt "$SpaceRequired" ]; then
	print "Unable to free up $SpaceRequired MB of space on '$MNT'!"
	exit 1
fi

exit 0
fi
fi
