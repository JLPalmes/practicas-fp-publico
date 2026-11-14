param([Parameter(Mandatory=$true)][string]$OutputPath)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

function New-RoundedPath($x,$y,$w,$h,$r) {
    $path = New-Object Drawing.Drawing2D.GraphicsPath
    $d = 2 * $r
    $path.AddArc($x,$y,$d,$d,180,90)
    $path.AddArc(($x+$w-$d),$y,$d,$d,270,90)
    $path.AddArc(($x+$w-$d),($y+$h-$d),$d,$d,0,90)
    $path.AddArc($x,($y+$h-$d),$d,$d,90,90)
    $path.CloseFigure()
    return $path
}

$sizes = 16,20,24,32,40,48,64,128,256
$frames = foreach ($size in $sizes) {
    $bitmap = New-Object Drawing.Bitmap($size,$size)
    $g = [Drawing.Graphics]::FromImage($bitmap)
    $tile = New-RoundedPath 3 3 58 58 13
    $paper = New-RoundedPath 17 14 30 37 5
    $clip = New-RoundedPath 23 10 18 9 4
    $teal = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(14,89,82))
    $mint = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(166,229,206))
    $gold = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(247,174,62))
    $pen = New-Object Drawing.Pen($teal,4)
    $stream = New-Object IO.MemoryStream
    try {
        $g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.ScaleTransform($size/64.0,$size/64.0)
        $g.FillPath($teal,$tile)
        $g.FillPath([Drawing.Brushes]::White,$paper)
        $g.FillPath($mint,$clip)
        $pen.StartCap = $pen.EndCap = [Drawing.Drawing2D.LineCap]::Round
        $pen.LineJoin = [Drawing.Drawing2D.LineJoin]::Round
        $g.DrawLines($pen,[Drawing.PointF[]]@([Drawing.PointF]::new(24,31),[Drawing.PointF]::new(30,37),[Drawing.PointF]::new(40,25)))
        $g.FillRectangle($gold,24,42,16,4)
        $bitmap.Save($stream,[Drawing.Imaging.ImageFormat]::Png)
        ,$stream.ToArray()
    } finally {
        foreach ($item in $stream,$pen,$gold,$mint,$teal,$clip,$paper,$tile,$g,$bitmap) { $item.Dispose() }
    }
}

$writer = New-Object IO.BinaryWriter([IO.File]::Create($OutputPath))
try {
    $writer.Write([uint16]0)
    $writer.Write([uint16]1)
    $writer.Write([uint16]$sizes.Count)
    $offset = 6 + 16 * $sizes.Count
    for ($i=0; $i -lt $sizes.Count; $i++) {
        $dimension = [byte]($sizes[$i] % 256)
        $writer.Write($dimension)
        $writer.Write($dimension)
        $writer.Write([uint16]0)
        $writer.Write([uint16]1)
        $writer.Write([uint16]32)
        $writer.Write([uint32]$frames[$i].Length)
        $writer.Write([uint32]$offset)
        $offset += $frames[$i].Length
    }
    foreach ($frame in $frames) { $writer.Write([byte[]]$frame) }
} finally {
    $writer.Dispose()
}
