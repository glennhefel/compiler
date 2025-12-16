# PowerShell build script for Windows
# Prerequisites (choose one installation method before running):
# - Chocolatey: choco install winflexbison3 mingw -y
#   (Add Mingw\bin to PATH if not auto-added)
# - Scoop: scoop install gcc winflexbison make
# - MSYS2 (UCRT64 or MINGW64 shell): pacman -S --needed mingw-w64-x86_64-gcc winflexbison make
# - WSL (Ubuntu): sudo apt update; sudo apt install build-essential flex bison
#
# This script assumes availability of: win_bison (or bison), win_flex (or flex), g++.
# If commands differ, adjust the variables below.

$ErrorActionPreference = 'Stop'

# Detect available tool names (basic heuristics)
$BisonCandidates = @('win_bison', 'bison', 'yacc')
$FlexCandidates  = @('win_flex', 'flex')
$GxxCandidates   = @('g++')

function Find-Tool($names) {
    foreach ($n in $names) {
        if (Get-Command $n -ErrorAction SilentlyContinue) { return $n }
    }
    throw "Required tool not found among: $($names -join ', ')"
}

$Bison = Find-Tool $BisonCandidates
$Flex  = Find-Tool $FlexCandidates
$Gxx   = Find-Tool $GxxCandidates

Write-Host "Using bison: $Bison" -ForegroundColor Cyan
Write-Host "Using flex:  $Flex" -ForegroundColor Cyan
Write-Host "Using g++:   $Gxx" -ForegroundColor Cyan

# Clean previous artifacts
# Clean previous artifacts (use explicit array to avoid comma parsing issues)
Remove-Item -Force -ErrorAction SilentlyContinue @('y.tab.c','y.tab.h','y.output','y.o','lex.yy.c','l.o','a.exe','parser.exe','22101047_log.txt')

# Generate parser (equivalent to: yacc -d -y --debug --verbose 22101047.y)
& $Bison -d -y --debug --verbose -Wcounterexamples 22101047.y
Write-Host "Generated parser sources (y.tab.c, y.tab.h)" -ForegroundColor Green

# Compile parser object
& $Gxx -w -c -o y.o y.tab.c
Write-Host "Compiled parser object (y.o)" -ForegroundColor Green

# Generate scanner
& $Flex 22101047.l
Write-Host "Generated scanner (lex.yy.c)" -ForegroundColor Green

# Compile scanner object
& $Gxx -fpermissive -w -c -o l.o lex.yy.c
Write-Host "Compiled scanner object (l.o)" -ForegroundColor Green

# Link final executable
$OutExe = 'parser.exe'
& $Gxx y.o l.o -o $OutExe
Write-Host "Linked executable ($OutExe)" -ForegroundColor Green

# Run with input file if exists
if (Test-Path input.c) {
    Write-Host "Running parser on input.c" -ForegroundColor Yellow
    if (Test-Path $OutExe) {
        # Use a single, stable execution path to avoid partial outputs
        # Read via stdin to avoid argv-related crashes
        Get-Content input.c | & .\$OutExe
    } else {
        Write-Host "Executable $OutExe not found; skipping run." -ForegroundColor Red
    }
} else {
    Write-Host "input.c not found; skipping run." -ForegroundColor Yellow
}

if (Test-Path 22101047_log.txt) {
    Write-Host "--- Log File (22101047_log.txt) ---" -ForegroundColor Magenta
    Get-Content 22101047_log.txt | Select-Object -First 60
}

Write-Host "Build complete." -ForegroundColor Cyan
