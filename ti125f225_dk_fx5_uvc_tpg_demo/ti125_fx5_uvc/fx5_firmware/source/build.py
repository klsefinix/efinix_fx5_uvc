#!/usr/bin/env python3
"""
Stand-alone build for the Ti125F225 FX5 UVC firmware (no ModusToolbox install).

Replicates what ModusToolbox core-make does for this one app:
  * auto-discovers sources/includes in app/ and mtb_shared/ using the
    COMPONENT_/TOOLCHAIN_/TARGET_/CONFIG_ directory filters and .cyignore
  * compiles with arm-none-eabi-gcc using the recipe-make-cat1a flags
  * links with the app's loadable linker script (runs under the FX bootloader)
  * appends the SHA-256 signature the FX USB bootloader checks
    (same as 'cymcuelftool --sign SHA256')
  * writes build/ti125_fx5_uvc_fw.hex

usage: python3 build.py [-j N] [--clean]
"""
import os, sys, subprocess, hashlib, shutil, argparse
from concurrent.futures import ThreadPoolExecutor

ROOT   = os.path.dirname(os.path.abspath(__file__))
APP    = os.path.join(ROOT, "app")
SHARED = os.path.join(ROOT, "mtb_shared")
OUT    = os.path.join(ROOT, "build")
NAME   = "ti125_fx5_uvc_fw"

TARGET    = "TI125F225_FX5"
DEVICE    = "CYUSB3083-FCAXI"
CORE      = "CM4"
CONFIG    = "Release"
TOOLCHAIN = "GCC_ARM"
COMPONENTS = {CORE, CORE + "_0", "SOFTFP", "FREERTOS", "RTOS_AWARE", "FX20_" + CORE,
              TOOLCHAIN, TARGET, CONFIG, "CAT1", "CAT1A", "FX3G2", "CM0P_SLEEP"}

# --- application options (from the Infineon example Makefile, adapted) -----
APP_DEFINES = [
    "CYUSB3083_FCAXI=1",
    "BCLK__BUS_CLK__HZ=75000000",
    "DEBUG_INFRA_EN=1",
    "FREERTOS_ENABLE=1",
    "USB3_LPM_ENABLE=1",
    "USBFS_LOGS_ENABLE=1",
    "FPGA_ENABLE=1",           # keep the FPGA code paths (LVDS link setup)
    "CUSTOM_TRAIN_ENABLE=0",   # 148.5 MHz 8:1 link: hardware PHY training only (as Infineon's 148.5 MHz examples)
    "DEEPSLEEP_EN=0",
    "LVDS_LOW_POWER_EN=0",
    "USB_CONN_TYPE=CY_USBD_USB_DEV_SS_GEN1",   # FX5 = USB 5 Gbps
    "LVCMOS_EN=0", "LVCMOS_DDR_EN=0",
    "SONY_IMX715_EN=0", "THINE_EN=0",
    "PORT1_EN=0", "INMD_EN=0", "PTM_ENABLE=0",
    "WL_EN=0",                 # narrow link (port 0, 8 lanes)
    "THREAD_INTERLEAVE_EN=0",
    "CY_VENDOR_IF_EN=0", "CDC_INTERFACE_EN=0", "AUDIO_IF_EN=0",
    "FORCE_USBHS=0",
    "BLOAD_ENABLE=1",
    "TI125_FX5_BOARD=1",       # board-specific changes in this port
]

GCC = "arm-none-eabi-gcc"
CPU = ["-mcpu=cortex-m4", "--specs=nano.specs", "-mfloat-abi=softfp", "-mfpu=fpv4-sp-d16", "-mthumb"]
COMMON = ["-ffunction-sections", "-fdata-sections", "-ffat-lto-objects", "-g", "-Wall", "-pipe"]
CFLAGS = CPU + COMMON + ["-Os", "-DNDEBUG", "-c"]
LDSCRIPT = os.path.join(APP, "LinkerScripts", "default", "fx_cm4_loadable.ld")

SRC_EXT = (".c", ".S", ".s")
FLASH_BASE, FLASH_LEN, SIG_LEN = 0x10008000, 0x78000, 512


def allowed(dirname):
    for p in ("COMPONENT_", "TOOLCHAIN_", "TARGET_", "CONFIG_"):
        if dirname.startswith(p):
            return dirname[len(p):] in COMPONENTS
    return not dirname.startswith(".")


