# Build + run the RV32I self-checking testbench with Icarus Verilog.
#
#   1) generate program.hex via the golden test generator (gen_test.py)
#   2) compile the core + testbench with iverilog
#   3) run the simulation with vvp
#
# There is no Verilog simulator required to *generate/validate* the test vector
# (gen_test.py does that in Python). iverilog is only needed to run the RTL.
# If you don't have iverilog, open these files in the Gowin EDA simulator instead
# (top module = tb_top).

$ErrorActionPreference = "Stop"
Set-Location -LiteralPath $PSScriptRoot

# --- locate a Python interpreter -------------------------------------------
function Find-Python {
    foreach ($c in @(
        (Join-Path $PSScriptRoot "..\..\yo.venv\Scripts\python.exe"),
        "python", "py", "python3"
    )) {
        $cmd = Get-Command $c -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    return $null
}

$py = Find-Python
if (-not $py) { Write-Error "No Python interpreter found (needed for gen_test.py)."; exit 1 }

Write-Host "==> Generating program.hex (golden ISS self-check)" -ForegroundColor Cyan
& $py "gen_test.py"
if ($LASTEXITCODE -ne 0) { Write-Error "gen_test.py failed."; exit 1 }

# --- compile + run with iverilog if available ------------------------------
$iv = Get-Command iverilog -ErrorAction SilentlyContinue
if (-not $iv) {
    Write-Host ""
    Write-Host "iverilog not found on PATH." -ForegroundColor Yellow
    Write-Host "Install it (winget install Icarus.Verilog) or simulate in Gowin EDA."
    Write-Host "Files (top = tb_top):"
    Write-Host "  ..\rtl\alu.v ..\rtl\decoder.v ..\rtl\regfile.v ..\rtl\rv32i_core.v sim_memory.v tb_top.v"
    exit 0
}

$rtl = "..\rtl"
$srcs = @(
    "$rtl\alu.v", "$rtl\decoder.v", "$rtl\regfile.v", "$rtl\rv32i_core.v",
    "sim_memory.v", "tb_top.v"
)

Write-Host "==> Compiling with iverilog" -ForegroundColor Cyan
iverilog -g2012 -I $rtl -o tb_top.out @srcs
if ($LASTEXITCODE -ne 0) { Write-Error "iverilog compile failed."; exit 1 }

Write-Host "==> Running vvp" -ForegroundColor Cyan
vvp tb_top.out
