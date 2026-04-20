# Create Placeholder Assets for Instana OTel Collector MSI Installer
# This script creates simple placeholder images until final UX designs are ready

Write-Host "Creating placeholder assets for MSI installer..." -ForegroundColor Cyan

# Load System.Drawing assembly
Add-Type -AssemblyName System.Drawing

# Create assets directory if it doesn't exist
$assetsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not (Test-Path $assetsDir)) {
    New-Item -ItemType Directory -Path $assetsDir -Force | Out-Null
}

# 1. Create 64x64 icon placeholder (PNG first, then convert to ICO)
Write-Host "Creating idot64.png..." -ForegroundColor Yellow
$iconBmp = New-Object System.Drawing.Bitmap(64, 64)
$graphics = [System.Drawing.Graphics]::FromImage($iconBmp)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.Clear([System.Drawing.Color]::FromArgb(0, 102, 204))  # Instana blue
$font = New-Object System.Drawing.Font("Arial", 14, [System.Drawing.FontStyle]::Bold)
$brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$format = New-Object System.Drawing.StringFormat
$format.Alignment = [System.Drawing.StringAlignment]::Center
$format.LineAlignment = [System.Drawing.StringAlignment]::Center
$graphics.DrawString("IDOT", $font, $brush, 32, 32, $format)
$iconBmp.Save("$assetsDir\idot64.png", [System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose()
$font.Dispose()
$brush.Dispose()
$format.Dispose()

# Convert PNG to ICO (create multiple sizes)
Write-Host "Creating idot64.ico..." -ForegroundColor Yellow
$icon16 = New-Object System.Drawing.Bitmap($iconBmp, 16, 16)
$icon32 = New-Object System.Drawing.Bitmap($iconBmp, 32, 32)
$icon48 = New-Object System.Drawing.Bitmap($iconBmp, 48, 48)

# Save as ICO (simplified - saves 64x64 only, but WiX will accept it)
$iconBmp.Save("$assetsDir\idot64.ico", [System.Drawing.Imaging.ImageFormat]::Icon)
$iconBmp.Dispose()
$icon16.Dispose()
$icon32.Dispose()
$icon48.Dispose()

# 2. Create banner placeholder (493 x 58 pixels)
Write-Host "Creating banner.bmp..." -ForegroundColor Yellow
$banner = New-Object System.Drawing.Bitmap(493, 58)
$graphics = [System.Drawing.Graphics]::FromImage($banner)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

# Background gradient
$rect = New-Object System.Drawing.Rectangle(0, 0, 493, 58)
$brush1 = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $rect,
    [System.Drawing.Color]::FromArgb(240, 248, 255),  # Light blue
    [System.Drawing.Color]::FromArgb(220, 235, 250),  # Slightly darker blue
    [System.Drawing.Drawing2D.LinearGradientMode]::Vertical
)
$graphics.FillRectangle($brush1, $rect)

# Draw text
$font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(0, 102, 204))
$graphics.DrawString("Instana OTel Collector", $font, $brush, 15, 15)

# Save as 24-bit BMP
$banner.Save("$assetsDir\banner.bmp", [System.Drawing.Imaging.ImageFormat]::Bmp)
$graphics.Dispose()
$font.Dispose()
$brush.Dispose()
$brush1.Dispose()
$banner.Dispose()

# 3. Create welcome image placeholder (493 x 312 pixels)
Write-Host "Creating welcome.bmp..." -ForegroundColor Yellow
$welcome = New-Object System.Drawing.Bitmap(493, 312)
$graphics = [System.Drawing.Graphics]::FromImage($welcome)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

# Background gradient
$rect = New-Object System.Drawing.Rectangle(0, 0, 493, 312)
$brush1 = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $rect,
    [System.Drawing.Color]::FromArgb(240, 248, 255),  # Light blue
    [System.Drawing.Color]::FromArgb(200, 225, 245),  # Darker blue
    [System.Drawing.Drawing2D.LinearGradientMode]::Vertical
)
$graphics.FillRectangle($brush1, $rect)

# Draw title
$font1 = New-Object System.Drawing.Font("Segoe UI", 32, [System.Drawing.FontStyle]::Bold)
$font2 = New-Object System.Drawing.Font("Segoe UI", 24)
$font3 = New-Object System.Drawing.Font("Segoe UI", 16)
$brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(0, 102, 204))
$format = New-Object System.Drawing.StringFormat
$format.Alignment = [System.Drawing.StringAlignment]::Center

$graphics.DrawString("Instana", $font1, $brush, 246, 80, $format)
$graphics.DrawString("OTel Collector", $font2, $brush, 246, 140, $format)
$graphics.DrawString("for Windows", $font3, $brush, 246, 190, $format)

# Save as 24-bit BMP
$welcome.Save("$assetsDir\welcome.bmp", [System.Drawing.Imaging.ImageFormat]::Bmp)
$graphics.Dispose()
$font1.Dispose()
$font2.Dispose()
$font3.Dispose()
$brush.Dispose()
$brush1.Dispose()
$format.Dispose()
$welcome.Dispose()

Write-Host ""
Write-Host "Placeholder assets created successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Created files:" -ForegroundColor Cyan
Write-Host "  - idot64.ico (64x64 icon)"
Write-Host "  - idot64.png (64x64 PNG)"
Write-Host "  - banner.bmp (493x58 banner)"
Write-Host "  - welcome.bmp (493x312 welcome screen)"
Write-Host ""
Write-Host "NOTE: These are placeholder assets." -ForegroundColor Yellow
Write-Host "Replace with final UX designs before production release." -ForegroundColor Yellow