def discover(top, ignore=()):
    srcs, incs = [], []
    ign = {os.path.normpath(os.path.join(top, i)) for i in ignore}
    for dirpath, dirnames, filenames in os.walk(top):
        cy = os.path.join(dirpath, ".cyignore")
        if os.path.exists(cy):
            for line in open(cy):
                line = line.strip()
                if line and not line.startswith("#"):
                    ign.add(os.path.normpath(os.path.join(dirpath, line)))
        dirnames[:] = sorted(d for d in dirnames
                             if allowed(d) and os.path.normpath(os.path.join(dirpath, d)) not in ign)
        if any(f.endswith((".h", ".hpp")) for f in filenames):
            incs.append(dirpath)
        for f in sorted(filenames):
            p = os.path.join(dirpath, f)
            if f.endswith(SRC_EXT) and os.path.normpath(p) not in ign:
                srcs.append(p)
    return srcs, incs


def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-j", type=int, default=os.cpu_count() or 4)
    ap.add_argument("--clean", action="store_true")
    a = ap.parse_args()
    if a.clean and os.path.isdir(OUT):
        shutil.rmtree(OUT)
    os.makedirs(OUT, exist_ok=True)

    srcs, incs = discover(APP, ignore=["build", "bootloader", "LinkerScripts"])
    for lib in sorted(os.listdir(SHARED)):
        if lib in ("core-make", "recipe-make-cat1a"):
            continue
        s, i = discover(os.path.join(SHARED, lib))
        srcs += s; incs += i

    defines = ["-D" + d for d in APP_DEFINES] + [
        "-DTARGET_" + TARGET, "-DCY_TARGET_BOARD=" + TARGET,
        "-DCY_SUPPORTS_DEVICE_VALIDATION", "-DCORE_NAME_%s_0=1" % CORE,
        "-D" + DEVICE.replace("-", "_"),
    ] + ["-DCOMPONENT_" + c for c in sorted(COMPONENTS)]
    inc_flags = ["-I" + i for i in incs]
    rsp = os.path.join(OUT, "inc.rsp")
    with open(rsp, "w") as f:
        f.write("\n".join(defines + inc_flags))

    objs, jobs = [], []
    for s in srcs:
        rel = os.path.relpath(s, ROOT)
        o = os.path.join(OUT, "obj", rel + ".o")
        os.makedirs(os.path.dirname(o), exist_ok=True)
        objs.append(o)
        flags = CFLAGS if not s.endswith((".S", ".s")) else CPU + COMMON + ["-c", "-x", "assembler-with-cpp"]
        jobs.append((rel, [GCC] + flags + ["@" + rsp, s, "-o", o]))

    print("%d sources, %d to compile" % (len(srcs), len(jobs)))
    fails = 0
    with ThreadPoolExecutor(a.j) as ex:
        for (rel, _), (rc, out) in zip(jobs, ex.map(lambda j: run(j[1]), jobs)):
            if rc:
                fails += 1
                print("FAIL", rel); print(out)
            elif "warning" in out and rel.startswith("app"):
                print("warn", rel); print(out)
    if fails:
        sys.exit("%d files failed" % fails)

    elf = os.path.join(OUT, NAME + ".elf")
    orsp = os.path.join(OUT, "obj.rsp")
    open(orsp, "w").write("\n".join(objs))
    rc, out = run([GCC] + CPU + COMMON + ["-Wl,--gc-sections", "-T", LDSCRIPT,
                   "-Wl,-Map," + os.path.join(OUT, NAME + ".map"), "--entry=Reset_Handler",
                   "-Wl,--start-group", "@" + orsp, "-Wl,--end-group", "-o", elf])
    print(out.strip())
    if rc:
        sys.exit("link failed")

    sign_and_hex(elf, os.path.join(OUT, NAME + ".hex"))
    rc, out = run(["arm-none-eabi-size", elf]); print(out)


def sign_and_hex(elf, hexfile):
    """Fill flash with 0, SHA-256 over [app start, signature), store at signature."""
    from intelhex import IntelHex
    tmp = elf + ".hex.tmp"
    subprocess.check_call(["arm-none-eabi-objcopy", "-O", "ihex", "--gap-fill", "0", elf, tmp])
    ih = IntelHex(tmp)
    sig_addr = FLASH_BASE + FLASH_LEN - SIG_LEN
    for addr in range(ih.minaddr(), FLASH_BASE + FLASH_LEN):
        if addr >= FLASH_BASE and ih[addr] is None:
            pass
    body = bytes(ih.tobinarray(start=FLASH_BASE, end=sig_addr - 1, pad=0))
    digest = hashlib.sha256(body).digest()
    full = IntelHex()
    full.frombytes(body, offset=FLASH_BASE)
    full.frombytes(digest + bytes(SIG_LEN - len(digest)), offset=sig_addr)
    # keep any data outside the app flash window (none expected)
    for a in ih.addresses():
        if not (FLASH_BASE <= a < FLASH_BASE + FLASH_LEN):
            full[a] = ih[a]
    full.write_hex_file(hexfile)
    os.remove(tmp)
    print("signed %s  sha256=%s" % (os.path.basename(hexfile), digest.hex()))


if __name__ == "__main__":
    main()
