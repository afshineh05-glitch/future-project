$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot;$path=Join-Path $root 'assets/data/exercise_library/anatomy_generation_manifest.json'
$manifest=Get-Content -Raw -LiteralPath $path|ConvertFrom-Json;$male=@($manifest.jobs|Where-Object sex -eq 'male');$female=@($manifest.jobs|Where-Object sex -eq 'female')
if($male.Count-ne392-or$female.Count-ne392){throw 'Manifest sex counts are invalid.'}
foreach($job in $male){$job.prompt_version='muscleup_anatomy_locked_v4';$job.template_id='male_neutral_anatomy_master_v4';$job.template_path='assets/exercises/anatomy/templates/male_neutral_anatomy_master_v4.png';$job.template_sha256='5FFE7590F204E01A1A1EC95B5D2312404B32A1FA59D2464E254D453254B95BD9';$job.artwork_reference_path='assets/exercises/anatomy/templates/male_neutral_anatomy_master_v4.png';$job.artwork_reference_sha256='5FFE7590F204E01A1A1EC95B5D2312404B32A1FA59D2464E254D453254B95BD9'}
$manifest.prompt_version='muscleup_anatomy_locked_v4';$json=$manifest|ConvertTo-Json -Depth 20;[IO.File]::WriteAllText($path,$json+[Environment]::NewLine,[Text.UTF8Encoding]::new($false))
"Male V4 migration complete: male=$($male.Count) female_untouched=$($female.Count)"
