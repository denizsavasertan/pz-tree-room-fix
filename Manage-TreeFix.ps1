param(
    [ValidateSet('Status','Install','Remove')][string]$Action = 'Status',
    [string]$GameDir = 'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid',
    [string]$JavaExe = ''
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$GameDir = (Resolve-Path -LiteralPath $GameDir).Path
$jar = Join-Path $GameDir 'projectzomboid.jar'
$target = Join-Path $GameDir 'zombie\iso\objects\IsoTree.class'
$stateDir = Join-Path $GameDir '.tree-room-null-fix'
$state = Join-Path $stateDir 'state.json'
if (!$JavaExe) { $JavaExe = Join-Path $GameDir 'jre64\bin\java.exe' }

function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToLowerInvariant() }
    finally { $sha.Dispose(); $stream.Dispose() }
}
function Assert-PlainPath([string]$Path) {
    $itemPath = $Path
    while ($itemPath) {
        if (Test-Path -LiteralPath $itemPath) {
            if ((Get-Item -LiteralPath $itemPath -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Refusing linked path: $itemPath"
            }
        }
        $itemPath = Split-Path -Parent $itemPath
    }
}
Assert-PlainPath $target
Assert-PlainPath $state
Assert-PlainPath $jar
if (!(Test-Path -LiteralPath $jar -PathType Leaf)) { throw 'Game archive not found.' }
if ($Action -eq 'Status') {
    if (Test-Path -LiteralPath $state) {
        $saved = Get-Content -LiteralPath $state -Raw | ConvertFrom-Json
        if (!(Test-Path -LiteralPath $target)) { Write-Output 'State exists but patch is missing. Run Remove to clear state.'; exit 0 }
        if ((Get-Sha256 $target) -ne $saved.patchHash) { throw 'Patch differs from installed version. No changes made.' }
        if ((Get-Sha256 $jar) -ne $saved.jarHash) {
            Write-Warning 'Game archive changed since installation. Remove this override before playing; do not reuse it after an update.'
        } else { Write-Output 'Tree room fallback installed; file and game hashes match.' }
    } elseif (Test-Path -LiteralPath $target) { Write-Output 'An unmanaged IsoTree override exists. Installation will refuse to replace it.' }
    else { Write-Output 'Not installed.' }
    exit 0
}
if (Get-Process -Name ProjectZomboid64,ProjectZomboid64ShowConsole,java,javaw -ErrorAction SilentlyContinue) {
    throw 'Close Project Zomboid and Java processes before installing or removing the patch.'
}
if ($Action -eq 'Remove') {
    if (!(Test-Path -LiteralPath $state)) { throw 'No managed installation. Nothing removed.' }
    $saved = Get-Content -LiteralPath $state -Raw | ConvertFrom-Json
    if (Test-Path -LiteralPath $target) {
        if ((Get-Sha256 $target) -ne $saved.patchHash) { throw 'Override was modified by another tool. Nothing removed.' }
        Remove-Item -LiteralPath $target
    }
    Remove-Item -LiteralPath $state
    Write-Output 'Patch removed. The untouched game archive supplies the original class again.'
    exit 0
}
if ((Test-Path -LiteralPath $target) -or (Test-Path -LiteralPath $state)) { throw 'Existing override or installation state. Run Status; do not overwrite.' }
if (!(Test-Path -LiteralPath $JavaExe -PathType Leaf)) { throw 'Java executable not found.' }
$temp = Join-Path ([IO.Path]::GetTempPath()) ('tree-room-fix-' + [guid]::NewGuid().ToString('N') + '.class')
$staged = "$target.tree-room-new"
Assert-PlainPath $staged
if (Test-Path -LiteralPath $staged) { throw 'Staged patch already exists; inspect it before retrying.' }
try {
    & $JavaExe -cp "$PSScriptRoot\patcher.jar;$PSScriptRoot\lib\*" TreePatcher $jar $temp
    if ($LASTEXITCODE -ne 0) { throw 'Compatibility check or patch generation failed. Game files unchanged.' }
    $record = @{
        patchHash = (Get-Sha256 $temp)
        jarHash = (Get-Sha256 $jar)
        originalClassHash = '48b8b8aa39dbbb534700c2e979c6b38097cdcfab2938786f1b56166e510f396a'
    }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target),$stateDir | Out-Null
    Copy-Item -LiteralPath $temp -Destination $staged
    $record | ConvertTo-Json | Set-Content -LiteralPath $state -Encoding UTF8
    Move-Item -LiteralPath $staged -Destination $target
    Write-Output 'Installed. Original projectzomboid.jar was not modified. Run Status before playing after any update.'
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp }
}

