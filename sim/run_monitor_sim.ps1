# Build the resident monitor and run the end-to-end UART RX/load/execute test.
$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot

$toolPath = "C:\msys64\ucrt64\bin"
if (Test-Path -LiteralPath $toolPath) {
    $env:Path = $toolPath + ";" + $env:Path
}

& powershell -ExecutionPolicy Bypass -File (Join-Path $repoRoot "sw\build.ps1")
if ($LASTEXITCODE -ne 0) { throw "Monitor firmware build failed." }

Set-Location -LiteralPath $PSScriptRoot
$rtl = Join-Path $repoRoot "rtl"
$sources = @(
    (Join-Path $rtl "alu.v"),
    (Join-Path $rtl "decoder.v"),
    (Join-Path $rtl "regfile.v"),
    (Join-Path $rtl "rv32i_core.v"),
    (Join-Path $rtl "uart_tx.v"),
    (Join-Path $rtl "uart_rx.v"),
    (Join-Path $rtl "soc_top.v"),
    "tb_uart_monitor.v"
)

iverilog -g2012 -I $rtl -I $PSScriptRoot -s tb_uart_monitor -o tb_uart_monitor.out @sources
if ($LASTEXITCODE -ne 0) { throw "Icarus compile failed." }
vvp tb_uart_monitor.out
if ($LASTEXITCODE -ne 0) { throw "UART monitor simulation failed." }
