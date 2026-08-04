#!/bin/sh
MODDIR=${0%/*}
cd "$MODDIR" || exit

ADBEX_PATH=/data/adb/adbex
mkdir -p $ADBEX_PATH

# Skip SELinux rules when KSU adb root is enabled
KSU_ADB_ROOT=0
KSUD=""
if [ -f /data/adb/ksu/lib/libadbroot.so ]; then
    if [ -x /data/adb/ksu/bin/ksud ]; then
        KSUD=/data/adb/ksu/bin/ksud
    elif command -v ksud >/dev/null 2>&1; then
        KSUD=ksud
    fi
    if [ -n "$KSUD" ]; then
        if $KSUD feature get adb_root 2>/dev/null | grep -qE 'Value:[[:space:]]*[1-9]'; then
            KSU_ADB_ROOT=1
        fi
    fi
fi

# Apply SELinux rules manually
if [ "$KSU_ADB_ROOT" != "1" ] && [ -f "$MODDIR/sepolicy_rule.txt" ]; then
    if [ -n "$KSUD" ]; then
        $KSUD sepolicy apply "$MODDIR/sepolicy_rule.txt" 2>/dev/null
    elif [ -x /data/adb/magisk/magiskpolicy ]; then
        /data/adb/magisk/magiskpolicy --live --apply "$MODDIR/sepolicy_rule.txt" 2>/dev/null
    fi
fi

if [ -f /linkerconfig/com.android.adbd/ld.config.txt ]; then
    echo "# adbex" >> /linkerconfig/com.android.adbd/ld.config.txt
    echo "namespace.default.permitted.paths += $ADBEX_PATH" >> /linkerconfig/com.android.adbd/ld.config.txt
fi

cp lib64/libadbex_init.so $ADBEX_PATH
cp lib64/libadbex_adbd.so $ADBEX_PATH
chcon -R u:object_r:system_file:s0 $ADBEX_PATH
./bin/inject 1 $ADBEX_PATH/libadbex_init.so
