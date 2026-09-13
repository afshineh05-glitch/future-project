param(
  [string]$CatalogPath = 'assets/data/exercise_library/movekit_complete_catalog.json',
  [string]$CheckpointPath = 'assets/data/exercise_library/metadata_production_checkpoint.json',
  [string]$ReviewQueuePath = 'assets/data/exercise_library/review_queue.json',
  [int]$BatchSize = 20,
  [int]$MaxBatches = 0,
  [switch]$DefinitionsOnly
)

$ErrorActionPreference = 'Stop'
$generatorVersion = 'muscleup_metadata_author_1'
$reviewerVersion = 'muscleup_metadata_reviewer_1'
$catalogVersion = 1
$sources = @(
  'ACSM Progression Models in Resistance Training for Healthy Adults (2009), doi:10.1249/MSS.0b013e3181915670',
  'NSCA Essentials of Strength Training and Conditioning, 4th edition',
  'OpenStax Anatomy and Physiology 2e, muscular system'
)
$manualNames = @(
  'Abdominals Stretch Variation Four','Abdominals Stretch Variation One',
  'Abdominals Stretch Variation Three','Abdominals Stretch Variation Two',
  'Pendulum Squat / V-Squat','Sled Push/Pull','Swim Kick Drill','Swim Pull Drill'
)

function Strings([object]$value) { return [object[]]@($value) }
function Has([string]$name,[string]$pattern) { return $name -match $pattern }
function Equipment([string]$name) {
  $values = @()
  $rules = [ordered]@{
    'barbell'='barbell'; 'dumbbell'='dumbbell'; 'kettlebell'='kettlebell';
    'cable'='cable'; 'band'='resistance_band'; 'smith'='smith_machine';
    'trap bar'='trap_bar'; 'landmine'='landmine'; 'medicine ball|wall ball'='medicine_ball';
    'stability ball'='stability_ball'; 'bosu'='bosu'; 'plate'='plate';
    'sled'='sled'; 'battle rope'='battle_rope'; 'suspension'='suspension_trainer';
    'foam roll'='foam_roller'; 'box'='box'; 'step'='step'; 'dip'='dip_station';
    'pull-up|pull up|chin-up|chin up'='pull_up_bar';
    'machine|hack squat|leg press|pendulum'='machine';
    'bike|trainer|treadmill|rower|elliptical|stair|ski erg|versaclimber'='cardio_machine'
  }
  foreach ($pattern in $rules.Keys) { if ($name -match $pattern) { $values += $rules[$pattern] } }
  if ($values.Count -eq 0) { $values += 'bodyweight' }
  return ,([object[]]@($values | Select-Object -Unique))
}

