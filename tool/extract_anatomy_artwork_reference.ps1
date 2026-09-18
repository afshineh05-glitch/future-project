param(
  [string]$SourcePath='assets/exercises/anatomy/templates/female_neutral_anatomy_master_v3.png',
  [string]$OutputPath='assets/exercises/anatomy/templates/female_neutral_anatomy_artwork_reference_v3.png',
  [string]$ExpectedSourceSha256='08B6D1124802BD7CDBDA31107A3C4D68990FF5CC2AFD354F2F07F936998C5057'
)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$sourceFull=Join-Path $root $SourcePath;$outputFull=Join-Path $root $OutputPath
if(-not(Test-Path -LiteralPath $sourceFull)){throw 'Locked female V3 master is missing.'}
if((Get-FileHash -Algorithm SHA256 -LiteralPath $sourceFull).Hash -ne $ExpectedSourceSha256){throw 'Locked female V3 master hash mismatch.'}
if(Test-Path -LiteralPath $outputFull){throw 'Artwork reference destination already exists.'}
Add-Type -AssemblyName System.Drawing
$source=[Drawing.Bitmap]::new($sourceFull)
try{
  if($source.Width -ne 1254 -or $source.Height -ne 1254){throw 'Unexpected female V3 master dimensions.'}
  $output=[Drawing.Bitmap]::new(1024,1024,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
  try{
    $g=[Drawing.Graphics]::FromImage($output)
    try{
      $g.Clear([Drawing.Color]::White);$g.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $sourceRect=[Drawing.Rectangle]::new(48,150,786,838)
      $destinationRect=[Drawing.Rectangle]::new(32,32,960,960)
      $g.DrawImage($source,$destinationRect,$sourceRect,[Drawing.GraphicsUnit]::Pixel)
    }finally{$g.Dispose()}
    # Remove pale blue panel rules while retaining grayscale anatomy.
    for($y=0;$y -lt $output.Height;$y++){for($x=0;$x -lt $output.Width;$x++){
      $p=$output.GetPixel($x,$y)
      if($p.R -gt 185 -and $p.G -gt $p.R -and $p.B -gt ($p.R+8)){$output.SetPixel($x,$y,[Drawing.Color]::White)}
    }}
    [IO.Directory]::CreateDirectory((Split-Path -Parent $outputFull))|Out-Null
    $stream=[IO.File]::Open($outputFull,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try{$output.Save($stream,[Drawing.Imaging.ImageFormat]::Png)}finally{$stream.Dispose()}
  }finally{$output.Dispose()}
}finally{$source.Dispose()}
$hash=(Get-FileHash -Algorithm SHA256 -LiteralPath $outputFull).Hash
[ordered]@{path=$OutputPath;sha256=$hash;width=1024;height=1024;source_path=$SourcePath;source_sha256=$ExpectedSourceSha256}|ConvertTo-Json -Compress
