param([double]$MaximumEstimatedSpendUsd=0.02)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$provider=Join-Path $PSScriptRoot 'openai_anatomy_image_provider.ps1'
$card=Join-Path $root 'assets/exercises/anatomy/templates/male_anatomy_master_v1.png'
$output=Join-Path $root 'assets/exercises/anatomy/templates/male_neutral_anatomy_master_v1.png'
$expected='3C44E6F8ADB17B17D544E82EF33C72DD0FC799A35853294FD0923654371D391E'
$estimatedCost=0.009
if($estimatedCost -gt $MaximumEstimatedSpendUsd){throw 'Neutral-master estimated spend exceeds guard.'}
if(Test-Path -LiteralPath $output){throw 'Neutral-master candidate already exists; overwrite forbidden.'}
$actual=(Get-FileHash -LiteralPath $card -Algorithm SHA256).Hash
if($actual -ne $expected){throw "Male card-template hash mismatch: expected=$expected actual=$actual"}
$prompt=@"
Create artwork only: exactly one male front-view and one male back-view clinical anatomical
mannequin on a pure white background, matching the supplied reference body's proportions,
pose, clinical illustration style, and front/back arrangement. Remove the entire inherited
card UI, all text, icons, borders, labels, exercise title, and every inherited red or orange
muscle highlight. Every muscle must be neutral grayscale. Do not add any exercise-specific
highlight. No clothing is required, but render a professional non-explicit medical mannequin
with smooth neutral pelvic anatomy and no intimate anatomical detail. No sexual presentation.
No typography. No symbols. No colored pixels. Complete uncropped bodies, medically plausible.
"@
$request=@{output_path=$output;prompt=$prompt;canonical_id='male_neutral_anatomy_master_v1';sex='male';reference_image_path=$card;template_sha256=$expected}|ConvertTo-Json -Compress
& $provider -RequestJson $request
if($LASTEXITCODE -ne 0){throw "neutral_master_provider_exit_$LASTEXITCODE"}
Add-Type -AssemblyName System.Drawing
$image=[Drawing.Bitmap]::new($output)
try{
  if($image.Width -ne 1024 -or $image.Height -ne 1024){throw "invalid_dimensions:$($image.Width)x$($image.Height)"}
  $red=0;$orange=0;$light=0;$samples=0
  for($y=0;$y -lt $image.Height;$y++){for($x=0;$x -lt $image.Width;$x++){
    $p=$image.GetPixel($x,$y);$samples++
    if($p.R -gt 235 -and $p.G -gt 235 -and $p.B -gt 235){$light++}
    if($p.R -gt 145 -and $p.R -gt ($p.G*1.35) -and $p.R -gt ($p.B*1.35)){$red++}
    if($p.R -gt 160 -and $p.G -gt 60 -and $p.G -lt 190 -and $p.B -lt 110){$orange++}
  }}
  $lightRatio=$light/$samples
  if($red -gt 0 -or $orange -gt 0){throw "colored_highlight_pixels:red=$red orange=$orange"}
  if($lightRatio -lt .45){throw "background_not_white:light_ratio=$lightRatio"}
  [ordered]@{status='pending_template_review';path='assets/exercises/anatomy/templates/male_neutral_anatomy_master_v1.png';width=$image.Width;height=$image.Height;red_pixels=$red;orange_pixels=$orange;light_background_ratio=$lightRatio;estimated_cost_usd=$estimatedCost}|ConvertTo-Json -Compress
}finally{$image.Dispose()}
