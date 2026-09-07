param(
    [string]$Source = "hello.c",
    [string]$OutputName = "app"
)

# Compile a C program for the UART monitor's upload area and make a text file
# that can be sent directly with Tera Term's File -> Send File command.
$ErrorActionPreference = "Stop"
Set-Location -LiteralPath $PSScriptRoot

$msysToolPath = "C:\msys64\ucrt64\bin"
if (Test-Path -LiteralPath $msysToolPath) {
    $env:Path = $msysToolPath + ";" + $env:Path
}

$gcc = Get-Command riscv32-unknown-elf-gcc -ErrorAction SilentlyContinue
if (-not $gcc) {
    throw "riscv32-unknown-elf-gcc is not on PATH."
}
$objcopy = Get-Command riscv32-unknown-elf-objcopy -ErrorAction SilentlyContinue
if (-not $objcopy) {
    throw "riscv32-unknown-elf-objcopy is not on PATH."
}

$sourcePath = (Resolve-Path -LiteralPath $Source).Path
$buildDir = Join-Path $PSScriptRoot "build"
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

$elf = Join-Path $buildDir "$OutputName.elf"
$bin = Join-Path $buildDir "$OutputName.bin"
$uartFile = Join-Path $buildDir "$OutputName.uart"
$map = Join-Path $buildDir "$OutputName.map"
$linkerScript = Join-Path $PSScriptRoot "link_app.ld"

$cflags = @(
    "-march=rv32i", "-mabi=ilp32", "-mcmodel=medlow",
    "-Os", "-ffreestanding", "-fno-builtin",
    "-ffunction-sections", "-fdata-sections",
    "-nostdlib", "-nostartfiles",
    "-Wall", "-Wextra", "-Werror"
)

& $gcc.Source @cflags "-T$linkerScript" `
    "-Wl,--gc-sections,--build-id=none,-Map=$map" `
    "crt0_app.S" "uart.c" $sourcePath "-o" $elf
if ($LASTEXITCODE -ne 0) { throw "GCC failed." }

& $objcopy.Source "-O" "binary" $elf $bin
if ($LASTEXITCODE -ne 0) { throw "objcopy failed." }

[byte[]]$bytes = [System.IO.File]::ReadAllBytes($bin)
if (($bytes.Length % 4) -ne 0) {
    $padded = New-Object byte[] ($bytes.Length + 4 - ($bytes.Length % 4))
    [Array]::Copy($bytes, $padded, $bytes.Length)
    $bytes = $padded
}

$words = New-Object System.Collections.Generic.List[string]
[uint64]$checksum = 0
for ($offset = 0; $offset -lt $bytes.Length; $offset += 4) {
    [uint32]$word = [BitConverter]::ToUInt32($bytes, $offset)
    $words.Add(("{0:x8}" -f $word))
    $checksum += [uint64]$word
    if ($checksum -gt 4294967295) { $checksum -= 4294967296 }
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add(("L 00000800 {0:x8} {1:x8}" -f $words.Count, $checksum))
$lines.AddRange($words)
$lines.Add("G 00000800")
[System.IO.File]::WriteAllLines($uartFile, [string[]]$lines,
    [System.Text.Encoding]::ASCII)

Write-Host "Built $elf" -ForegroundColor Green
Write-Host "Tera Term upload file: $uartFile" -ForegroundColor Green
Write-Host "Send it at 115200 8N1 with no per-line delay." -ForegroundColor Cyan
