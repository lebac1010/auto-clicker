[CmdletBinding()]
param(
    [switch]$SkipAnalyze,
    [switch]$SkipTests,
    [switch]$SkipClean,
    [switch]$ForceRegenerateKeystore,
    [string]$Alias = "upload",
    [int]$ValidityDays = 10000,
    [string]$DefaultDName = "CN=TapMacro, OU=Mobile, O=TapMacro, L=Bangkok, ST=Bangkok, C=TH"
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Get-PlainSecret {
    param([string]$Prompt)
    $secure = Read-Host -Prompt $Prompt -AsSecureString
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}

function Find-Keytool {
    $keytoolCmd = Get-Command keytool -ErrorAction SilentlyContinue
    if ($null -ne $keytoolCmd) {
        return $keytoolCmd.Source
    }
    if (-not [string]::IsNullOrWhiteSpace($env:JAVA_HOME)) {
        $candidate = Join-Path $env:JAVA_HOME "bin\keytool.exe"
        if (Test-Path $candidate) {
            return $candidate
        }
    }
    throw "Khong tim thay keytool. Cai JDK/Android Studio va dam bao keytool co trong PATH hoac JAVA_HOME."
}

function Run-Checked {
    param(
        [string]$Label,
        [scriptblock]$Command
    )
    Write-Step $Label
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$Label that bai (exit code: $LASTEXITCODE)."
    }
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$appDir = Join-Path $repoRoot "app"
$androidDir = Join-Path $appDir "android"
$keystorePath = Join-Path $androidDir "upload-keystore.jks"
$keyPropertiesPath = Join-Path $androidDir "key.properties"

if (-not (Test-Path $appDir)) {
    throw "Khong tim thay thu muc app: $appDir"
}

$keytool = Find-Keytool

$needGenerateKeystore = $ForceRegenerateKeystore -or -not (Test-Path $keystorePath)
if (-not $needGenerateKeystore) {
    $reuse = Read-Host "Tim thay keystore hien tai ($keystorePath). Tiep tuc dung file nay? [Y/n]"
    if (-not [string]::IsNullOrWhiteSpace($reuse) -and $reuse.Trim().ToLowerInvariant() -eq "n") {
        $needGenerateKeystore = $true
    }
}

$storePassword = Get-PlainSecret "Nhap store password"
$keyPassword = Get-PlainSecret "Nhap key password (Enter de dung cung store password)"
if ([string]::IsNullOrWhiteSpace($keyPassword)) {
    $keyPassword = $storePassword
}

$aliasInput = Read-Host "Nhap key alias (Enter de dung '$Alias')"
if (-not [string]::IsNullOrWhiteSpace($aliasInput)) {
    $Alias = $aliasInput.Trim()
}

if ($needGenerateKeystore) {
    $dName = $DefaultDName
    $dNameInput = Read-Host "Nhap DName certificate (Enter de dung mac dinh)"
    if (-not [string]::IsNullOrWhiteSpace($dNameInput)) {
        $dName = $dNameInput.Trim()
    }

    Run-Checked "Tao upload keystore" {
        & $keytool `
            -genkeypair `
            -v `
            -keystore $keystorePath `
            -storetype JKS `
            -keyalg RSA `
            -keysize 2048 `
            -validity $ValidityDays `
            -alias $Alias `
            -storepass $storePassword `
            -keypass $keyPassword `
            -dname $dName
    }
} else {
    Write-Step "Bo qua tao keystore, su dung file co san."
}

$keyPropertiesContent = @(
    "storeFile=$(Split-Path $keystorePath -Leaf)"
    "storePassword=$storePassword"
    "keyAlias=$Alias"
    "keyPassword=$keyPassword"
) -join [Environment]::NewLine

Set-Content -Path $keyPropertiesPath -Value $keyPropertiesContent -Encoding Ascii
Write-Step "Da tao/cap nhat key.properties"

Push-Location $appDir
try {
    if (-not $SkipClean) {
        Run-Checked "flutter clean" { flutter clean }
    }
    Run-Checked "flutter pub get" { flutter pub get }

    if (-not $SkipAnalyze) {
        Run-Checked "flutter analyze" { flutter analyze }
    }

    if (-not $SkipTests) {
        Run-Checked "flutter test" { flutter test }
    }

    Run-Checked "flutter build appbundle --release" { flutter build appbundle --release }
} finally {
    Pop-Location
}

$aabPath = Join-Path $appDir "build\app\outputs\bundle\release\app-release.aab"
if (Test-Path $aabPath) {
    Write-Host ""
    Write-Host "SUCCESS: AAB san sang de upload." -ForegroundColor Green
    Write-Host "File: $aabPath"
} else {
    throw "Build thanh cong nhung khong tim thay artifact: $aabPath"
}
