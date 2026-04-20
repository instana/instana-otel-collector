#Requires -Version 5.1
<#
.SYNOPSIS
    Build Windows MSI installer for Instana OTel Collector

.DESCRIPTION
    This script builds a complete MSI installer package using WiX Toolset.
    It compiles the collector binary, stages files, and creates the MSI.

.PARAMETER Version
    Version number for the package (e.g., "1.316.0")

.PARAMETER SkipBuild
    Skip building the Go binary (use existing binary)

.PARAMETER Verbose
    Enable verbose output

.PARAMETER OutputDir
    Output directory for the MSI file (default: dist)

.EXAMPLE
    .\build-msi.ps1 -Version "1.316.0"

.EXAMPLE
    .\build-msi.ps1 -Version "1.316.0" -Verbose -OutputDir "release"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Version,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipBuild,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputDir = "dist"
)

# Script configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Compute MSI-compatible version (major.0.minor) because MSI requires minor < 256
# e.g. 1.313.0 -> 1.0.313
$versionParts = $Version -split '\.'
$MsiVersion = "$($versionParts[0]).0.$($versionParts[1])"

# Paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Resolve-Path (Join-Path $ScriptDir "..\..\..") 
$InstallerDir = Join-Path $ScriptDir "idot-windows-installer"
$StagingDir = Join-Path $RootDir "dist\staging"
$OutputPath = Join-Path $RootDir $OutputDir
# Functions
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN"  { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-Prerequisites {
    Write-Log "Checking prerequisites..."
    
    # Detect WiX version
    $script:WixVersion = $null
    $script:WixCommand = $null
    
    # Check for WiX 4.0 (new CLI)
    try {
        $wixOutput = & wix --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            $script:WixVersion = 4
            $script:WixCommand = "wix"
            Write-Log "Found WiX Toolset 4.0: $wixOutput" "SUCCESS"
        }
    } catch {
        # WiX 4.0 not found, continue to check for 3.x
    }
    
    # Check for WiX 3.x (classic toolset)
    if (-not $script:WixVersion) {
        if ($env:WIX) {
            $wixBin = Join-Path $env:WIX "bin"
            $requiredTools = @("heat.exe", "candle.exe", "light.exe")
            $allFound = $true
            
            foreach ($tool in $requiredTools) {
                $toolPath = Join-Path $wixBin $tool
                if (-not (Test-Path $toolPath)) {
                    $allFound = $false
                    break
                }
            }
            
            if ($allFound) {
                $script:WixVersion = 3
                $script:WixCommand = $wixBin
                Write-Log "Found WiX Toolset 3.x at: $wixBin" "SUCCESS"
            }
        }
    }
    
    # If no WiX found, error out
    if (-not $script:WixVersion) {
        Write-Log "WiX Toolset not found!" "ERROR"
        Write-Log "Please install WiX 4.0 from: https://github.com/wixtoolset/wix4/releases" "ERROR"
        Write-Log "Or WiX 3.11 from: https://wixtoolset.org/releases/" "ERROR"
        exit 1
    }
    
    # Check Go
    if (-not $SkipBuild) {
        try {
            $goVersion = & go version 2>&1
            Write-Log "Found Go: $goVersion"
        } catch {
            Write-Log "Go not found. Please install Go 1.21 or later" "ERROR"
            exit 1
        }
    }
    
    Write-Log "All prerequisites satisfied" "SUCCESS"
}

function Build-Collector {
    if ($SkipBuild) {
        Write-Log "Skipping collector build (using existing binary)"
        return
    }
    
    Write-Log "Building Instana OTel Collector for Windows..."
    
    $collectorDir = Join-Path $RootDir "cmd\idot_win"
    Push-Location $collectorDir
    
    try {
        $env:GOOS = "windows"
        $env:GOARCH = "amd64"
        $env:CGO_ENABLED = "0"

        & go build -trimpath -o "instana-otelcol.exe" -ldflags="-s -w" 2>&1 | Write-Verbose
        
        if ($LASTEXITCODE -ne 0) {
            throw "Go build failed with exit code $LASTEXITCODE"
        }
        
        Write-Log "Collector binary built successfully" "SUCCESS"
    } finally {
        Pop-Location
    }
}

