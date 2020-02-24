#!/usr/bin/env bash
# Circle CI/CD - Simple kernel build script
export parse_branch=$(git rev-parse --abbrev-ref HEAD)
if [[ $parse_branch == "vince" ]]; then
     export device="Xiaomi Redmi 5 Plus"
     export codename_device=vince
     export config_device=vince-perf_defconfig
elif [[ $parse_branch == "lavender" ]]; then
     export device="Xiaomi Redmi Note 7/7S"
     export codename_device=lavender
     export config_device=lavender-perf_defconfig
elif [[ ! $parse_branch == "vince" ]] && [[ ! $parse_branch == "lavender" ]]; then
     echo "please set the kernel branch name as above"
     exit 1;
fi
mkdir $(pwd)/TEMP
if [[ $parse_branch == "vince" ]]; then
     git clone --depth=1 https://github.com/crdroidandroid/android_prebuilts_clang_host_linux-x86_clang-6207600 clang
     git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 -b android-9.0.0_r50 gcc
     git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 -b android-9.0.0_r50 gcc32
elif [[ $parse_branch == "lavender" ]]; then
     git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 -b android-9.0.0_r50 gcc
     git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 -b android-9.0.0_r50 gcc32
fi
git clone --depth=1 https://github.com/fadlyas07/AnyKernel3-1 anykernel3
git clone --depth=1 https://github.com/fabianonline/telegram.sh telegram

# Telegram & Github Env Vars
export ARCH=arm64
export TZ=Asia/Jakarta
export TEMP=$(pwd)/TEMP
export TELEGRAM_ID=$chat_id
export pack=$(pwd)/anykernel3
export TELEGRAM_TOKEN=$token
export product_name=GREENFORCE
export KBUILD_BUILD_USER=github.com.fadlyas07
export KBUILD_BUILD_HOST=$CIRCLE_SHA1
export kernel_img=$(pwd)/out/arch/arm64/boot/Image.gz-dtb
export commit_point=$(git log --pretty=format:'<code>%h: %s by</code> <b>%an</b>' -1)

TELEGRAM=telegram/telegram
tg_channelcast() {
    "$TELEGRAM" -c "$TELEGRAM_ID" -H \
	"$(
		for POST in "$@"; do
			echo "$POST"
		done
	)"
}
tg_sendinfo() {
  curl -s "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
       -d chat_id="784548477" \
       -d "parse_mode=markdown" \
       -d "disable_web_page_preview=true" \
       -d text="$1"
}
tg_sendstick() {
   curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendSticker" \
	-d sticker="CAADBQADPwEAAn1Cwy4LGnCzWtePdRYE" \
	-d chat_id="$TELEGRAM_ID"
}
if [[ $parse_branch == "vince" ]]; then 
      export PATH=$(pwd)/clang/bin:$(pwd)/gcc/bin:$(pwd)/gcc32/bin:$PATH
elif [[ $parse_branch == "lavender" ]]; then
       export PATH=$(pwd)/gcc/bin:$(pwd)/gcc32/bin:$PATH
fi
date=$(TZ=Asia/Jakarta date +'%H%M-%d%m%y')
make O=out ARCH=arm64 "$config_device"
if [[ $parse_branch == "vince" ]]; then 
make -j$(nproc) O=out \
                ARCH=arm64 \
                CC=clang \
                CLANG_TRIPLE=aarch64-linux-gnu- \
                CROSS_COMPILE=aarch64-linux-android- \
                CROSS_COMPILE_ARM32=arm-linux-androideabi- 2>&1| tee kernel.log
elif [[ $parse_branch == "lavender" ]]; then
make -j$(nproc) O=out \
                ARCH=arm64 \
                CROSS_COMPILE=aarch64-linux-android- \
                CROSS_COMPILE_ARM32=arm-linux-androideabi- 2>&1| tee kernel.log
fi
mv *.log $TEMP
if [[ ! -f "$kernel_img" ]]; then
        curl -F document=@$(echo $TEMP/*.log) "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="$fadlyas"
	tg_sendinfo "$product_name $device Build Failed!!"
	exit 1;
else
        mv $kernel_img $pack/zImage
fi
curl -F document=@$(echo $TEMP/*.log) "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="784548477"
cd $pack
zip -r9q $product_name-$codename_device-$date.zip * -x .git README.md LICENCE
cd ..
toolchain_ver=$(cat $(pwd)/out/include/generated/compile.h | grep LINUX_COMPILER | cut -d '"' -f2)
tg_sendstick
tg_channelcast "<b>$product_name new build is available</b>!" \
	       "<b>Device :</b> <code>$device</code>" \
	       "<b>Branch :</b> <code>$parse_branch</code>" \
               "<b>Toolchain :</b> <code>$toolchain_ver</code>" \
	       "<b>Latest commit :</b> $commit_point"
curl -F document=@$(echo $pack/*.zip) "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="$TELEGRAM_ID"