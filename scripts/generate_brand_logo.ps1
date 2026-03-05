[CmdletBinding()]
param(
    [string]$OutputDir = "app/branding/logo"
)

$ErrorActionPreference = "Stop"

function New-RoundedRectPath {
    param(
        [float]$X,
        [float]$Y,
        [float]$Width,
        [float]$Height,
        [float]$Radius
    )

    $diameter = [Math]::Min($Radius * 2, [Math]::Min($Width, $Height))
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $rect = New-Object System.Drawing.RectangleF($X, $Y, $Width, $Height)

    if ($diameter -le 0) {
        $path.AddRectangle($rect)
        return $path
    }

    $arc = New-Object System.Drawing.RectangleF($rect.X, $rect.Y, $diameter, $diameter)
    $path.AddArc($arc, 180, 90)
    $arc.X = $rect.Right - $diameter
    $path.AddArc($arc, 270, 90)
    $arc.Y = $rect.Bottom - $diameter
    $path.AddArc($arc, 0, 90)
    $arc.X = $rect.X
    $path.AddArc($arc, 90, 90)
    $path.CloseFigure()
    return $path
}

function Write-LogoSvg {
    param([string]$Path)

    $svg = @'
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#0F1A3D"/>
      <stop offset="100%" stop-color="#1F315F"/>
    </linearGradient>
    <linearGradient id="accent" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0%" stop-color="#58E1D9"/>
      <stop offset="100%" stop-color="#79F0C9"/>
    </linearGradient>
  </defs>

  <rect x="64" y="64" width="896" height="896" rx="208" fill="url(#bg)"/>
  <rect x="224" y="248" width="576" height="132" rx="66" fill="url(#accent)"/>
  <rect x="452" y="318" width="120" height="404" rx="60" fill="#E9F6FF"/>

  <circle cx="512" cy="780" r="104" fill="#102654" opacity="0.9"/>
  <circle cx="512" cy="780" r="74" fill="#57E0DA"/>
  <circle cx="512" cy="780" r="32" fill="#D8FBFF"/>
</svg>
'@
    [System.IO.File]::WriteAllText($Path, $svg, [System.Text.Encoding]::UTF8)
}

function Write-LogoPng {
    param(
        [int]$Size,
        [string]$Path,
        [switch]$Monochrome
    )

    $bitmap = New-Object System.Drawing.Bitmap($Size, $Size)
    try {
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.Clear([System.Drawing.Color]::Transparent)

            $u = $Size / 1024.0
            $bgPath = New-RoundedRectPath -X (64 * $u) -Y (64 * $u) -Width (896 * $u) -Height (896 * $u) -Radius (208 * $u)

            if ($Monochrome) {
                $fill = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 255, 255, 255))
                $graphics.FillPath($fill, $bgPath)
                $fill.Dispose()

                $cutBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(0, 0, 0, 0))
                $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
                $barPath = New-RoundedRectPath -X (224 * $u) -Y (248 * $u) -Width (576 * $u) -Height (132 * $u) -Radius (66 * $u)
                $stemPath = New-RoundedRectPath -X (452 * $u) -Y (318 * $u) -Width (120 * $u) -Height (404 * $u) -Radius (60 * $u)
                $graphics.FillPath($cutBrush, $barPath)
                $graphics.FillPath($cutBrush, $stemPath)
                $graphics.FillEllipse(
                    $cutBrush,
                    [float](438 * $u),
                    [float](706 * $u),
                    [float](148 * $u),
                    [float](148 * $u)
                )
                $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
                $cutBrush.Dispose()
                $barPath.Dispose()
                $stemPath.Dispose()
            } else {
                $bgStart = New-Object System.Drawing.PointF -ArgumentList @([float](64 * $u), [float](64 * $u))
                $bgEnd = New-Object System.Drawing.PointF -ArgumentList @([float](960 * $u), [float](960 * $u))
                $bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush -ArgumentList @(
                    $bgStart,
                    $bgEnd,
                    [System.Drawing.ColorTranslator]::FromHtml("#0F1A3D"),
                    [System.Drawing.ColorTranslator]::FromHtml("#1F315F")
                )
                $graphics.FillPath($bgBrush, $bgPath)
                $bgBrush.Dispose()

                $barPath = New-RoundedRectPath -X (224 * $u) -Y (248 * $u) -Width (576 * $u) -Height (132 * $u) -Radius (66 * $u)
                $barStart = New-Object System.Drawing.PointF -ArgumentList @([float](224 * $u), [float](248 * $u))
                $barEnd = New-Object System.Drawing.PointF -ArgumentList @([float](800 * $u), [float](248 * $u))
                $barBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush -ArgumentList @(
                    $barStart,
                    $barEnd,
                    [System.Drawing.ColorTranslator]::FromHtml("#58E1D9"),
                    [System.Drawing.ColorTranslator]::FromHtml("#79F0C9")
                )
                $graphics.FillPath($barBrush, $barPath)
                $barBrush.Dispose()
                $barPath.Dispose()

                $stemPath = New-RoundedRectPath -X (452 * $u) -Y (318 * $u) -Width (120 * $u) -Height (404 * $u) -Radius (60 * $u)
                $stemBrush = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#E9F6FF"))
                $graphics.FillPath($stemBrush, $stemPath)
                $stemBrush.Dispose()
                $stemPath.Dispose()

                $c1 = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#102654"))
                $graphics.FillEllipse(
                    $c1,
                    [float](408 * $u),
                    [float](676 * $u),
                    [float](208 * $u),
                    [float](208 * $u)
                )
                $c1.Dispose()

                $c2 = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#57E0DA"))
                $graphics.FillEllipse(
                    $c2,
                    [float](438 * $u),
                    [float](706 * $u),
                    [float](148 * $u),
                    [float](148 * $u)
                )
                $c2.Dispose()

                $c3 = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#D8FBFF"))
                $graphics.FillEllipse(
                    $c3,
                    [float](480 * $u),
                    [float](748 * $u),
                    [float](64 * $u),
                    [float](64 * $u)
                )
                $c3.Dispose()
            }

            $bgPath.Dispose()
        } finally {
            $graphics.Dispose()
        }

        $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $bitmap.Dispose()
    }
}

Add-Type -AssemblyName System.Drawing
[System.IO.Directory]::CreateDirectory((Resolve-Path ".").Path + "\" + $OutputDir) | Out-Null

$resolvedOutput = Join-Path (Resolve-Path ".").Path $OutputDir
if (-not (Test-Path $resolvedOutput)) {
    New-Item -ItemType Directory -Path $resolvedOutput -Force | Out-Null
}

$svgPath = Join-Path $resolvedOutput "tapmacro_logo_master.svg"
$png1024Path = Join-Path $resolvedOutput "tapmacro_logo_1024.png"
$png512Path = Join-Path $resolvedOutput "tapmacro_logo_512.png"
$mono1024Path = Join-Path $resolvedOutput "tapmacro_logo_monochrome_1024.png"

Write-LogoSvg -Path $svgPath
Write-LogoPng -Size 1024 -Path $png1024Path
Write-LogoPng -Size 512 -Path $png512Path
Write-LogoPng -Size 1024 -Path $mono1024Path -Monochrome

Write-Host "Generated logo assets:" -ForegroundColor Green
Write-Host " - $svgPath"
Write-Host " - $png1024Path"
Write-Host " - $png512Path"
Write-Host " - $mono1024Path"
