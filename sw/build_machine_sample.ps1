# Generate the small hand-coded UART test with deterministic CRLF line endings.
$ErrorActionPreference = "Stop"
$output = Join-Path $PSScriptRoot "build\machine_bang.uart"
$lines = @(
    "L 00000800 00000007 810bdb55",
    "800002b7",
    "0042a303",
    "00137313",
    "fe031ce3",
    "02100513",
    "00a2a023",
    "0000006f",
    "G 00000800"
)
[System.IO.File]::WriteAllLines($output, $lines, [System.Text.Encoding]::ASCII)
Write-Host "Generated $output with CRLF line endings." -ForegroundColor Green
