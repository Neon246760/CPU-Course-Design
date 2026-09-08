param(
    [string]$Vivado = 'D:\Applications\Xilinx\Vivado\2019.2\bin\vivado.bat',
    [string]$Python = 'D:\Applications\miniconda3\python.exe',
    [string]$Legacy = '',
    [switch]$UseSnapshot,
    [switch]$SkipImplementation,
    [int]$Repeats = 2
)
$ErrorActionPreference='Stop'
if ($Repeats -lt 1) { throw 'Repeats must be positive' }
$taskRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
Push-Location $taskRoot
try {
    New-Item -ItemType Directory -Force 'build/performance','docs/performance/raw' | Out-Null
    if ($UseSnapshot) { & $Python sim/performance/prepare.py --use-snapshot }
    elseif ($Legacy) { & $Python sim/performance/prepare.py --legacy $Legacy }
    else { & $Python sim/performance/prepare.py }
    if ($LASTEXITCODE -ne 0) { throw 'Benchmark preparation failed' }
    $baseline=@{}
    for ($taskRepeat=1; $taskRepeat -le $Repeats; $taskRepeat++) {
        & $Vivado -mode batch -source sim/performance/run.tcl -log build/performance/run.log -journal build/performance/run.jou
        if ($LASTEXITCODE -ne 0) { throw "Performance simulation failed in repeat $taskRepeat" }
        Copy-Item -LiteralPath docs/performance/raw/simulation.log -Destination "docs/performance/raw/run$taskRepeat.log" -Force
        $taskFiles=@(Get-ChildItem docs/performance/raw -Filter '*.csv')
        if ($taskFiles.Count -ne 84) { throw "Expected 42 results and 42 traces, found $($taskFiles.Count)" }
        foreach ($taskFile in $taskFiles) {
            $digest=(Get-FileHash -LiteralPath $taskFile.FullName -Algorithm SHA256).Hash
            if ($taskRepeat -eq 1) { $baseline[$taskFile.Name]=$digest }
            elseif ($baseline[$taskFile.Name] -ne $digest) { throw "Non-deterministic output: $($taskFile.Name)" }
        }
    }
    $metadata=@{ measured_at=(Get-Date).ToString('o'); repeats=$Repeats; cases_per_repeat=42; identical_outputs=$true; period_ns=10; vivado_path=$Vivado; output_sha256=$baseline }
    $metadata | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath docs/performance/run_metadata.json -Encoding utf8
    if (-not $SkipImplementation) {
        & $Vivado -mode batch -source sim/performance/implement_compare.tcl -log build/performance/implement_compare.log -journal build/performance/implement_compare.jou
        if ($LASTEXITCODE -ne 0) { throw 'Static implementation comparison failed' }
        & $Vivado -mode batch -source sim/performance/verify_clocks.tcl -log build/performance/verify_clocks.log -journal build/performance/verify_clocks.jou
        if ($LASTEXITCODE -ne 0) { throw 'Timing-closed operating-point verification failed' }
    }
    & $Python sim/performance/analyze.py
    if ($LASTEXITCODE -ne 0) { throw 'Performance analysis failed' }
} finally { Pop-Location }
