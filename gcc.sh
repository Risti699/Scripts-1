#!/usr/bin/env bash
# Circle CI/CD - Simple kernel build script
# Copyright (C) 2019 Raphielscape LLC (@raphielscape)
# Copyright (C) 2019 Dicky Herlambang (@Nicklas373)
# Copyright (C) 2020 Muhammad Fadlyas (@fadlyas07)
export parse_branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$parse_branch" == "aosp/eas-3.18" ]; then
	export kernel_type=EaS
	export sticker="CAADBQADIwEAAn1Cwy5pf2It72fNXBYE"
elif [ "$parse_branch" == "aware" ]; then
	export kernel_type=EaS-LTO
	export sticker="CAADBQADIwEAAn1Cwy5pf2It72fNXBYE"
fi

# Environment for Device 1
export codename_device1=rolex
export config_device1=rolex_defconfig

# Environment for Device 2
export codename_device2=riva
export config_device2=riva_defconfig

# Environment Vars
export ARCH=arm64
export TZ="Asia/Jakarta"
export pack1=$(pwd)/zip1
export pack2=$(pwd)/zip2
export TELEGRAM_ID=$chat_id
export TELEGRAM_TOKEN=$token
export product_name=GREENFORCE
export device="Xiaomi Redmi 4A/5A"
export KBUILD_BUILD_HOST=$CIRCLE_SHA1
export KBUILD_BUILD_USER=github.com.fadlyas07
export PATH=$(pwd)/gcc/bin:$(pwd)/gcc32/bin:$PATH
export kernel_img=$(pwd)/out/arch/arm64/boot/Image.gz-dtb
export commit_point=$(git log --pretty=format:'%h: %s (%an)' -1)

mkdir $(pwd)/TEMP
export TEMP=$(pwd)/TEMP
if [ "$parse_branch" == "aosp/eas-3.18" ]; then
    git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 -b android-9.0.0_r40 gcc
    git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 -b android-9.0.0_r40 gcc32
elif [ "$parse_branch" == "aware" ]; then
    mkdir gcc gcc32
    echo "processing..." # Download GCC 9.2-2019 arm32
    wget https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-a/9.2-2019.12/binrel/gcc-arm-9.2-2019.12-x86_64-arm-none-eabi.tar.xz
    tar -xvf gcc-arm-9.2-2019.12-x86_64-arm-none-eabi.tar.xz
    mv gcc-arm-9.2-2019.12-x86_64-arm-none-eabi/* gcc32/
    echo "processing..." # Download GCC 9.2-2019 aarch64
    wget https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-a/9.2-2019.12/binrel/gcc-arm-9.2-2019.12-x86_64-aarch64-none-elf.tar.xz 
    tar -xvf gcc-arm-9.2-2019.12-x86_64-aarch64-none-elf.tar.xz 
    mv gcc-arm-9.2-2019.12-x86_64-aarch64-none-elf/* gcc/
    rm -rf *.tar.xz && rm -rf gcc-arm*
fi
git clone --depth=1 https://github.com/fabianonline/telegram.sh telegram
git clone --depth=1 https://github.com/fadlyas07/anykernel-3 zip1
git clone --depth=1 https://github.com/fadlyas07/anykernel-3 zip2

TELEGRAM=telegram/telegram
tg_channelcast() {
    "$TELEGRAM" -c "$TELEGRAM_ID" -H \
	"$(
		for POST in "$@"; do
			echo "$POST"
		done
	)"
}
tg_sendstick() {
   curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendSticker" \
	-d sticker="CAADBQADIwEAAn1Cwy5pf2It72fNXBYE" \
	-d chat_id="$TELEGRAM_ID"
}
if [ "$parse_branch" == "aware" ]; then
    tg_makegcc () {
        make -C $(pwd) -j$(nproc --all) O=out \
                                        ARCH=arm64 \
                                        CROSS_COMPILE=aarch64-none-elf- \
                                        CROSS_COMPILE_ARM32=arm-none-eabi- 2>&1| tee kernel.log
    }
else
    tg_makegcc () {
        make -C $(pwd) -j$(nproc --all) O=out \
                                        ARCH=arm64 \
                                        CROSS_COMPILE=aarch64-linux-android- \
                                        CROSS_COMPILE_ARM32=arm-linux-androideabi- 2>&1| tee kernel.log
    }
fi
tg_sendinfo() {
    "$TELEGRAM" -c "784548477" -H \
	"$(
		for POST in "$@"; do
			echo "$POST"
		done
	)"
}
tg_makedevice1() {
make -s -C $(pwd) -j$(nproc --all) ARCH=arm64 O=out "$config_device1"
PATH=$(pwd)/gcc/bin:$(pwd)/gcc32/bin:$PATH \
tg_makegcc
}
tg_makedevice2() {
make -s -C $(pwd) -j$(nproc --all) ARCH=arm64 O=out "$config_device2"
PATH=$(pwd)/gcc/bin:$(pwd)/gcc32/bin:$PATH \
tg_makegcc
}

# Time to compile Device 1
date1=$(TZ=Asia/Jakarta date +'%H%M-%d%m%y')
tg_makedevice1
mv *.log $TEMP
if [[ ! -f "$kernel_img" ]]; then
	curl -F document=@$(echo $TEMP/*.log) "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="784548477"
	tg_sendinfo "$product_name $kernel_type Build Failed!"
	exit 1
else
	mv $kernel_img $pack1/zImage
fi
curl -F document=@$(echo $TEMP/*.log) "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="784548477"
cd $pack1
zip -r9q $product_name-$codename_device1-$kernel_type-$date1.zip * -x .git README.md LICENCE
cd ..

# clean out & log before compile again
rm -rf out/ $TEMP/*.log

# Time to compile Device 2
date2=$(TZ=Asia/Jakarta date +'%H%M-%d%m%y')
tg_makedevice2
mv *.log $TEMP
if [[ ! -f "$kernel_img" ]]; then
	curl -F document=@$(echo $TEMP/*.log) "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="784548477"
	tg_sendinfo "$product_name $kernel_type Build Failed!"
	exit 1
else
	mv $kernel_img $pack2/zImage
fi
curl -F document=@$(echo $TEMP/*.log) "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="784548477"
cd $pack2
zip -r9q $product_name-$codename_device2-$kernel_type-$date2.zip * -x .git README.md LICENCE
cd ..

toolchain_ver=$(cat $(pwd)/out/include/generated/compile.h | grep LINUX_COMPILER | cut -d '"' -f2)
tg_sendstick
tg_channelcast "<b>$product_name new build is available</b>!" \
		"<b>Device :</b> <code>$device</code>" \
		"<b>Kernel Type :</b> <code>$kernel_type</code>" \
		"<b>Branch :</b> <code>$parse_branch</code>" \
		"<b>Toolchain :</b> <code>$toolchain_ver</code>" \
		"<b>Latest commit :</b> <code>$commit_point</code>"
curl -F document=@$(echo $pack1/*.zip) "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="$TELEGRAM_ID"
curl -F document=@$(echo $pack2/*.zip) "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="$TELEGRAM_ID"
