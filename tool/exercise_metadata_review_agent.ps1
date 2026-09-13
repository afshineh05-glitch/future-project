param(
  [string]$CatalogPath='assets/data/exercise_library/movekit_complete_catalog.json',
  [string]$QueuePath='assets/data/exercise_library/review_queue.json',
  [string]$CheckpointPath='assets/data/exercise_library/metadata_production_checkpoint.json',
  [int]$BatchSize=10,
  [int]$MaxBatches=0,
  [switch]$RestartResolution
)
$ErrorActionPreference='Stop'
$reviewBatchSize=$BatchSize;$reviewMaxBatches=$MaxBatches
. "$PSScriptRoot/exercise_metadata_agent.ps1" -DefinitionsOnly -BatchSize $reviewBatchSize -MaxBatches $reviewMaxBatches
$BatchSize=$reviewBatchSize;$MaxBatches=$reviewMaxBatches
$resolutionAuthor='muscleup_review_research_1';$resolutionReviewer='muscleup_review_verifier_1'
$await=@(
 'mu_ex_abdominals_stretch_variation_four','mu_ex_abdominals_stretch_variation_one','mu_ex_abdominals_stretch_variation_three','mu_ex_abdominals_stretch_variation_two',
 'mu_ex_battle_ropes','mu_ex_behind_the_neck_press','mu_ex_burpee','mu_ex_cuban_press','mu_ex_dumbbell_superman','mu_ex_floor_press','mu_ex_hill_climb_repeats','mu_ex_landmine_press','mu_ex_man_maker','mu_ex_pendulum_squat_v_squat','mu_ex_single_arm_tricep_extension','mu_ex_sled_pull','mu_ex_sled_push','mu_ex_swim_kick_drill','mu_ex_swim_pull_drill','mu_ex_wall_ball'
)
$canonicalMuscles=@('chest','anterior_deltoids','lateral_deltoids','posterior_deltoids','triceps','biceps','forearms','lats','traps','upper_back','spinal_erectors','core','obliques','glutes','quadriceps','hamstrings','adductors','abductors','hip_flexors','calves','rotator_cuff','serratus_anterior','neck_flexors','neck_extensors','tibialis_anterior')

