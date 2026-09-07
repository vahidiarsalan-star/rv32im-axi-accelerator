# Build the resident bare-metal UART monitor for soc_top.v.
# Run from PowerShell:
#   powershell -ExecutionPolicy Bypass -File .\build.ps1

$ErrorActionPreference = "Stop"
Set-Location -LiteralPath $PSScriptRoot

$msysToolPath = "C:\msys64\ucrt64\bin"
if (Test-Path -LiteralPath $msysToolPath) {
    $env:Path = $msysToolPath + ";" + $env:Path
}

$gcc = Get-Command riscv32-unknown-elf-gcc -ErrorAction SilentlyContinue
if (-not $gcc) {
    throw "riscv32-unknown-elf-gcc is not on PATH. Open a new PowerShell window after the MSYS2 setup."
}

$objcopy = Get-Command riscv32-unknown-elf-objcopy -ErrorAction SilentlyContinue
if (-not $objcopy) {
    throw "riscv32-unknown-elf-objcopy is not on PATH."
}

$buildDir = Join-Path $PSScriptRoot "build"
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

$elf = Join-Path $buildDir "monitor.elf"
$bin = Join-Path $buildDir "monitor.bin"
$hex = Join-Path $buildDir "monitor.hex"
$linkerScript = Join-Path $PSScriptRoot "link_monitor.ld"

$cflags = @(
    "-march=rv32i", "-mabi=ilp32", "-mcmodel=medlow",
    "-Os", "-ffreestanding", "-fno-builtin",
    "-ffunction-sections", "-fdata-sections",
    "-nostdlib", "-nostartfiles",
    "-Wall", "-Wextra", "-Werror"
)

& $gcc.Source @cflags "-T$linkerScript" "-Wl,--gc-sections,--build-id=none" `
    "crt0.S" "uart.c" "monitor.c" "-o" $elf
if ($LASTEXITCODE -ne 0) { throw "GCC failed." }

& $objcopy.Source "-O" "binary" $elf $bin
if ($LASTEXITCODE -ne 0) { throw "objcopy failed." }

# Gowin's RAM initializer is known to accept the project's original plain,
# one-32-bit-word-per-line format.  Do not use objcopy's @address directives.
[byte[]]$bytes = [System.IO.File]::ReadAllBytes($bin)
if (($bytes.Length % 4) -ne 0) {
    $padded = New-Object byte[] ($bytes.Length + 4 - ($bytes.Length % 4))
    [Array]::Copy($bytes, $padded, $bytes.Length)
    $bytes = $padded
}

$words = for ($offset = 0; $offset -lt $bytes.Length; $offset += 4) {
    "{0:x8}" -f [BitConverter]::ToUInt32($bytes, $offset)
}
if ($words.Count -gt 1024) {
    throw "Monitor image exceeds the SoC's 1024-word RAM."
}
# Give every RAM word a deterministic power-up value.  The upload region is
# replaced by the monitor before it is executed.
while ($words.Count -lt 1024) {
    $words += "00000013" # RV32I NOP (addi x0,x0,0)
}
[System.IO.File]::WriteAllLines($hex, [string[]]$words)

Copy-Item -Force $hex (Join-Path $PSScriptRoot "..\gowin\firmware.hex")
Copy-Item -Force $hex (Join-Path $PSScriptRoot "..\sim\monitor.hex")

Write-Host "Built $elf" -ForegroundColor Green
Write-Host "Updated gowin\firmware.hex and sim\monitor.hex" -ForegroundColor Green