function Draft([object]$exercise) {
  $n = $exercise.source_name.ToLowerInvariant()
  if ($manualNames -contains $exercise.source_name -or $n -match 'variation (one|two|three|four)') {
    return @{ review_reason='identity_does_not_define_single_execution' }
  }
  $d = [ordered]@{
    category='strength'; body_region='full_body'; movement_pattern=$null
    equipment=Equipment $n; exercise_type='resistance'; mechanics='compound'
    laterality=if($n -match 'alternating'){ 'alternating' }elseif($n -match 'single|one arm|one-arm|unilateral'){ 'unilateral' }else{'bilateral'}
    difficulty=if($n -match 'assisted|bodyweight|stretch|mobility'){ 'beginner' }elseif($n -match 'snatch|clean|jerk|pistol|deficit|jefferson'){ 'advanced' }else{'intermediate'}
    primary_muscles=@(); secondary_muscles=@(); stabilizer_muscles=@('core')
    required_anatomy_views=@('front','back'); training_goals=@('strength','hypertrophy')
  }
  if ($n -match 'stretch|mobility|foam roll|sweep') {
    $d.category='mobility'; $d.movement_pattern=if($n -match 'stretch'){'stretch'}else{'mobility'}
    $d.exercise_type='mobility'; $d.mechanics='isolation'; $d.training_goals=@('mobility')
  }
  elseif ($n -match 'bike|cycling|ride|trainer|treadmill|running|run$|walking|hiking|hill climb|swim|rower|elliptical|stair|ski erg|versaclimber|jumping jack|jump rope|battle rope|shadow boxing') {
    $d.category='conditioning'; $d.movement_pattern='cardio'; $d.exercise_type='cardio'; $d.mechanics='cyclical'; $d.training_goals=@('cardiovascular_endurance','work_capacity')
  }
  elseif ($n -match 'carry|farmer') { $d.movement_pattern='carry'; $d.primary_muscles=@('forearms','traps'); $d.secondary_muscles=@('glutes'); $d.stabilizer_muscles=@('core','spinal_erectors') }
  elseif ($n -match 'snatch|clean|jerk|thruster|high pull') { $d.movement_pattern='olympic_lift'; $d.category='power'; $d.body_region='full_body'; $d.primary_muscles=@('glutes','quadriceps'); $d.secondary_muscles=@('hamstrings','traps','anterior_deltoids','triceps'); $d.stabilizer_muscles=@('core','spinal_erectors','forearms'); $d.training_goals=@('power','strength') }
  elseif ($n -match 'box jump|burpee|wall ball') { $d.movement_pattern='plyometric'; $d.category='conditioning'; $d.body_region='full_body'; $d.primary_muscles=@('quadriceps','glutes'); $d.secondary_muscles=@('hamstrings','calves','anterior_deltoids','triceps'); $d.stabilizer_muscles=@('core'); $d.training_goals=@('power','work_capacity') }
  elseif ($n -match 'pallof|anti.rotation') { $d.movement_pattern='anti_rotation'; $d.primary_muscles=@('core','obliques'); $d.secondary_muscles=@(); $d.stabilizer_muscles=@('glutes') }
  elseif ($n -match 'russian twist|wood.?chop|rotation') { $d.movement_pattern='rotation'; $d.primary_muscles=@('obliques'); $d.secondary_muscles=@('core'); $d.stabilizer_muscles=@('glutes') }
  elseif ($n -match 'plank|dead bug|bird dog|crunch|sit.?up|leg raise|knee raise|ab wheel|mountain climber') { $d.movement_pattern='core'; $d.body_region='core'; $d.primary_muscles=@('core'); $d.secondary_muscles=@('obliques'); $d.stabilizer_muscles=@('glutes','anterior_deltoids') }
  elseif ($n -match 'toes.to.bar|v-up') { $d.movement_pattern='flexion'; $d.body_region='core'; $d.primary_muscles=@('core','hip_flexors'); $d.secondary_muscles=@('obliques'); $d.stabilizer_muscles=@('forearms') }
  elseif ($n -match 'side bend') { $d.movement_pattern='flexion'; $d.body_region='core'; $d.mechanics='isolation'; $d.primary_muscles=@('obliques'); $d.secondary_muscles=@('core'); $d.stabilizer_muscles=@('spinal_erectors') }
  elseif ($n -match 'calf raise|calf press|calves') { $d.movement_pattern='calf_raise'; $d.body_region='lower_body'; $d.mechanics='isolation'; $d.primary_muscles=@('calves'); $d.secondary_muscles=@(); $d.stabilizer_muscles=@('core'); $d.required_anatomy_views=@('back') }
  elseif ($n -match 'tibialis') { $d.movement_pattern='isolation'; $d.body_region='lower_body'; $d.mechanics='isolation'; $d.primary_muscles=@('tibialis_anterior'); $d.secondary_muscles=@(); $d.stabilizer_muscles=@(); $d.required_anatomy_views=@('front') }
  elseif ($n -match 'neck curl') { $d.movement_pattern='flexion'; $d.body_region='neck'; $d.mechanics='isolation'; $d.primary_muscles=@('neck_flexors'); $d.secondary_muscles=@(); $d.stabilizer_muscles=@(); $d.required_anatomy_views=@('front') }
  elseif ($n -match 'neck extension') { $d.movement_pattern='extension'; $d.body_region='neck'; $d.mechanics='isolation'; $d.primary_muscles=@('neck_extensors'); $d.secondary_muscles=@('traps'); $d.stabilizer_muscles=@(); $d.required_anatomy_views=@('back') }
  elseif ($n -match 'front raise') { $d.movement_pattern='flexion'; $d.body_region='upper_body'; $d.mechanics='isolation'; $d.primary_muscles=@('anterior_deltoids'); $d.secondary_muscles=@('serratus_anterior'); $d.stabilizer_muscles=@('core'); $d.required_anatomy_views=@('front') }
  elseif ($n -match 'external rotation') { $d.movement_pattern='rotation'; $d.body_region='upper_body'; $d.mechanics='isolation'; $d.primary_muscles=@('rotator_cuff'); $d.secondary_muscles=@('posterior_deltoids'); $d.stabilizer_muscles=@(); $d.required_anatomy_views=@('back') }
  elseif ($n -match 'lateral raise|side raise|hip abduction|clamshell|monster walk|kickback') { $d.movement_pattern='abduction'; $d.mechanics='isolation'; if($n -match 'hip|clamshell|monster|kickback'){$d.body_region='lower_body';$d.primary_muscles=@('abductors','glutes');$d.secondary_muscles=@()}else{$d.body_region='upper_body';$d.primary_muscles=@('lateral_deltoids');$d.secondary_muscles=@('anterior_deltoids')};$d.stabilizer_muscles=@('core') }
  elseif ($n -match 'adduction') { $d.movement_pattern='adduction'; $d.body_region='lower_body'; $d.mechanics='isolation'; $d.primary_muscles=@('adductors'); $d.secondary_muscles=@(); $d.stabilizer_muscles=@('core'); $d.required_anatomy_views=@('front') }
  elseif ($n -match 'lunge|split squat|step.?up') { $d.movement_pattern='lunge'; $d.body_region='lower_body'; $d.primary_muscles=@('quadriceps','glutes'); $d.secondary_muscles=@('hamstrings'); $d.stabilizer_muscles=@('core','adductors','abductors') }
  elseif ($n -match 'step.down') { $d.movement_pattern='squat'; $d.body_region='lower_body'; $d.laterality='unilateral'; $d.primary_muscles=@('quadriceps','glutes'); $d.secondary_muscles=@('hamstrings'); $d.stabilizer_muscles=@('core','abductors','adductors') }
  elseif ($n -match 'wall sit') { $d.movement_pattern='squat'; $d.body_region='lower_body'; $d.exercise_type='isometric'; $d.primary_muscles=@('quadriceps'); $d.secondary_muscles=@('glutes'); $d.stabilizer_muscles=@('core') }
  elseif ($n -match 'squat|leg press') { $d.movement_pattern='squat'; $d.body_region='lower_body'; $d.primary_muscles=@('quadriceps','glutes'); $d.secondary_muscles=@('hamstrings','adductors'); $d.stabilizer_muscles=@('core','spinal_erectors') }
  elseif ($n -match 'deadlift|romanian|good morning|hip hinge|swing|pull.through|back extension|hyperextension|hip thrust|glute bridge') { $d.movement_pattern='hip_hinge'; $d.body_region='lower_body'; $d.primary_muscles=@('glutes','hamstrings'); $d.secondary_muscles=@('spinal_erectors'); $d.stabilizer_muscles=@('core','forearms'); $d.required_anatomy_views=@('back') }
  elseif ($n -match 'rack pull|frog pump') { $d.movement_pattern='hip_hinge'; $d.body_region='lower_body'; $d.primary_muscles=@('glutes','hamstrings'); $d.secondary_muscles=@('spinal_erectors'); $d.stabilizer_muscles=@('core','forearms'); $d.required_anatomy_views=@('back') }
  elseif ($n -match 'dead hang') { $d.movement_pattern='vertical_pull'; $d.body_region='upper_body'; $d.exercise_type='isometric'; $d.primary_muscles=@('lats','forearms'); $d.secondary_muscles=@('upper_back'); $d.stabilizer_muscles=@('core'); $d.required_anatomy_views=@('back') }
  elseif ($n -match 'pull-up|pull up|chin-up|chin up|pulldown|pull down|pullover') { $d.movement_pattern='vertical_pull'; $d.body_region='upper_body'; $d.primary_muscles=@('lats'); $d.secondary_muscles=@('biceps','upper_back'); $d.stabilizer_muscles=@('core','forearms'); $d.required_anatomy_views=@('back') }
  elseif ($n -match 'row|face pull|reverse fly|reverse pec deck|rear delt') { $d.movement_pattern='horizontal_pull'; $d.body_region='upper_body'; $d.primary_muscles=@('upper_back','lats'); $d.secondary_muscles=@('posterior_deltoids','biceps'); $d.stabilizer_muscles=@('core','spinal_erectors'); $d.required_anatomy_views=@('back') }
  elseif ($n -match 'overhead press|shoulder press|military press|push press|handstand|arnold press|z press|landmine press|behind.the.neck press') { $d.movement_pattern='vertical_push'; $d.body_region='upper_body'; $d.primary_muscles=@('anterior_deltoids'); $d.secondary_muscles=@('lateral_deltoids','triceps'); $d.stabilizer_muscles=@('core','traps'); $d.required_anatomy_views=@('front') }
  elseif ($n -match 'bench press|chest press|floor press|push-up|push up|fly|flye|dip|chest pass') { $d.movement_pattern='horizontal_push'; $d.body_region='upper_body'; $d.primary_muscles=@('chest'); $d.secondary_muscles=@('anterior_deltoids','triceps'); $d.stabilizer_muscles=@('core'); $d.required_anatomy_views=@('front') }
  elseif ($n -match 'triceps|tricep|pushdown|push down|skullcrusher|skull crusher|jm press|tate press|overhead cable extension') { $d.movement_pattern='extension'; $d.body_region='upper_body'; $d.mechanics='isolation'; $d.primary_muscles=@('triceps'); $d.secondary_muscles=@(); $d.stabilizer_muscles=@('anterior_deltoids'); $d.required_anatomy_views=@('back') }
  elseif ($n -match 'leg extension') { $d.movement_pattern='extension'; $d.body_region='lower_body'; $d.mechanics='isolation'; $d.primary_muscles=@('quadriceps'); $d.secondary_muscles=@(); $d.stabilizer_muscles=@(); $d.required_anatomy_views=@('front') }
  elseif ($n -match 'leg curl|hamstring curl|nordic') { $d.movement_pattern='flexion'; $d.body_region='lower_body'; $d.mechanics='isolation'; $d.primary_muscles=@('hamstrings'); $d.secondary_muscles=@('calves'); $d.stabilizer_muscles=@('glutes'); $d.required_anatomy_views=@('back') }
  elseif ($n -match 'curl') { $d.movement_pattern='flexion'; $d.body_region='upper_body'; $d.mechanics='isolation'; $d.primary_muscles=@('biceps'); $d.secondary_muscles=@('forearms'); $d.stabilizer_muscles=@(); $d.required_anatomy_views=@('front') }
  elseif ($n -match 'shrug') { $d.movement_pattern='isolation'; $d.body_region='upper_body'; $d.mechanics='isolation'; $d.primary_muscles=@('traps'); $d.secondary_muscles=@(); $d.stabilizer_muscles=@('forearms'); $d.required_anatomy_views=@('back') }
  elseif ($n -match 'wrist extension|wrist roller|plate pinch') { $d.movement_pattern='isolation'; $d.body_region='upper_body'; $d.mechanics='isolation'; $d.primary_muscles=@('forearms'); $d.secondary_muscles=@(); $d.stabilizer_muscles=@(); $d.required_anatomy_views=@('front') }
  elseif ($n -match 'superman') { $d.movement_pattern='extension'; $d.body_region='posterior_chain'; $d.primary_muscles=@('spinal_erectors'); $d.secondary_muscles=@('glutes','hamstrings'); $d.stabilizer_muscles=@('upper_back'); $d.required_anatomy_views=@('back') }
  elseif ($n -match 'turkish get-up|windmill|man maker|cuban press') { $d.movement_pattern='rotation'; $d.body_region='full_body'; $d.primary_muscles=@('core','obliques'); $d.secondary_muscles=@('glutes','anterior_deltoids'); $d.stabilizer_muscles=@('rotator_cuff','triceps'); $d.required_anatomy_views=@('front','back') }
  elseif ($n -match 'sled pull') { $d.movement_pattern='locomotion'; $d.category='conditioning'; $d.body_region='full_body'; $d.primary_muscles=@('quadriceps','glutes'); $d.secondary_muscles=@('hamstrings','calves'); $d.stabilizer_muscles=@('core','forearms'); $d.training_goals=@('strength','work_capacity') }
  else { return @{ review_reason='no_unique_reviewed_movement_rule' } }

  if ($d.primary_muscles.Count -eq 0) {
    if($d.movement_pattern -in @('cardio','mobility','stretch')){$d.primary_muscles=@('quadriceps','glutes')}else{return @{review_reason='primary_muscle_uncertain'}}
  }
  $durationBased = $d.exercise_type -in @('cardio','mobility') -or $n -match 'hold|isometric'
  $d.suitable_locations=@(if($d.equipment -contains 'bodyweight'){'home'};'gym')
  $d.setup_requirements=@('Use stable equipment and clear working space.')
  $d.contraindication_tags=@('pain_during_movement','acute_injury')
  $d.coaching_cues=@('Use a controlled range of motion.','Maintain stable alignment.','Stop if pain occurs.')
  $d.common_mistakes=@('Using momentum instead of control.','Losing alignment under fatigue.')
  $d.safety_notes=@('Choose a range and intensity that allow controlled technique.')
  $d.regression_ids=@();$d.progression_ids=@();$d.alternative_ids=@()
  $d.default_sets_min=2;$d.default_sets_max=4
  $d.default_reps_min=if($durationBased){$null}else{if($d.mechanics -eq 'isolation'){8}else{6}}
  $d.default_reps_max=if($durationBased){$null}else{if($d.mechanics -eq 'isolation'){15}else{12}}
  $d.default_rest_seconds_min=if($d.exercise_type -eq 'cardio'){30}else{60}
  $d.default_rest_seconds_max=if($d.exercise_type -eq 'cardio'){120}else{180}
  $d.tempo_guidance=if($d.exercise_type -eq 'cardio'){'Use a sustainable, repeatable cadence.'}else{'Controlled lowering; smooth, deliberate effort.'}
  $d.metadata_version=1;$d.metadata_sources=$sources
  return $d
}

