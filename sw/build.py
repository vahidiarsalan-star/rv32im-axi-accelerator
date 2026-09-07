#!/usr/bin/env python3
"""Build freestanding RV32I firmware with either common GNU cross-tool prefix."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SW = ROOT / "sw"


def tool_prefix():
    candidates = [os.environ.get("RISCV_PREFIX", ""),
                  "riscv32-unknown-elf-", "riscv64-unknown-elf-"]
    for prefix in filter(None, candidates):
        if all(shutil.which(prefix + t) for t in ("gcc", "objcopy", "size")):
            return prefix
    raise RuntimeError("Install a RISC-V bare-metal GCC/binutils toolchain or set RISCV_PREFIX.")


def words_from_binary(data):
    data += bytes((-len(data)) % 4)
    return [int.from_bytes(data[i:i + 4], "little") for i in range(0, len(data), 4)]


def upload_record(words, base=0x800):
    checksum = sum(words) & 0xffffffff
    return (f"L {base:08x} {len(words):08x} {checksum:08x}\n" +
            "".join(f"{word:08x}\n" for word in words) + f"G {base:08x}\n")


def build(target, out_dir, prefix):
    out_dir = Path(out_dir).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    monitor = target == "monitor"
    standalone = target == "hello_standalone"
    source = "monitor.c" if monitor else "hello.c" if standalone else f"{target}.c"
    linker = "link_monitor.ld" if monitor else "link.ld" if standalone else "link_app.ld"
    startup = "crt0.S" if monitor or standalone else "crt0_app.S"
    elf = out_dir / f"{target}.elf"
    binary = out_dir / f"{target}.bin"
    flags = ["-march=rv32i", "-mabi=ilp32", "-mcmodel=medlow", "-Os",
             "-mno-relax", "-msmall-data-limit=0", "-ffreestanding", "-fno-builtin",
             "-ffunction-sections", "-fdata-sections", "-nostdlib", "-nostartfiles",
             "-Wall", "-Wextra", "-Werror"]
    subprocess.run([prefix + "gcc", *flags, "-T" + str(SW / linker),
                    "-Wl,--gc-sections,--build-id=none,-Map=" + str(out_dir / f"{target}.map"),
                    str(SW / startup), str(SW / "uart.c"), str(SW / source), "-o", str(elf)],
                   check=True)
    subprocess.run([prefix + "objcopy", "-O", "binary", str(elf), str(binary)], check=True)
    words = words_from_binary(binary.read_bytes())
    if monitor or standalone:
        if len(words) > 1024:
            raise RuntimeError(f"{target}: image exceeds 4 KiB")
        padded = words + [0x13] * (1024 - len(words))
        (out_dir / f"{target}.hex").write_text(
            "".join(f"{w:08x}\n" for w in padded), encoding="ascii")
    else:
        if len(words) > 384:
            raise RuntimeError(f"{target}: image exceeds application region")
        (out_dir / f"{target}.uart").write_text(upload_record(words), encoding="ascii")
    subprocess.run([prefix + "size", str(elf)], check=True)
    return binary.stat().st_size


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", choices=["all", "monitor", "hello", "echo", "hello_standalone"], default="all")
    parser.add_argument("--out-dir", type=Path, default=SW / "build")
    parser.add_argument("--update-board-image", action="store_true",
                        help="Explicitly copy a newly built monitor to gowin/firmware.hex")
    args = parser.parse_args()
    prefix = tool_prefix()
    targets = ["monitor", "hello", "echo", "hello_standalone"] if args.target == "all" else [args.target]
    for target in targets:
        print(f"Building {target}", flush=True)
        build(target, args.out_dir, prefix)
    if args.update_board_image:
        if "monitor" not in targets:
            parser.error("--update-board-image requires --target monitor or all")
        shutil.copyfile(args.out_dir / "monitor.hex", ROOT / "gowin" / "firmware.hex")


if __name__ == "__main__":
    main()