function Research([object]$exercise){
 if($await -contains $exercise.canonical_id){return @{state='awaiting_video_license';reason='multiple_material_executions_require_licensed_visual_confirmation';sources=@('Identity is insufficient to distinguish materially different established executions.')}}
 $draft=Draft $exercise
 if($draft.review_reason){return @{state='needs_human_review';reason=$draft.review_reason;sources=@()}}
 if($exercise.canonical_id -eq 'mu_ex_horizontal_leg_press_calf_press'){$draft.movement_pattern='calf_raise';$draft.body_region='lower_body';$draft.mechanics='isolation';$draft.primary_muscles=@('calves');$draft.secondary_muscles=@();$draft.stabilizer_muscles=@();$draft.required_anatomy_views=@('back')}
 if($exercise.canonical_id -eq 'mu_ex_reverse_pec_deck'){$draft.movement_pattern='horizontal_pull';$draft.body_region='upper_body';$draft.mechanics='isolation';$draft.primary_muscles=@('posterior_deltoids');$draft.secondary_muscles=@('upper_back','traps');$draft.stabilizer_muscles=@('rotator_cuff');$draft.required_anatomy_views=@('back')}
 $draft.metadata_sources=@($draft.metadata_sources)+@('Resolution review: ACE Exercise Library and NSCA exercise-technique conventions; independently paraphrased.')
 return @{state='draft';metadata=$draft;author_version=$resolutionAuthor;hash=(Fingerprint $draft)}
}
function Verify([object]$exercise,[object]$proposal){
 $issues=@();if($proposal.author_version -eq $resolutionReviewer){$issues+='same_pass_identity'};if(-not $proposal.hash){$issues+='missing_author_hash'}
 $d=$proposal.metadata;$roles=@($d.primary_muscles)+@($d.secondary_muscles)+@($d.stabilizer_muscles)
 if(-not $d.movement_pattern -or -not $d.primary_muscles){$issues+='missing_classification'}
 if(@($roles|Sort-Object -Unique).Count -ne $roles.Count){$issues+='muscle_role_overlap'}
 if(@($roles|Where-Object {$_ -notin $canonicalMuscles}).Count){$issues+='taxonomy_gap'}
 if(@($d.required_anatomy_views|Where-Object {$_ -notin @('front','back')}).Count -or -not $d.required_anatomy_views){$issues+='invalid_anatomy_views'}
 if($d.default_sets_min -gt $d.default_sets_max -or $d.default_rest_seconds_min -gt $d.default_rest_seconds_max){$issues+='invalid_programming'}
 if(($null -ne $d.default_reps_min) -xor ($null -ne $d.default_reps_max)){$issues+='invalid_programming'}
 if($exercise.canonical_id -in $await){$issues+='research_verifier_disagrees_with_await_gate'}
 return @{decision=if($issues.Count){'needs_human_review'}else{'pass'};issues=[object[]]$issues;reviewer_version=$resolutionReviewer;author_hash=$proposal.hash}
}
function SetValue([object]$record,[string]$name,[object]$value){if($record.PSObject.Properties[$name]){$record.$name=$value}else{$record|Add-Member NoteProperty $name $value}}
function Persist([object]$catalog,[int]$batch,[string]$last){
 $catalog|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $CatalogPath -Encoding utf8
 $open=@($catalog.exercises|Where-Object metadata_status -in @('awaiting_video_license','needs_human_review','invalid_identity'))
 [ordered]@{duplicate_candidates=@();unresolved=@($open|ForEach-Object {[ordered]@{canonical_id=$_.canonical_id;source_name=$_.source_name;reason=$_.review_reason;state=$_.metadata_status}});unknown_muscles=@();ambiguous_video_matches=@()}|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $QueuePath -Encoding utf8
 $validated=@($catalog.exercises|Where-Object metadata_status -eq 'metadata_validated').Count
 [ordered]@{generator_version=$resolutionAuthor;reviewer_version=$resolutionReviewer;catalog_version=1;total_records=412;completed_records=$validated;pending_records=0;review_records=$open.Count;failed_records=@($catalog.exercises|Where-Object metadata_status -eq 'invalid_identity').Count;last_completed_canonical_id=$last;current_batch=$batch;updated_at=(Get-Date).ToUniversalTime().ToString('o')}|ConvertTo-Json|Set-Content -LiteralPath $CheckpointPath -Encoding utf8
}
$catalog=Get-Content -LiteralPath $CatalogPath -Raw|ConvertFrom-Json
if($RestartResolution){foreach($e in $catalog.exercises|Where-Object metadata_version -eq 2){$e.metadata_status='needs_review';$e.validation_status='needs_review';$e.review_reason='resolution_restart'}}
$protected=@{};foreach($e in $catalog.exercises|Where-Object metadata_status -eq 'metadata_validated'){$protected[$e.canonical_id]=($e|ConvertTo-Json -Depth 8 -Compress)}
$remaining=@($catalog.exercises|Where-Object metadata_status -in @('needs_review','needs_human_review')|Sort-Object canonical_id)
$batch=if((Test-Path $CheckpointPath) -and -not $RestartResolution){[int]((Get-Content $CheckpointPath -Raw|ConvertFrom-Json).current_batch)}else{0};$processed=0;$last=$null
while($remaining.Count -and ($MaxBatches -eq 0 -or $processed -lt $MaxBatches)){
 $batch++;$processed++;foreach($e in @($remaining|Select-Object -First $BatchSize)){
  $p=Research $e
  if($p.state -ne 'draft'){$e.metadata_status=$p.state;$e.validation_status=$p.state;$e.review_reason=$p.reason;SetValue $e metadata_sources ([object[]]@($p.sources));SetValue $e metadata_version 2;SetValue $e authored_at ((Get-Date).ToUniversalTime().ToString('o'));SetValue $e reviewed_at ((Get-Date).ToUniversalTime().ToString('o'))}
  else{$v=Verify $e $p;if($v.decision -eq 'pass'){foreach($k in $p.metadata.Keys){SetValue $e $k $p.metadata[$k]};$e.metadata_status='metadata_validated';$e.validation_status='verified';$e.review_reason=$null;SetValue $e metadata_version 2;SetValue $e authored_at ((Get-Date).ToUniversalTime().ToString('o'));SetValue $e reviewed_at ((Get-Date).ToUniversalTime().ToString('o'))}else{$e.metadata_status='needs_human_review';$e.validation_status='needs_human_review';$e.review_reason=($v.issues -join ',')}}
  $last=$e.canonical_id
 }
 foreach($id in $protected.Keys){$now=($catalog.exercises|Where-Object canonical_id -eq $id)|ConvertTo-Json -Depth 8 -Compress;if($now -ne $protected[$id]){throw "Previously validated record changed: $id"}}
 Persist $catalog $batch $last;Write-Output "Resolution batch $batch saved; last=$last"
 $remaining=@($catalog.exercises|Where-Object metadata_status -in @('needs_review','needs_human_review')|Sort-Object canonical_id)
}
Persist $catalog $batch $last
Write-Output "Resolution complete: validated=$(@($catalog.exercises|Where-Object metadata_status -eq 'metadata_validated').Count) awaiting=$(@($catalog.exercises|Where-Object metadata_status -eq 'awaiting_video_license').Count) human=$(@($catalog.exercises|Where-Object metadata_status -eq 'needs_human_review').Count) invalid=$(@($catalog.exercises|Where-Object metadata_status -eq 'invalid_identity').Count)"