function New-StagingDirectory {
    Write-Log "Creating staging directory..."
    
    # Clean and create staging directory
    if (Test-Path $StagingDir) {
        Remove-Item $StagingDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $StagingDir -Force | Out-Null
    
    # Create directory structure
    $dirs = @(
        "bin",
        "config",
        "logs"
    )
    
    foreach ($dir in $dirs) {
        New-Item -ItemType Directory -Path (Join-Path $StagingDir $dir) -Force | Out-Null
    }
    
    Write-Log "Staging directory created: $StagingDir"
}

function Test-Assets {
    Write-Log "Checking for UI assets..."
    
    $assetsDir = Join-Path $InstallerDir "assets"
    $requiredAssets = @("idot64.ico", "idot64.png", "banner.bmp", "welcome.bmp")
    $missingAssets = @()
    
    foreach ($asset in $requiredAssets) {
        $assetPath = Join-Path $assetsDir $asset
        if (-not (Test-Path $assetPath)) {
            $missingAssets += $asset
        }
    }
    
    if ($missingAssets.Count -gt 0) {
        Write-Log "Missing UI assets: $($missingAssets -join ', ')" "WARN"
        Write-Log "Creating placeholder assets..." "WARN"
        
        $placeholderScript = Join-Path $assetsDir "create-placeholders.ps1"
        if (Test-Path $placeholderScript) {
            & $placeholderScript
            Write-Log "Placeholder assets created" "SUCCESS"
        } else {
            Write-Log "Placeholder script not found. MSI build may fail." "ERROR"
            Write-Log "Please create assets manually or run: $placeholderScript" "ERROR"
        }
    } else {
        Write-Log "All UI assets present" "SUCCESS"
    }
}

function Copy-CollectorFiles {
    Write-Log "Copying collector files to staging..."
    
    # Copy binary
    $binarySource = Join-Path $RootDir "cmd\idot_win\instana-otelcol.exe"
    $binaryDest = Join-Path $StagingDir "bin\instana-otelcol.exe"
    Copy-Item $binarySource $binaryDest -Force
    Write-Log "  Copied: instana-otelcol.exe"
    
    # Copy configuration
    $configSource = Join-Path $RootDir "config\windows\config.yaml"
    $configDest = Join-Path $StagingDir "config\config.yaml"
    Copy-Item $configSource $configDest -Force
    Write-Log "  Copied: config.yaml"
    
    # Create VERSION file
    $versionFile = Join-Path $StagingDir "VERSION"
    Set-Content -Path $versionFile -Value $Version
    Write-Log "  Created: VERSION"
    
    Write-Log "All files copied successfully" "SUCCESS"
}

function Build-MSI {
    Write-Log "Building MSI installer using WiX $script:WixVersion..."
    
    Push-Location $InstallerDir
    
    try {
        if ($script:WixVersion -eq 4) {
            Build-MSI-WiX4
        } else {
            Build-MSI-WiX3
        }
    } finally {
        Pop-Location
    }
}

function Build-MSI-WiX4 {
    Write-Log "Using WiX 4.0 build process..."
    
    # Step 1: Generate file structure
    Write-Log "  [1/2] Generating file structure..."
    $filesWxs = Join-Path $InstallerDir "Files.wxs"
    
    & wix extension add WixToolset.UI.wixext 2>&1 | Write-Verbose
    & wix extension add WixToolset.Util.wixext 2>&1 | Write-Verbose
    
    & wix build `
        -d Version=$Version `
        -d MsiVersion=$MsiVersion `
        -d SourceDir=$StagingDir `
        -ext WixToolset.UI.wixext `
        -ext WixToolset.Util.wixext `
        -culture en-US `
        -loc (Join-Path $InstallerDir "en-US.wxl") `
        -out (Join-Path $OutputPath "instana-otel-collector-$Version.msi") `
        (Join-Path $InstallerDir "InstanaIdot.wxs") `
        (Join-Path $InstallerDir "InstanaIdotUI.wxs") 2>&1 | Write-Verbose
    
    if ($LASTEXITCODE -ne 0) {
        throw "WiX build failed with exit code $LASTEXITCODE"
    }
    
    $msiName = "instana-otel-collector-$Version.msi"
    $msiPath = Join-Path $OutputPath $msiName
    
    # Generate checksum
    Write-Log "Generating SHA256 checksum..."
    $hash = Get-FileHash -Path $msiPath -Algorithm SHA256
    $checksumPath = "$msiPath.sha256"
    "$($hash.Hash.ToLower())  $msiName" | Set-Content -Path $checksumPath
    
    Write-Log "MSI installer created successfully" "SUCCESS"
    Write-Log "  MSI: $msiPath"
    Write-Log "  Checksum: $checksumPath"
    
    return $msiPath
}

function Build-MSI-WiX3 {
    Write-Log "Using WiX 3.x build process..."
    
    $wixBin = $script:WixCommand
    $heatExe = Join-Path $wixBin "heat.exe"
    $candleExe = Join-Path $wixBin "candle.exe"
    $lightExe = Join-Path $wixBin "light.exe"
    
    # Step 1: Generate file structure with Heat
    Write-Log "  [1/3] Generating file structure with Heat..."
    $filesWxs = Join-Path $InstallerDir "Files.wxs"
    
    & $heatExe dir $StagingDir `
        -cg InstanaCollectorFiles `
        -dr INSTALLFOLDER `
        -platform x64 `
        -gg -sfrag -srd -sreg `
        -out $filesWxs 2>&1 | Write-Verbose

    if ($LASTEXITCODE -ne 0) {
        throw "Heat.exe failed with exit code $LASTEXITCODE"
    }

    # Remove files explicitly defined in InstanaIdot.wxs to avoid duplicate component errors
    # instana-otelcol.exe: KeyPath for service component (must be declared there for correct ImagePath)
    # config.yaml: declared as CollectorConfig in InstanaIdot.wxs
    (Get-Content $filesWxs) | Where-Object { $_ -notmatch 'instana-otelcol\.exe' -and $_ -notmatch 'config\.yaml' } | Set-Content $filesWxs

    # Step 2: Compile WXS files with Candle
    Write-Log "  [2/3] Compiling WXS files with Candle..."
    
    $wixobjDir = Join-Path $OutputPath "wixobj"
    if (-not (Test-Path $wixobjDir)) {
        New-Item -ItemType Directory -Path $wixobjDir -Force | Out-Null
    }
    
    $wxsFiles = @(
        @{Source = "InstanaIdot.wxs"; Output = "InstanaIdot.wixobj"},
        @{Source = "InstanaIdotUI.wxs"; Output = "InstanaIdotUI.wixobj"},
        @{Source = "Files.wxs"; Output = "Files.wixobj"}
    )
    
    foreach ($wxs in $wxsFiles) {
        $wxsPath = Join-Path $InstallerDir $wxs.Source
        if (Test-Path $wxsPath) {
            $wixobjPath = Join-Path $wixobjDir $wxs.Output
            
            & $candleExe $wxsPath `
                "-dVersion=$Version" `
                "-dMsiVersion=$MsiVersion" `
                "-dSourceDir=$StagingDir" `
                -out $wixobjPath `
                -ext WixUIExtension `
                -ext WixUtilExtension 2>&1 | Write-Verbose
            
            if ($LASTEXITCODE -ne 0) {
                throw "Candle.exe failed for $($wxs.Source) with exit code $LASTEXITCODE"
            }
        }
    }
    
    # Step 3: Link with Light to create MSI
    Write-Log "  [3/3] Linking with Light to create MSI..."
    
    $msiName = "instana-otel-collector-$Version.msi"
    $msiPath = Join-Path $OutputPath $msiName
    
    $wixobjFiles = Get-ChildItem -Path $wixobjDir -Filter "*.wixobj" | Select-Object -ExpandProperty FullName
    
    & $lightExe $wixobjFiles `
        -out $msiPath `
        -b $StagingDir `
        -ext WixUIExtension `
        -ext WixUtilExtension `
        -cultures:en-US `
        -loc (Join-Path $InstallerDir "en-US.wxl") `
        -sice:ICE03 `
        -sice:ICE18 `
        -sice:ICE61 `
        -sice:ICE80 2>&1 | Write-Verbose
    
    if ($LASTEXITCODE -ne 0) {
        throw "Light.exe failed with exit code $LASTEXITCODE"
    }
    
    # Generate checksum
    Write-Log "Generating SHA256 checksum..."
    $hash = Get-FileHash -Path $msiPath -Algorithm SHA256
    $checksumPath = "$msiPath.sha256"
    "$($hash.Hash.ToLower())  $msiName" | Set-Content -Path $checksumPath
    
    Write-Log "MSI installer created successfully" "SUCCESS"
    Write-Log "  MSI: $msiPath"
    Write-Log "  Checksum: $checksumPath"
    
    # Cleanup
    Write-Log "Cleaning up temporary files..."
    Remove-Item $filesWxs -Force -ErrorAction SilentlyContinue
    Remove-Item $wixobjDir -Recurse -Force -ErrorAction SilentlyContinue
    
    return $msiPath
}

# Main execution
try {
    Write-Log "========================================" 
    Write-Log "Building Instana OTel Collector MSI v$Version"
    Write-Log "========================================"
    Write-Log ""
    
    Test-Prerequisites
    Test-Assets
    Build-Collector
    New-StagingDirectory
    Copy-CollectorFiles
    $msiPath = Build-MSI
    
    Write-Log ""
    Write-Log "========================================" "SUCCESS"
    Write-Log "Build Complete!" "SUCCESS"
    Write-Log "========================================" "SUCCESS"
    Write-Log "MSI Installer: $msiPath" "SUCCESS"
    Write-Log ""
    
    exit 0
    
} catch {
    Write-Log "Build failed: $_" "ERROR"
    Write-Log $_.ScriptStackTrace "ERROR"
    exit 1
}