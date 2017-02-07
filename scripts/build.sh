#!/bin/bash

usage()
{
    echo -e ""
    echo -e ${txtbld}"Usage:"${txtrst}
    echo -e "  build.sh [options] device"
    echo -e ""
    echo -e ${txtbld}"  Options:"${txtrst}
    echo -e "    -c# Cleanin options before build:"
    echo -e "        1 - make clean"
    echo -e "        2 - make dirty"
    echo -e "        10 - make official"
    echo -e "    -d  Use dex optimizations"
    echo -e "    -i  Static Initlogo"
    echo -e "    -j# Set jobs"
    echo -e "    -s  Sync before build"
    echo -e "    -p  Build using pipe"
    echo -e "    -a  Enable strict aliasing"
    echo -e "    -o# Select GCC O Level"
    echo -e "        Valid O Levels are"
    echo -e "        1 (Os) or 3 (O3)"
    echo -e "    -z  sign zip with release keys"
    echo -e ""
    echo -e ${txtbld}"  Example:"${txtrst}
    echo -e "    ./build.sh -p -o3 -j18 hammerhead"
    echo -e ""
    exit 1
}


if [ ! -d ".repo" ]; then
    echo -e ${red}"No .repo directory found.  Is this an Android build tree?"${txtrst}
    exit 1
fi


# figure out the output directories
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
thisDIR="${PWD##*/}"

findOUT() {
if [ -n "${OUT_DIR_COMMON_BASE+x}" ]; then
return 1; else
return 0
fi;}

findOUT
RES="$?"

if [ $RES = 1 ];then
    export OUTDIR=$OUT_DIR_COMMON_BASE/$thisDIR
    echo -e ""
    echo -e ${bldgrn}"External out DIR is set ($OUTDIR)"${txtrst}
    echo -e ""
elif [ $RES = 0 ];then
    export OUTDIR=$DIR/out
    echo -e ""
    echo -e ${bldgrn}"No external out, using default ($OUTDIR)"${txtrst}
    echo -e ""
else
    echo -e ""
    echo -e ${red}"NULL"${txtrst}
    echo -e ${red}"Error wrong results"${txtrst}
    echo -e ""
fi

# get OS (linux / Mac OS x)
IS_DARWIN=$(uname -a | grep Darwin)
if [ -n "$IS_DARWIN" ]; then
    CPUS=$(sysctl hw.ncpu | awk '{print $2}')
    DATE=gdate
else
    CPUS=$(grep "^processor" /proc/cpuinfo | wc -l)
    DATE=date
fi

export USE_CCACHE=1

opt_clean=0
opt_dex=0
opt_initlogo=0
opt_jobs="$CPUS"
opt_log=0
opt_sync=0
opt_pipe=0
opt_strict=0
opt_olvl=0
opt_verbose=0

while getopts "c:dij:spao:z" opt; do
    case "$opt" in
    c) opt_clean="$OPTARG" ;;
    d) opt_dex=1 ;;
    i) opt_initlogo=1 ;;
    j) opt_jobs="$OPTARG" ;;
    s) opt_sync=1 ;;
    p) opt_pipe=1 ;;
    a) opt_strict=1 ;;
    o) opt_olvl="$OPTARG" ;;
    z) opt_log=1 ;;
    *) usage
    esac
done
shift $((OPTIND-1))
if [ "$#" -ne 1 ]; then
    usage
fi
device="$1"

# get current version
eval $(grep "^PRODUCT_VERSION_" vendor/slim/config/common.mk | sed 's/ *//g')
VERSION="$PRODUCT_VERSION_MAINTENANCE.$PRODUCT_VERSION_MAJOR."

echo -e ${bldgrn}"Building Broken $VERSION"${txtrst}

if [ "$opt_clean" -eq 0 ]; then
    echo -e ""
    echo -e ${bldgrn}"Flag is needed"${txtrst}
    echo -e ""
    exit 1
elif [ "$opt_clean" -eq 1 ]; then
    make clean >/dev/null
    echo -e ""
    echo -e ${bldgrn}"Got rid of the garbage"${txtrst}
    echo -e ""
