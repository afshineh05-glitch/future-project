$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
function Assert($Condition,[string]$Message){if(-not $Condition){throw $Message}}
$master=Join-Path $root 'assets/exercises/anatomy/templates/male_neutral_anatomy_master_v4.png'
$reference=$master
Assert ((Get-FileHash -Algorithm SHA256 $master).Hash -eq '5FFE7590F204E01A1A1EC95B5D2312404B32A1FA59D2464E254D453254B95BD9') 'Male V4 master hash mismatch'
$agent=Get-Content -Raw (Join-Path $root 'tool/anatomy_production_agent.ps1')
$promptBlock=$agent.Substring($agent.IndexOf('function Get-Prompt'),$agent.IndexOf('function Get-VersionedPaths')-$agent.IndexOf('function Get-Prompt'))
foreach($cardText in @('Muscles Worked','Primary Muscles','Secondary Muscles','Front View','Back View','Barbell Bench Press')){Assert (-not $promptBlock.Contains($cardText)) "Provider prompt contains card text: $cardText"}
Assert ($agent.Contains('reference_image_path=$maleArtworkReferencePath')) 'Provider does not receive cropped male artwork reference'
Assert ($agent.Contains("Where-Object { `$_.sex -eq 'male'")) 'Production selection is not male-only'
$validateIndex=$agent.IndexOf('$artValidationText=& $validatorPath');$renderIndex=$agent.IndexOf('$rendererText=& $rendererPath')
Assert ($validateIndex -gt 0 -and $renderIndex -gt $validateIndex) 'Renderer is not gated behind artwork validation'
$catalog=Get-Content -Raw (Join-Path $root 'assets/data/exercise_library/movekit_complete_catalog.json')|ConvertFrom-Json
$bench=$catalog.exercises|Where-Object canonical_id -eq 'mu_ex_barbell_bench_press'|Select-Object -First 1
Assert ($bench.display_name -ceq 'Barbell Bench Press') 'Catalog title mismatch';Assert ((@($bench.primary_muscles)-join ',') -ceq 'chest') 'Catalog primary mismatch';Assert ((@($bench.secondary_muscles)-join ',') -ceq 'anterior_deltoids,triceps') 'Catalog secondary mismatch'
$testDir=Join-Path $root 'build/anatomy_pipeline_test';[IO.Directory]::CreateDirectory($testDir)|Out-Null
$card=Join-Path $testDir 'renderer_card.png';if(Test-Path $card){Remove-Item -LiteralPath $card}
$rendererJson=& (Join-Path $root 'tool/render_anatomy_card.ps1') -ArtworkPath $reference -OutputPath $card -ExerciseName $bench.display_name -PrimaryMuscles @($bench.primary_muscles) -SecondaryMuscles @($bench.secondary_muscles)|ConvertFrom-Json
Assert (Test-Path $card) 'Renderer did not produce card';Assert ($rendererJson.title -ceq 'Barbell Bench Press') 'Title can disappear';Assert (($rendererJson.primary_muscles-join ',') -ceq 'chest') 'Primary labels not from catalog';Assert (($rendererJson.secondary_muscles-join ',') -ceq 'anterior_deltoids,triceps') 'Secondary labels not from catalog'
foreach($fixed in @('Muscles Worked','Primary','Secondary','Primary Muscles','Secondary Muscles','Front View','Back View')){Assert ($rendererJson.fixed_text -ccontains $fixed) "Missing deterministic text: $fixed"}
Add-Type -AssemblyName System.Drawing;$invalid=Join-Path $testDir 'invalid_artwork.png';$invalidCard=Join-Path $testDir 'invalid_card.png';if(Test-Path $invalidCard){Remove-Item -LiteralPath $invalidCard}
$bitmap=[Drawing.Bitmap]::new(1024,1024);try{$g=[Drawing.Graphics]::FromImage($bitmap);try{$g.Clear([Drawing.Color]::White);$g.DrawString('INVALID TEXT',[Drawing.Font]::new('Arial',18),[Drawing.Brushes]::Black,2,2)}finally{$g.Dispose()};$bitmap.Save($invalid,[Drawing.Imaging.ImageFormat]::Png)}finally{$bitmap.Dispose()}
$rejected=$false;try{& (Join-Path $root 'tool/validate_anatomy_artwork.ps1') -ArtworkPath $invalid -Sex male -PrimaryMuscles chest -SecondaryMuscles anterior_deltoids,triceps|Out-Null}catch{$rejected=$true}
Assert $rejected 'Invalid artwork passed validation';Assert (-not(Test-Path $invalidCard)) 'Invalid artwork reached renderer'
$manifest=Get-Content -Raw (Join-Path $root 'assets/data/exercise_library/anatomy_generation_manifest.json')|ConvertFrom-Json;$job=$manifest.jobs|Where-Object job_id -eq 'mu_ex_barbell_bench_press_female'
Assert ((Test-Path (Join-Path $root 'assets/exercises/anatomy/candidates/female/mu_ex_barbell_bench_press_v2.png')) -and (Test-Path (Join-Path $root 'assets/exercises/anatomy/candidates/female/mu_ex_barbell_bench_press_v3.png'))) 'Rejected V2/V3 files not preserved'
Assert ($job.status -in @('rejected','failed') -and @($job.candidate_history).Count -ge 2) 'Rejected V2/V3 history not preserved'
"Artwork pipeline tests passed: Male V4 artwork reference, text separation, catalog renderer, validation gate, rejected history"
