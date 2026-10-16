param(
    [Parameter(Mandatory=$true)][string]$JdkBin,
    [string]$GameDir = 'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'
)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
New-Item -ItemType Directory -Force build,build/tests | Out-Null
& "$JdkBin\javac.exe" --release 17 -cp 'lib/*' -d build src/TreePatcher.java
if ($LASTEXITCODE) { throw 'Compilation failed' }
& "$JdkBin\jar.exe" "-J-Djava.io.tmpdir=$PSScriptRoot\build" --create --file build/patcher.jar -C build TreePatcher.class
if ($LASTEXITCODE) { throw 'Packaging failed' }
$java = Join-Path $GameDir 'jre64\bin\java.exe'
$output = Join-Path $PSScriptRoot ('build/tree-' + [guid]::NewGuid().ToString('N') + '.class')
& $java -cp 'build/patcher.jar;lib/*' TreePatcher "$GameDir\projectzomboid.jar" $output
if ($LASTEXITCODE) { throw 'Patching failed' }
$fixtures = Get-ChildItem tests/fixtures -Recurse -Filter '*.java' | ForEach-Object FullName
& "$JdkBin\javac.exe" --release 17 -cp 'lib/*' -d build/tests tests/TreeBehaviorTest.java $fixtures
if ($LASTEXITCODE) { throw 'Test compilation failed' }
& $java -Xverify:all -cp 'build/tests;lib/*' TreeBehaviorTest $output build/tests
if ($LASTEXITCODE) { throw 'Behavior tests failed' }
Copy-Item -LiteralPath build/patcher.jar -Destination patcher.jar -Force
Write-Output 'Build and nine behavior checks passed.'