elif [ "$opt_clean" -eq 2 ]; then
    make dirty >/dev/null
    echo -e ""
    echo -e ${bldgrn}"Changelogs, build.prop and zips removed"${txtrst}
    echo -e ""
elif [ "$opt_clean" -eq 10 ]; then
    echo -e ${red}"Moving previously created official zips to OFFICIAL folder"${txtrst}
    mkdir OFFICIALS 2> /dev/null
    mv $OUTDIR/target/product/*/*OFFICIAL*.zip OFFICIALS 2> /dev/null
    mv $OUTDIR/target/product/*/*OFFICIAL*.zip.md5sum OFFICIALS 2> /dev/null
    make official >/dev/null
    export OFFICIAL=true
    echo -e ""
    echo -e ""
fi

# sync with latest sources
if [ "$opt_sync" -ne 0 ]; then
    echo -e ""
    echo -e ${bldgrn}"updating sources"${txtrst}
    repo sync -j"$opt_jobs"
    echo -e ""
fi

rm -f $OUTDIR/target/product/$device/obj/KERNEL_OBJ/.version

# get time of startup
t1=$($DATE +%s)

# setup environment
echo -e ${bldgrn}"Getting ready"${txtrst}
. build/envsetup.sh

# Remove system folder (this will create a new build.prop with updated build time and date)
rm -f $OUTDIR/target/product/$device/system/build.prop
rm -f $OUTDIR/target/product/$device/system/app/*.odex
rm -f $OUTDIR/target/product/$device/system/framework/*.odex

# initlogo
if [ "$opt_initlogo" -ne 0 ]; then
    export BUILD_WITH_STATIC_INITLOGO=true
fi

# lunch device
echo -e ""
echo -e ${bldgrn}"Getting your device"${txtrst}
lunch "slim_$device-userdebug";

echo -e ""

# start compilation
if [ "$opt_dex" -ne 0 ]; then
    export WITH_DEXPREOPT=true
    echo -e ""
    echo -e ${red}"Using DexOptimization"${txtrst}
    echo -e ""
fi

if [ "$opt_pipe" -ne 0 ]; then
    export TARGET_USE_PIPE=true
    echo -e ""
    echo -e ${red}"Using Pipe Optimization"${txtrst}
    echo -e ""
fi

if [ "$opt_strict" -ne 0 ]; then
    export STRICT=true
    echo -e ""
    echo -e ${red}"Using Strict Aliasing"${txtrst}
    echo -e ""
fi

if [ "$opt_olvl" -eq 1 ]; then
    export TARGET_USE_O_LEVEL_S=true
    echo -e ""
    echo -e ${red}"Using Os Optimization"${txtrst}
    echo -e ""
elif [ "$opt_olvl" -eq 3 ]; then
    export TARGET_USE_O_LEVEL_3=true
    echo -e ""
    echo -e ${red}"Using O3 Optimization"${txtrst}
    echo -e ""
else
    echo -e ""
    echo -e ${red}"Using the default GCC Optimization Level, O2"${txtrst}
    echo -e ""
fi

#create build-logs
echo -e ""
echo -e ${bldgrn}"Creating 'build-logs' directory if one hasn't been created already"${txtrst}
echo -e ""
# create 'build-logs' directory if it hasn't already been created
mkdir -p build-logs
echo -e ""
echo -e ${bldgrn}"Your build will be logged in 'build-logs'"${txtrst}
echo -e ""

# make 
if [ "$opt_log" -ne 0 ]; then
    #build and then sign with release keys
    make -j"$opt_jobs" dist 2>&1 | tee build-logs/slim_$device-$(date "+%Y%m%d").txt
    
else
    # build normally
    make -j"$opt_jobs" bacon 2>&1 | tee build-logs/slim_$device-$(date "+%Y%m%d").txt

fi

play $BEEP &> /dev/null

# finished? get elapsed time
t2=$($DATE +%s)

tmin=$(( (t2-t1)/60 ))
tsec=$(( (t2-t1)%60 ))

echo -e ${bldgrn}"Total time elapsed:${txtrst} ${grn}$tmin minutes $tsec seconds"${txtrst}
