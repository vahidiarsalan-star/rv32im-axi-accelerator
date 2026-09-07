#!/usr/bin/env python3
"""Rebuild and run the reproducible RTL/firmware regression (Python stdlib only)."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

import gen_regression

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "build" / "verification"
CORE = ["alu.v", "decoder.v", "regfile.v", "rv32i_core.v"]
SOC = CORE + ["uart_tx.v", "uart_rx.v", "soc_top.v"]


def source_digest():
    paths = sorted(p for folder in ("rtl", "sim", "sw") for p in (ROOT / folder).glob("*")
                   if p.suffix in (".v", ".vh", ".py", ".c", ".h", ".S", ".ld"))
    digest = hashlib.sha256()
    for path in paths:
        # Normalize line endings so Windows and Linux identify the same sources.
        digest.update(path.relative_to(ROOT).as_posix().encode() + b"\0")
        digest.update(path.read_bytes().replace(b"\r\n", b"\n") + b"\0")
    return digest.hexdigest()


def command(args, log_name, marker=None, expected_failure=False):
    result = subprocess.run([str(a) for a in args], cwd=OUT, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180)
    output = result.stdout.replace(str(ROOT), "<repo>").replace(str(ROOT).replace("\\", "/"), "<repo>")
    (OUT / f"{log_name}.log").write_text(output, encoding="utf-8")
    if expected_failure:
        ok = result.returncode != 0 and marker in output
    else:
        ok = result.returncode == 0 and (marker is None or marker in output)
    if not ok:
        print(output)
        raise RuntimeError(f"{log_name}: unexpected result (exit {result.returncode})")
    return output


def compile_tb(top, rtl, parameters=()):
    output = top + ("_" + "_".join(parameters).replace("=", "_") if parameters else "") + ".out"
    command(["iverilog", "-g2012", "-I", ROOT / "rtl", "-I", ROOT / "sim", "-s", top,
             *["-P" + p for p in parameters], "-o", output,
             *[ROOT / "rtl" / name for name in rtl],
             *([ROOT / "sim" / "sim_memory.v"] if top == "tb_top" else []),
             ROOT / "sim" / (top + ".v")], "compile_" + output)
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rtl-only", action="store_true", help="CPU and UART tests without GCC")
    parser.add_argument("--waves", action="store_true", help="Retain CPU VCDs for inspection")
    args = parser.parse_args()
    for tool in ("iverilog", "vvp"):
        if not shutil.which(tool):
            parser.error(f"{tool} must be on PATH")
    OUT.mkdir(parents=True, exist_ok=True)
    results = []
    summary = {"generated_utc": datetime.now(timezone.utc).isoformat(),
               "source_sha256": source_digest(), "scope": "rtl-only" if args.rtl_only else "full",
               "status": "RUNNING", "results": results, "tools": {"python": sys.version.split()[0]}}
    try:
        summary["tools"]["iverilog"] = command(["iverilog", "-V"], "iverilog_version").splitlines()[0]
        cpu = compile_tb("tb_top", CORE)
        for name, words in gen_regression.cases():
            (OUT / f"{name}.hex").write_text("".join(f"{w:08x}\n" for w in words), encoding="ascii")
            output = command(["vvp", cpu, f"+PROGRAM={name}.hex", f"+WORDS={len(words)}",
                              *(["+WAVES"] if args.waves else [])], name, "*** PASS ***")
            metrics = re.search(r"cycles=(\d+) stalls=(\d+) redirects=(\d+)", output)
            entry = {"test": name, "status": "PASS", "static_words": len(words),
                     **dict(zip(("cycles", "stall_cycles", "redirect_events"), map(int, metrics.groups())))}
            results.append(entry)
            if args.waves:
                shutil.copyfile(OUT / "tb_top.vcd", OUT / f"{name}.vcd")
            print(f"PASS {name}: {entry['cycles']} cycles", flush=True)
        # Prove a failing DUT/program and a hang cannot be reported as green CI.
        for name, words, marker in [("failure_exit", [0x00001fb7, 0x00200f13, 0x01efa023], "*** FAIL ***"),
                                    ("timeout_exit", [0x0000006f], "*** TIMEOUT ***")]:
            (OUT / f"{name}.hex").write_text("".join(f"{w:08x}\n" for w in words), encoding="ascii")
            command(["vvp", cpu, f"+PROGRAM={name}.hex", f"+WORDS={len(words)}"], name, marker, True)
            results.append({"test": name, "status": "PASS", "expected_nonzero_exit": True})
            print(f"PASS {name}: deliberately failing simulation rejected", flush=True)
        for divisor in (10, 234):
            uart = compile_tb("tb_uart", ["uart_rx.v", "uart_tx.v"], [f"tb_uart.DIV={divisor}"])
            name = f"uart_divisor_{divisor}"
            command(["vvp", uart], name, "*** UART UNIT PASS ***")
            results.append({"test": name, "status": "PASS", "byte_values": 256, "divisor": divisor})
            print(f"PASS {name}: 256 bytes, false start, framing error", flush=True)
        if not args.rtl_only:
            sys.path.insert(0, str(ROOT / "sw"))
            import build as firmware
            prefix = firmware.tool_prefix()
            summary["tools"]["gcc"] = command([prefix + "gcc", "--version"], "gcc_version").splitlines()[0]
            command([sys.executable, ROOT / "sw" / "build.py", "--out-dir", OUT], "firmware_build")
            summary["firmware_binary_bytes"] = {name: (OUT / f"{name}.bin").stat().st_size
                                                 for name in ("monitor", "hello", "echo", "hello_standalone")}
            shutil.copyfile(OUT / "hello_standalone.hex", OUT / "firmware.hex")
            c_tb = compile_tb("tb_c_firmware", CORE)
            command(["vvp", c_tb], "c_firmware", "*** C FIRMWARE PASS ***")
            results.append({"test": "c_firmware", "status": "PASS"})
            print("PASS c_firmware: freshly compiled C image", flush=True)
            monitor = compile_tb("tb_uart_monitor", SOC)
            command(["vvp", monitor], "uart_monitor", "*** UART MONITOR PASS ***")
            results.append({"test": "uart_monitor", "status": "PASS"})
            print("PASS uart_monitor: command rejection, upload, RAM, serial TX", flush=True)
            app = compile_tb("tb_uart_application", SOC)
            for name in ("hello", "echo"):
                payload = (OUT / f"{name}.uart").read_bytes()
                (OUT / f"{name}_bytes.hex").write_text("".join(f"{b:02x}\n" for b in payload), encoding="ascii")
                command(["vvp", app, f"+UPLOAD={name}_bytes.hex", f"+BYTES={len(payload)}",
                         *(["+ECHO"] if name == "echo" else [])], f"uart_{name}_app",
                        f"*** UART {name.upper()} APP PASS ***")
                results.append({"test": f"uart_{name}_app", "status": "PASS", "upload_bytes": len(payload)})
                print(f"PASS uart_{name}_app: compiled application loaded over serial", flush=True)
        summary["status"] = "PASS"
        print(f"\n{len(results)} checks passed. Evidence: build/verification/summary.json", flush=True)
    except (OSError, RuntimeError, subprocess.SubprocessError, AssertionError) as exc:
        summary["status"] = "FAIL"
        summary["error"] = str(exc).replace(str(ROOT), "<repo>")
        print(f"FAIL: {summary['error']}", file=sys.stderr)
        return 1
    finally:
        (OUT / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
