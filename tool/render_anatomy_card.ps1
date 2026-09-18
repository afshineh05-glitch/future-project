param(
  [Parameter(Mandatory=$true)][string]$ArtworkPath,
  [Parameter(Mandatory=$true)][string]$OutputPath,
  [Parameter(Mandatory=$true)][string]$ExerciseName,
  [Parameter(Mandatory=$true)][string[]]$PrimaryMuscles,
  [Parameter(Mandatory=$true)][string[]]$SecondaryMuscles
)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
if(Test-Path -LiteralPath $OutputPath){throw 'Card destination already exists.'}
$source=[Drawing.Image]::FromFile($ArtworkPath)
try{
  $card=[Drawing.Bitmap]::new(1024,1024,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
  try{
    $g=[Drawing.Graphics]::FromImage($card)
    try{
      $g.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::AntiAlias
      $g.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $g.Clear([Drawing.Color]::FromArgb(248,250,252))
      $white=[Drawing.SolidBrush]::new([Drawing.Color]::White)
      $border=[Drawing.Pen]::new([Drawing.Color]::FromArgb(222,228,236),2)
      $g.FillRectangle($white,32,32,960,960);$g.DrawRectangle($border,32,32,960,960)
      $titleFont=[Drawing.Font]::new('Segoe UI',36,[Drawing.FontStyle]::Bold)
      $labelFont=[Drawing.Font]::new('Segoe UI',18,[Drawing.FontStyle]::Bold)
      $bodyFont=[Drawing.Font]::new('Segoe UI',15,[Drawing.FontStyle]::Regular)
      $nameFont=[Drawing.Font]::new('Segoe UI',25,[Drawing.FontStyle]::Bold)
      $ink=[Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(25,35,50))
      $muted=[Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(80,92,110))
      $red=[Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(216,52,52))
      $orange=[Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(239,134,45))
      $center=[Drawing.StringFormat]::new();$center.Alignment=[Drawing.StringAlignment]::Center
      $g.DrawString('Muscles Worked',$titleFont,$ink,[Drawing.RectangleF]::new(64,58,500,55),$center)
      $g.FillEllipse($red,610,76,18,18);$g.DrawString('Primary',$bodyFont,$muted,637,73)
      $g.FillEllipse($orange,775,76,18,18);$g.DrawString('Secondary',$bodyFont,$muted,802,73)
      $g.DrawString('Front View',$labelFont,$muted,[Drawing.RectangleF]::new(100,132,350,35),$center)
      $g.DrawString('Back View',$labelFont,$muted,[Drawing.RectangleF]::new(574,132,350,35),$center)
      $g.DrawImage($source,[Drawing.Rectangle]::new(90,170,844,590))
      $g.FillRectangle($red,100,788,24,24);$g.DrawString('Primary Muscles',$labelFont,$ink,136,782)
      $g.FillRectangle($orange,540,788,24,24);$g.DrawString('Secondary Muscles',$labelFont,$ink,576,782)
      $primary=if($PrimaryMuscles.Count){$PrimaryMuscles -join ', '}else{'None'}
      $secondary=if($SecondaryMuscles.Count){$SecondaryMuscles -join ', '}else{'None'}
      $g.DrawString($primary,$bodyFont,$muted,[Drawing.RectangleF]::new(100,825,390,52))
      $g.DrawString($secondary,$bodyFont,$muted,[Drawing.RectangleF]::new(540,825,390,52))
      $g.DrawLine($border,80,890,944,890)
      $g.DrawString($ExerciseName,$nameFont,$ink,[Drawing.RectangleF]::new(70,916,884,45),$center)
      [IO.Directory]::CreateDirectory((Split-Path -Parent $OutputPath))|Out-Null
      $card.Save($OutputPath,[Drawing.Imaging.ImageFormat]::Png)
    }finally{$g.Dispose()}
  }finally{$card.Dispose()}
}finally{$source.Dispose()}
[ordered]@{
  title=$ExerciseName
  fixed_text=@('Muscles Worked','Primary','Secondary','Primary Muscles','Secondary Muscles','Front View','Back View')
  primary_muscles=@($PrimaryMuscles)
  secondary_muscles=@($SecondaryMuscles)
  output_path=$OutputPath
  width=1024
  height=1024
  text_source='deterministic_renderer_inputs'
}|ConvertTo-Json -Depth 5 -Compress
