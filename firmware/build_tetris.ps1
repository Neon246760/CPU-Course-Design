param(
    [string]$RarsJar = 'D:\Applications\rars\rars_3897cfa.jar'
)

$ErrorActionPreference = 'Stop'
$sourcePath = Join-Path $PSScriptRoot 'tetris.S'
$rawPath = Join-Path $PSScriptRoot 'tetris.raw.mem'
$outputPath = Join-Path $PSScriptRoot 'tetris.mem'

if (-not (Test-Path -LiteralPath $RarsJar)) {
    throw "RARS jar not found: $RarsJar"
}

& java -jar $RarsJar nc a ae1 mc CompactTextAtZero dump .text HexText $rawPath $sourcePath
if ($LASTEXITCODE -ne 0) {
    throw "RARS assembly failed with exit code $LASTEXITCODE"
}

$program = @(Get-Content -LiteralPath $rawPath | Where-Object { $_ -match '^[0-9a-fA-F]{8}$' })
if ($program.Count -eq 0) {
    throw 'RARS produced an empty text image.'
}

function Test-CpuInstruction([uint32]$word) {
    $opcode = $word -band 0x7f
    $funct3 = ($word -shr 12) -band 7
    $funct7 = ($word -shr 25) -band 0x7f
    switch ($opcode) {
        0x33 {
            $key = ($funct7 -shl 3) -bor $funct3
            return $key -in @(0, 0x100, 7, 6, 4, 1, 5, 0x105, 2, 3)
        }
        0x13 { return $funct3 -in @(0, 7, 6, 4) }
        0x03 { return $funct3 -in @(2, 0, 4) }
        0x23 { return $funct3 -in @(2, 0) }
        0x63 { return $funct3 -in @(0, 1, 4, 5) }
        0x6f { return $true }
        0x67 { return $funct3 -eq 0 }
        0x37 { return $true }
        0x17 { return $true }
        0x73 { return ($word -eq 0x00000073) -or ($word -eq 0x30200073) }
        default { return $false }
    }
}

$unsupported = @()
for ($i = 0; $i -lt $program.Count; $i++) {
    $word = [Convert]::ToUInt32($program[$i], 16)
    if (-not (Test-CpuInstruction $word)) {
        $unsupported += "word $i ($($program[$i]))"
    }
}
if ($unsupported.Count -ne 0) {
    Remove-Item -LiteralPath $rawPath
    throw "RARS emitted instructions outside the implemented CPU subset: $($unsupported -join ', ')"
}

# The core resets at 0 and vectors traps to 0x100.  RARS 1.5 does not allow
# .org/.word in its text segment, so place those two architectural words here.
$image = [System.Collections.Generic.List[string]]::new()
$image.Add('2000006f')                 # jal x0, 0x200
for ($i = 1; $i -lt 64; $i++) { $image.Add('00000000') }
$image.Add('30200073')                 # mret at 0x100
for ($i = 65; $i -lt 128; $i++) { $image.Add('00000000') }
foreach ($word in $program) { $image.Add($word.ToLowerInvariant()) }

Set-Content -LiteralPath $outputPath -Value $image -Encoding ascii
Remove-Item -LiteralPath $rawPath
Write-Host "Generated $outputPath ($($image.Count) words); validated $($program.Count) CPU instructions"
