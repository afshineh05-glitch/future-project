param(
  [ValidateSet('manifest','dry-run','pilot','run','approve','reject','status')]
  [string]$Command = 'dry-run',
  [string]$JobId,
  [string]$Reason,
  [int]$BatchSize = 20,
  [ValidateRange(0,0)][int]$RetryLimit = 0,
  [int]$DelayMilliseconds = 1000,
  [double]$MaximumEstimatedSpendUsd = 0,
  [int]$MinimumResolution = 1024,
  [int]$MinimumFileSizeBytes = 1024,
  [int]$MaximumFileSizeBytes = 25000000,
  [switch]$GenerateCandidate
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$catalogPath = Join-Path $root 'assets/data/exercise_library/movekit_complete_catalog.json'
$manifestPath = Join-Path $root 'assets/data/exercise_library/anatomy_generation_manifest.json'
$checkpointPath = Join-Path $root 'assets/data/exercise_library/anatomy_generation_checkpoint.json'
$auditPath = Join-Path $root 'assets/data/exercise_library/anatomy_generation_audit.json'
$providerPath = Join-Path $PSScriptRoot 'openai_anatomy_image_provider.ps1'
$promptVersion = 'muscleup_anatomy_locked_v4'
$pilotCanonicalId = 'mu_ex_barbell_bench_press'
$rendererPath = Join-Path $PSScriptRoot 'render_anatomy_card.ps1'
$validatorPath = Join-Path $PSScriptRoot 'validate_anatomy_artwork.ps1'
$femaleTemplateId = 'female_neutral_anatomy_master_v3'
$femaleTemplateRelativePath = 'assets/exercises/anatomy/templates/female_neutral_anatomy_master_v3.png'
$femaleTemplatePath = Join-Path $root $femaleTemplateRelativePath
$femaleTemplateSha256 = '08B6D1124802BD7CDBDA31107A3C4D68990FF5CC2AFD354F2F07F936998C5057'
$femaleArtworkReferenceRelativePath = 'assets/exercises/anatomy/templates/female_neutral_anatomy_artwork_reference_v3.png'
$femaleArtworkReferencePath = Join-Path $root $femaleArtworkReferenceRelativePath
$femaleArtworkReferenceSha256 = '2A1C946F09F9B53C9E3452146E38D406847AF2DC2A992FDCA1E3FF0BA0627225'
$maleTemplateId = 'male_neutral_anatomy_master_v4'
$maleTemplateRelativePath = 'assets/exercises/anatomy/templates/male_neutral_anatomy_master_v4.png'
$maleTemplatePath = Join-Path $root $maleTemplateRelativePath
$maleTemplateSha256 = '5FFE7590F204E01A1A1EC95B5D2312404B32A1FA59D2464E254D453254B95BD9'
$maleArtworkReferenceRelativePath = 'assets/exercises/anatomy/templates/male_neutral_anatomy_master_v4.png'
$maleArtworkReferencePath = Join-Path $root $maleArtworkReferenceRelativePath
$maleArtworkReferenceSha256 = '5FFE7590F204E01A1A1EC95B5D2312404B32A1FA59D2464E254D453254B95BD9'

function Assert-LockedTemplates {
  if(-not(Test-Path -LiteralPath $maleTemplatePath)){throw 'Locked male anatomy master is missing.'}
  $maleActual=(Get-FileHash -LiteralPath $maleTemplatePath -Algorithm SHA256).Hash
  if($maleActual -ne $maleTemplateSha256){throw "Locked male anatomy master hash mismatch: expected=$maleTemplateSha256 actual=$maleActual"}
  if(-not(Test-Path -LiteralPath $maleArtworkReferencePath)){throw 'Cropped male artwork reference is missing.'}
  if((Get-FileHash -LiteralPath $maleArtworkReferencePath -Algorithm SHA256).Hash -ne $maleArtworkReferenceSha256){throw 'Cropped male artwork reference hash mismatch.'}
}

function Save-Json($Value, [string]$Path, [int]$Depth = 12) {
  $json = $Value | ConvertTo-Json -Depth $Depth
  [IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
}

function Read-Json([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
}

function Status-Value($Exercise, [string]$Sex) {
  $asset = $Exercise."${Sex}_anatomy_asset"
  $status = $Exercise."${Sex}_anatomy_status"
  if ($asset -and $status -like 'approved*') { return 'approved_existing' }
  return 'pending'
}

function New-Manifest {
  $catalog = Read-Json $catalogPath
  $eligible = @($catalog.exercises | Where-Object metadata_status -eq 'metadata_validated' | Sort-Object canonical_id)
  $excluded = @($catalog.exercises | Where-Object metadata_status -eq 'awaiting_video_license')
  if ($catalog.exercises.Count -ne 412 -or $eligible.Count -ne 392 -or $excluded.Count -ne 20) {
    throw "Catalog eligibility mismatch: total=$($catalog.exercises.Count) eligible=$($eligible.Count) excluded=$($excluded.Count)"
  }
  $previous = Read-Json $manifestPath
  $old = @{}
  if ($previous) { foreach ($job in $previous.jobs) { $old[$job.job_id] = $job } }
  $jobs = foreach ($exercise in $eligible) {
    foreach ($sex in @('male','female')) {
      $id = "$($exercise.canonical_id)_$sex"
      $prior = $old[$id]
      $protected = Status-Value $exercise $sex
      [ordered]@{
        job_id = $id; canonical_id = $exercise.canonical_id
        exercise_name = $exercise.display_name; sex = $sex
        primary_muscles = @($exercise.primary_muscles)
        secondary_muscles = @($exercise.secondary_muscles)
        output_path = if($prior){$prior.output_path}else{"assets/exercises/anatomy/$sex/$($exercise.canonical_id).png"}
        prompt_version = $promptVersion
        template_id = if($sex -eq 'female'){$femaleTemplateId}else{$maleTemplateId}
        template_path = if($sex -eq 'female'){$femaleTemplateRelativePath}else{$maleTemplateRelativePath}
        template_sha256 = if($sex -eq 'female'){$femaleTemplateSha256}else{$maleTemplateSha256}
        template_role = 'card_template'
        artwork_reference_path = if($sex -eq 'female'){$femaleArtworkReferenceRelativePath}else{$maleArtworkReferenceRelativePath}
        artwork_reference_sha256 = if($sex -eq 'female'){$femaleArtworkReferenceSha256}else{$maleArtworkReferenceSha256}
        status = if ($protected -eq 'approved_existing') { $protected } elseif ($prior) { $prior.status } else { 'pending' }
        attempts = if ($prior) { [int]$prior.attempts } else { 0 }
        validation_result = if ($prior) { $prior.validation_result } else { $null }
        error_details = if ($prior) { $prior.error_details } else { $null }
        candidate_history = if ($prior -and $prior.candidate_history) { @($prior.candidate_history) } else { @() }
      }
    }
  }
  $manifest = [ordered]@{
    manifest_version = 1; prompt_version = $promptVersion
    generated_at = (Get-Date).ToUniversalTime().ToString('o')
    total_catalog_records = 412; eligible_records = 392; excluded_records = 20
    jobs = @($jobs)
  }
  Save-Json $manifest $manifestPath
  if (-not (Test-Path -LiteralPath $auditPath)) {
    Save-Json ([ordered]@{events=@()}) $auditPath
  }
  Update-Checkpoint $manifest
  return $manifest
}

function Update-Checkpoint($Manifest) {
  $jobs = @($Manifest.jobs)
  $checkpoint = [ordered]@{
    generator_version = 1; prompt_version = $promptVersion; total_jobs = $jobs.Count
    pending_jobs = @($jobs | Where-Object status -in @('pending','rejected','failed')).Count
    pending_review_jobs = @($jobs | Where-Object status -eq 'pending_review').Count
    approved_jobs = @($jobs | Where-Object status -in @('approved','approved_existing')).Count
    failed_jobs = @($jobs | Where-Object status -eq 'failed').Count
    pending_review_candidates = @($jobs | Where-Object status -eq 'pending_review' | ForEach-Object {[ordered]@{job_id=$_.job_id;output_path=$_.output_path;prompt_version=$_.prompt_version;template_id=$_.template_id;template_sha256=$_.template_sha256;provider_id=$_.validation_result.provider_id;model=$_.validation_result.model;estimated_cost_usd=$_.validation_result.estimated_cost_usd;width=$_.validation_result.width;height=$_.validation_result.height;validation=$_.validation_result}})
    updated_at = (Get-Date).ToUniversalTime().ToString('o')
  }
  Save-Json $checkpoint $checkpointPath
}

function Get-Prompt($Job) {
  return @"
Edit the supplied cropped male anatomy artwork reference. Return anatomy artwork only:
exactly one complete male front anatomy on the left and one complete male back anatomy
on the right, on a plain white background. Preserve the exact anatomy model and proportions.
Color only these primary muscles red: $($Job.primary_muscles -join ', '). Color only these
secondary muscles orange: $($Job.secondary_muscles -join ', '). Every unrelated muscle must
remain grayscale. Use anatomically correct regions in the appropriate front and/or back view.
Do not render any text, letters, words, numbers, UI, cards, panels,
icons, labels, legends, borders, badges, logos, or decorative elements. Do not crop or deform
the bodies and do not add people or exercise equipment.
"@
}

function Get-VersionedPaths($Job) {
  $dir=Join-Path $root "assets/exercises/anatomy/candidates/$($Job.sex)"
  [IO.Directory]::CreateDirectory($dir)|Out-Null
  $version=2
  do {
    $stem="$($Job.canonical_id)_v$version"
    $card=Join-Path $dir "$stem.png"
    $art=Join-Path $dir "${stem}_artwork.png"
    $version++
  } while((Test-Path -LiteralPath $card) -or (Test-Path -LiteralPath $art))
  return @{card=$card;artwork=$art;relative_card="assets/exercises/anatomy/candidates/$($Job.sex)/$stem.png"}
}

function Test-Png($Job) {
  $full = Join-Path $root $Job.output_path
  $normalized=$Job.output_path.Replace('\','/')
  $base="assets/exercises/anatomy/$($Job.sex)/$($Job.canonical_id).png"
  $candidatePattern="^assets/exercises/anatomy/candidates/$($Job.sex)/$([regex]::Escape($Job.canonical_id))_v[0-9]+\.png$"
  if ($normalized -ne $base -and $normalized -notmatch $candidatePattern) { return @{valid=$false; error='destination_mismatch'} }
  if (-not (Test-Path -LiteralPath $full)) { return @{valid=$false; error='file_missing'} }
  $bytes = [IO.File]::ReadAllBytes($full)
  if ($bytes.Length -lt $MinimumFileSizeBytes) { return @{valid=$false; error='below_minimum_file_size';bytes=$bytes.Length} }
  if ($bytes.Length -gt $MaximumFileSizeBytes) { return @{valid=$false; error='above_maximum_file_size';bytes=$bytes.Length} }
  $signature = @(137,80,78,71,13,10,26,10)
  for ($i=0; $i -lt 8; $i++) { if ($bytes[$i] -ne $signature[$i]) { return @{valid=$false; error='not_png'} } }
  $width = [Net.IPAddress]::NetworkToHostOrder([BitConverter]::ToInt32($bytes,16))
  $height = [Net.IPAddress]::NetworkToHostOrder([BitConverter]::ToInt32($bytes,20))
  if ($width -ne $height) { return @{valid=$false; error='not_square';width=$width;height=$height} }
  if ($width -lt $MinimumResolution) { return @{valid=$false;error='below_minimum_resolution';width=$width;height=$height} }
  return @{valid=$true;width=$width;height=$height;bytes=$bytes.Length}
}

function Add-Audit($Job, [string]$Action, [string]$Details) {
  $audit = Read-Json $auditPath
  $events = [Collections.ArrayList]::new()
  if ($audit -and $audit.events) { foreach ($event in @($audit.events)) { [void]$events.Add($event) } }
  [void]$events.Add([ordered]@{at=(Get-Date).ToUniversalTime().ToString('o');job_id=$Job.job_id;action=$Action;details=$Details})
  Save-Json ([ordered]@{events=@($events)}) $auditPath
}

function Invoke-Jobs($Manifest, [bool]$PilotOnly) {
  if (-not (Test-Path -LiteralPath $providerPath)) { throw 'The isolated OpenAI anatomy provider is missing.' }
  if (-not (Test-Path -LiteralPath $rendererPath) -or -not (Test-Path -LiteralPath $validatorPath)) { throw 'Hybrid renderer or validator is missing.' }
  $key = [Environment]::GetEnvironmentVariable('OPENAI_API_KEY', 'Process')
  if ([string]::IsNullOrWhiteSpace($key)) { throw 'OPENAI_API_KEY is not configured in the current process.' }
  $cost = 0.009
  Assert-LockedTemplates
  if($GenerateCandidate){
    if(-not $JobId){throw 'GenerateCandidate requires an exact JobId.'}
    $jobs=@($Manifest.jobs|Where-Object job_id -eq $JobId)
  }else{
    $jobs = @($Manifest.jobs | Where-Object { $_.sex -eq 'male' -and $_.status -in @('pending','rejected','failed') })
    if ($PilotOnly) { $jobs = @($Manifest.jobs | Where-Object job_id -eq 'mu_ex_barbell_bench_press_male') }
    if ($JobId) { $jobs = @($jobs | Where-Object job_id -eq $JobId) }
  }
  if($jobs.Count -ne 1 -and $GenerateCandidate){throw 'GenerateCandidate must resolve exactly one job.'}
  if(@($jobs|Where-Object sex -ne 'male').Count){throw 'Male-only mode forbids female provider jobs.'}
  $jobs = @($jobs | Select-Object -First $BatchSize)
  $estimate = $jobs.Count * $cost
  if ($estimate -gt $MaximumEstimatedSpendUsd) { throw "Estimated spend $estimate USD exceeds guard $MaximumEstimatedSpendUsd USD." }
  foreach ($job in $jobs) {
    $catalog = Read-Json $catalogPath
    $exercise = $catalog.exercises | Where-Object canonical_id -eq $job.canonical_id | Select-Object -First 1
    $protectedApprovedExisting=(Status-Value $exercise $job.sex) -eq 'approved_existing'
    if (-not $GenerateCandidate -and -not $PilotOnly -and (Status-Value $exercise $job.sex) -eq 'approved_existing') { $job.status='approved_existing'; continue }
    $paths=Get-VersionedPaths $job
    $full=$paths.card;$artwork=$paths.artwork
    if($job.sex -ne 'male'){throw 'Male-only artwork reference routing failed.'}
    $request=[ordered]@{prompt=(Get-Prompt $job);output_path=$artwork;reference_image_path=$maleArtworkReferencePath;template_sha256=$maleArtworkReferenceSha256}|ConvertTo-Json -Depth 5 -Compress
    for ($attempt=0; $attempt -le $RetryLimit; $attempt++) {
      $job.attempts = [int]$job.attempts + 1
      $providerOutput = (@(& $providerPath -RequestJson $request 2>&1) | Out-String).Trim()
      if ([string]::IsNullOrWhiteSpace($providerOutput) -and $LASTEXITCODE -ne 0) { $providerOutput = "provider_exit_$LASTEXITCODE" }
      $providerExit = $LASTEXITCODE
      if ($providerExit -eq 0) {
        try { $providerResult=$providerOutput|ConvertFrom-Json }
        catch { throw 'Provider succeeded but returned an unparseable status envelope.' }
        break
      }
      if ($providerExit -eq 10) {
        $job.status='failed';$job.error_details=([string]$providerOutput);Add-Audit $job 'failed' $job.error_details
        Save-Json $Manifest $manifestPath;Update-Checkpoint $Manifest
        throw 'OpenAI authentication failed; stopped after one request.'
      }
      if ($attempt -lt $RetryLimit) { Start-Sleep -Milliseconds $DelayMilliseconds }
    }
    if($providerExit -ne 0){
      $job.error_details=([string]$providerOutput)
      if($protectedApprovedExisting){if(-not $job.PSObject.Properties['candidate_history']){$job|Add-Member -NotePropertyName candidate_history -NotePropertyValue @()};$job.candidate_history=@($job.candidate_history)+@([ordered]@{status='pilot_failed';failed_at=(Get-Date).ToUniversalTime().ToString('o');reason=$job.error_details});$job.status='approved_existing'}else{$job.status='failed'}
      Add-Audit $job 'failed' $job.error_details;Save-Json $Manifest $manifestPath;Update-Checkpoint $Manifest;throw $job.error_details
    }
    try{
      $artValidationText=& $validatorPath -ArtworkPath $artwork -Sex $job.sex -PrimaryMuscles @($job.primary_muscles) -SecondaryMuscles @($job.secondary_muscles)
      $artValidation=$artValidationText|ConvertFrom-Json
      $rendererText=& $rendererPath -ArtworkPath $artwork -OutputPath $full -ExerciseName $job.exercise_name -PrimaryMuscles @($job.primary_muscles) -SecondaryMuscles @($job.secondary_muscles)
      $rendererFields=$rendererText|ConvertFrom-Json
    }catch{
      $job.status='rejected';$job.output_path=$artwork.Substring($root.Length+1).Replace('\','/');$job.error_details=$_.Exception.Message
      if(-not $job.PSObject.Properties['candidate_history']){$job|Add-Member -NotePropertyName candidate_history -NotePropertyValue @()}
      $job.candidate_history=@($job.candidate_history)+@([ordered]@{status='rejected';rejected_at=(Get-Date).ToUniversalTime().ToString('o');output_path=$job.output_path;reason=$job.error_details;provider_response=$providerResult})
      Add-Audit $job 'validation_failed_before_render' ([ordered]@{reason=$job.error_details;artwork_path=$job.output_path;renderer_invoked=$false;provider_response=$providerResult}|ConvertTo-Json -Depth 8 -Compress);Save-Json $Manifest $manifestPath;Update-Checkpoint $Manifest
      if($PilotOnly -or $GenerateCandidate){throw};continue
    }
    $job.output_path=$paths.relative_card
    if(-not $job.PSObject.Properties['candidate_history']){$job|Add-Member -NotePropertyName candidate_history -NotePropertyValue @()}
    $validation = Test-Png $job; $validation.artwork_validation=$artValidation;$validation.renderer_fields=$rendererFields;$validation.artwork_path=$artwork.Substring($root.Length+1).Replace('\','/');$validation.provider_response=$providerResult;$validation.provider_id='openai';$validation.model='gpt-image-1.5';$validation.estimated_cost_usd=0.009;$validation.prompt_version=$promptVersion;$validation.template_id=$job.template_id;$validation.template_sha256=$job.template_sha256;$validation.generated_at=(Get-Date).ToUniversalTime().ToString('o'); $job.validation_result=$validation
    if ($validation.valid) { $job.status='pending_review';$job.error_details=$null;Add-Audit $job 'generated' ($validation|ConvertTo-Json -Depth 10 -Compress) }
    else { $job.status='failed';$job.error_details=$validation.error;Add-Audit $job 'failed' $validation.error }
    Save-Json $Manifest $manifestPath;Update-Checkpoint $Manifest
    if ($DelayMilliseconds -gt 0 -and $job -ne $jobs[-1]) { Start-Sleep -Milliseconds $DelayMilliseconds }
  }
}

$manifest = if ($Command -eq 'manifest') { New-Manifest } else { Read-Json $manifestPath }
if (-not $manifest) { $manifest = New-Manifest }

switch ($Command) {
  'manifest' { "Manifest saved: jobs=$($manifest.jobs.Count)" }
  'dry-run' {
    $male=@($manifest.jobs|Where-Object sex -eq 'male').Count;$female=@($manifest.jobs|Where-Object sex -eq 'female').Count
    $bad=@($manifest.jobs|Where-Object { $normalized=$_.output_path.Replace('\','/');$base="assets/exercises/anatomy/$($_.sex)/$($_.canonical_id).png";$candidate="^assets/exercises/anatomy/candidates/$($_.sex)/$([regex]::Escape($_.canonical_id))_v[0-9]+\.png$";$normalized -ne $base -and $normalized -notmatch $candidate })
    Assert-LockedTemplates
    $badFemale=@($manifest.jobs|Where-Object {$_.sex -eq 'female' -and ($_.template_id -ne $femaleTemplateId -or $_.template_path -ne $femaleTemplateRelativePath -or $_.template_sha256 -ne $femaleTemplateSha256)})
    $badMale=@($manifest.jobs|Where-Object {$_.sex -eq 'male' -and ($_.template_id -ne $maleTemplateId -or $_.template_path -ne $maleTemplateRelativePath -or $_.template_sha256 -ne $maleTemplateSha256)})
    $crossSex=@($manifest.jobs|Where-Object {($_.sex -eq 'male' -and $_.template_path -eq $femaleTemplateRelativePath)-or($_.sex -eq 'female' -and $_.template_path -eq $maleTemplateRelativePath)})
    if ($manifest.jobs.Count -ne 784 -or $male -ne 392 -or $female -ne 392 -or $bad.Count -or $badFemale.Count -or $badMale.Count -or $crossSex.Count) { throw 'Dry-run manifest validation failed.' }
    "Dry-run passed: eligible=392 excluded=20 jobs=784 male=$male female=$female cross_sex=$($crossSex.Count) images_generated=0"
  }
  'pilot' { Invoke-Jobs $manifest $true;Save-Json $manifest $manifestPath;Update-Checkpoint $manifest }
  'run' { Invoke-Jobs $manifest $false;Save-Json $manifest $manifestPath;Update-Checkpoint $manifest }
  'approve' {
    $job=$manifest.jobs|Where-Object job_id -eq $JobId|Select-Object -First 1
    if (-not $job -or $job.status -ne 'pending_review') { throw 'Job must exist and be pending_review.' }
    $validation=Test-Png $job;if(-not $validation.valid){throw "File validation failed: $($validation.error)"}
    $catalog=Read-Json $catalogPath;$exercise=$catalog.exercises|Where-Object canonical_id -eq $job.canonical_id|Select-Object -First 1
    $assetField="$($job.sex)_anatomy_asset";$statusField="$($job.sex)_anatomy_status"
    if ($exercise.$assetField -and $exercise.$statusField -like 'approved*') { throw 'Approved asset overwrite is forbidden.' }
    $exercise.$assetField=$job.output_path;$exercise.$statusField='approved';$job.status='approved';$job.validation_result=$validation
    Save-Json $catalog $catalogPath;Save-Json $manifest $manifestPath;Add-Audit $job 'approved' $job.output_path;Update-Checkpoint $manifest
  }
  'reject' {
    if (-not $Reason) { throw 'Rejection reason is required.' };$job=$manifest.jobs|Where-Object job_id -eq $JobId|Select-Object -First 1
    if (-not $job -or $job.status -ne 'pending_review') { throw 'Job must exist and be pending_review.' }
    $snapshot=[ordered]@{reason=$Reason;output_path=$job.output_path;validation_result=$job.validation_result}
    if(-not $job.PSObject.Properties['candidate_history']){$job|Add-Member -NotePropertyName candidate_history -NotePropertyValue @()}
    $job.candidate_history=@($job.candidate_history)+@([ordered]@{status='rejected';rejected_at=(Get-Date).ToUniversalTime().ToString('o');output_path=$job.output_path;reason=$Reason;validation_result=$job.validation_result})
    $job.status='rejected';$job.error_details=$Reason;Save-Json $manifest $manifestPath;Add-Audit $job 'rejected' ($snapshot|ConvertTo-Json -Depth 12 -Compress);Update-Checkpoint $manifest
  }
  'status' { Get-Content -Raw $checkpointPath }
}