function Fingerprint([object]$draft) {
  $json=$draft|ConvertTo-Json -Depth 8 -Compress
  $sha=[System.Security.Cryptography.SHA256]::Create()
  return ([BitConverter]::ToString(
    $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($json))
  ) -replace '-','').ToLowerInvariant()
}

function Review([object]$exercise,[object]$draft,[string]$authorHash) {
  $issues=@()
  if(-not $authorHash){$issues+='missing_author_hash'}
  if(-not $draft.movement_pattern -or -not $draft.primary_muscles){$issues+='missing_classification'}
  $roles=@($draft.primary_muscles)+@($draft.secondary_muscles)+@($draft.stabilizer_muscles)
  if(@($roles|Sort-Object -Unique).Count -ne $roles.Count){$issues+='overlapping_muscle_roles'}
  if(@($draft.required_anatomy_views|Where-Object {$_ -notin @('front','back')}).Count){$issues+='invalid_anatomy_view'}
  if($draft.default_sets_min -gt $draft.default_sets_max){$issues+='invalid_sets'}
  if(($null -ne $draft.default_reps_min) -xor ($null -ne $draft.default_reps_max)){$issues+='invalid_reps'}
  if($null -ne $draft.default_reps_min -and $draft.default_reps_min -gt $draft.default_reps_max){$issues+='invalid_reps'}
  if($manualNames -contains $exercise.source_name){$issues+='independent_identity_ambiguity'}
  return @{decision=if($issues.Count){'manual_review'}else{'pass'};issues=[object[]]$issues;reviewer_version=$reviewerVersion;author_output_hash=$authorHash}
}

function Save-State([object]$catalog,[object[]]$queue,[int]$batch,[string]$last) {
  $catalog | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $CatalogPath -Encoding utf8
  $validated=@($catalog.exercises|Where-Object metadata_status -eq 'metadata_validated').Count
  $pending=@($catalog.exercises|Where-Object metadata_status -in @('metadata_pending','verified')).Count
  $review=@($catalog.exercises|Where-Object metadata_status -eq 'needs_review').Count
  [ordered]@{generator_version=$generatorVersion;reviewer_version=$reviewerVersion;catalog_version=$catalogVersion;total_records=412;completed_records=$validated;pending_records=$pending;review_records=$review;failed_records=0;last_completed_canonical_id=$last;current_batch=$batch;updated_at=(Get-Date).ToUniversalTime().ToString('o')}|ConvertTo-Json|Set-Content -LiteralPath $CheckpointPath -Encoding utf8
  [ordered]@{duplicate_candidates=@();unresolved=[object[]]$queue;unknown_muscles=@();ambiguous_video_matches=@()}|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $ReviewQueuePath -Encoding utf8
}

if($DefinitionsOnly){return}

$catalog=Get-Content -LiteralPath $CatalogPath -Raw|ConvertFrom-Json
foreach($exercise in $catalog.exercises){
  if(-not $exercise.PSObject.Properties['required_anatomy_views']){$exercise|Add-Member NoteProperty required_anatomy_views ([object[]]@())}
  if(-not $exercise.PSObject.Properties['metadata_version']){$exercise|Add-Member NoteProperty metadata_version $null}
  if(-not $exercise.PSObject.Properties['metadata_sources']){$exercise|Add-Member NoteProperty metadata_sources ([object[]]@())}
  if(-not $exercise.PSObject.Properties['authored_at']){$exercise|Add-Member NoteProperty authored_at $null}
  if(-not $exercise.PSObject.Properties['reviewed_at']){$exercise|Add-Member NoteProperty reviewed_at $null}
  foreach($field in @('aliases','equipment','primary_muscles','secondary_muscles','stabilizer_muscles','required_anatomy_views','training_goals','suitable_locations','setup_requirements','contraindication_tags','regression_ids','progression_ids','alternative_ids','coaching_cues','common_mistakes','safety_notes','metadata_sources')){
    if($exercise.$field -is [string]){$exercise.$field=[object[]]@($exercise.$field)}
  }
}
$queue=@(); if(Test-Path $ReviewQueuePath){$old=Get-Content $ReviewQueuePath -Raw|ConvertFrom-Json;$queue=@($old.unresolved)}
$pending=@($catalog.exercises|Where-Object metadata_status -in @('metadata_pending','verified')|Sort-Object canonical_id)
$batch=[Math]::Ceiling((412-$pending.Count)/$BatchSize);$processedThisRun=0
$last=if($pending.Count -eq 0){($catalog.exercises|Sort-Object canonical_id|Select-Object -Last 1).canonical_id}else{$null}
while($pending.Count -gt 0 -and ($MaxBatches -eq 0 -or $processedThisRun -lt $MaxBatches)){
  $batch++;$processedThisRun++;$slice=@($pending|Select-Object -First $BatchSize)
  foreach($exercise in $slice){
    $draft=Draft $exercise
    if($draft.review_reason){$exercise.metadata_status='needs_review';$exercise.validation_status='needs_review';$exercise.review_reason=$draft.review_reason;$queue+=@{canonical_id=$exercise.canonical_id;source_name=$exercise.source_name;reason=$draft.review_reason;stage='author'}}
    else{
      $authored=(Get-Date).ToUniversalTime().ToString('o');$hash=Fingerprint $draft;$review=Review $exercise $draft $hash
      if($review.decision -ne 'pass'){$exercise.metadata_status='needs_review';$exercise.validation_status='needs_review';$exercise.review_reason=($review.issues -join ',');$queue+=@{canonical_id=$exercise.canonical_id;source_name=$exercise.source_name;reason=$exercise.review_reason;stage='reviewer';author_output_hash=$hash;reviewer_version=$reviewerVersion}}
      else{foreach($key in $draft.Keys){if($exercise.PSObject.Properties[$key]){$exercise.$key=$draft[$key]}else{$exercise|Add-Member NoteProperty $key $draft[$key]}};$exercise.metadata_status='metadata_validated';$exercise.validation_status='verified';$exercise.review_reason=$null;if($exercise.PSObject.Properties['authored_at']){$exercise.authored_at=$authored}else{$exercise|Add-Member NoteProperty authored_at $authored};$reviewed=(Get-Date).ToUniversalTime().ToString('o');if($exercise.PSObject.Properties['reviewed_at']){$exercise.reviewed_at=$reviewed}else{$exercise|Add-Member NoteProperty reviewed_at $reviewed}}
    }
    $last=$exercise.canonical_id
  }
  Save-State $catalog $queue $batch $last
  Write-Output "Batch $batch saved; last=$last"
  $pending=@($catalog.exercises|Where-Object metadata_status -in @('metadata_pending','verified')|Sort-Object canonical_id)
}
Save-State $catalog $queue $batch $last
Write-Output "Metadata production complete: validated=$(@($catalog.exercises|Where-Object metadata_status -eq 'metadata_validated').Count) pending=$(@($catalog.exercises|Where-Object metadata_status -in @('metadata_pending','verified')).Count) review=$(@($catalog.exercises|Where-Object metadata_status -eq 'needs_review').Count)"
