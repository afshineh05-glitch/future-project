param(
  [string]$CatalogPath = "assets/data/exercise_library/movekit_complete_catalog.json"
)

$ErrorActionPreference = "Stop"
$catalog = Get-Content -LiteralPath $CatalogPath -Raw | ConvertFrom-Json

$listFields = @(
  'aliases','equipment','primary_muscles','secondary_muscles',
  'stabilizer_muscles','training_goals','suitable_locations',
  'setup_requirements','contraindication_tags','regression_ids',
  'progression_ids','alternative_ids','coaching_cues','common_mistakes',
  'safety_notes'
)
foreach ($exercise in $catalog.exercises) {
  foreach ($field in $listFields) {
    if ($exercise.$field -is [System.Management.Automation.PSCustomObject]) {
      $exercise.$field = [object[]]@()
    }
  }
}

$pilots = @{
  'barbell-bench-press' = @{category='strength';body_region='upper_body';movement_pattern='horizontal_push';equipment=@('barbell','bench');exercise_type='resistance';mechanics='compound';laterality='bilateral';difficulty='intermediate';primary_muscles=@('chest');secondary_muscles=@('anterior_deltoids','triceps');stabilizer_muscles=@('core');training_goals=@('strength','hypertrophy');male_anatomy_asset='assets/exercises/anatomy/barbell_bench_press.png'}
  'barbell-overhead-press' = @{category='strength';body_region='upper_body';movement_pattern='vertical_push';equipment=@('barbell');exercise_type='resistance';mechanics='compound';laterality='bilateral';difficulty='intermediate';primary_muscles=@('anterior_deltoids');secondary_muscles=@('lateral_deltoids','triceps');stabilizer_muscles=@('core','traps');training_goals=@('strength','hypertrophy')}
  'barbell-bent-over-row' = @{category='strength';body_region='upper_body';movement_pattern='horizontal_pull';equipment=@('barbell');exercise_type='resistance';mechanics='compound';laterality='bilateral';difficulty='intermediate';primary_muscles=@('upper_back','lats');secondary_muscles=@('posterior_deltoids','biceps');stabilizer_muscles=@('spinal_erectors','core');training_goals=@('strength','hypertrophy');male_anatomy_asset='assets/exercises/anatomy/barbell_bent_over_row.png'}
  'neutral-grip-pull-up' = @{category='strength';body_region='upper_body';movement_pattern='vertical_pull';equipment=@('bodyweight','pull_up_bar');exercise_type='resistance';mechanics='compound';laterality='bilateral';difficulty='intermediate';primary_muscles=@('lats');secondary_muscles=@('biceps','upper_back');stabilizer_muscles=@('core','forearms');training_goals=@('strength','hypertrophy')}
  'barbell-squat' = @{category='strength';body_region='lower_body';movement_pattern='squat';equipment=@('barbell');exercise_type='resistance';mechanics='compound';laterality='bilateral';difficulty='intermediate';primary_muscles=@('quadriceps','glutes');secondary_muscles=@('hamstrings','adductors');stabilizer_muscles=@('core','spinal_erectors');training_goals=@('strength','hypertrophy');male_anatomy_asset='assets/exercises/anatomy/barbell_back_squat.png'}
  'barbell-romanian-deadlift' = @{category='strength';body_region='lower_body';movement_pattern='hip_hinge';equipment=@('barbell');exercise_type='resistance';mechanics='compound';laterality='bilateral';difficulty='intermediate';primary_muscles=@('hamstrings','glutes');secondary_muscles=@('spinal_erectors');stabilizer_muscles=@('core','forearms');training_goals=@('strength','hypertrophy')}
  'forward-lunge' = @{category='strength';body_region='lower_body';movement_pattern='lunge';equipment=@('bodyweight');exercise_type='resistance';mechanics='compound';laterality='alternating';difficulty='beginner';primary_muscles=@('quadriceps','glutes');secondary_muscles=@('hamstrings','calves');stabilizer_muscles=@('core','abductors','adductors');training_goals=@('strength','balance');male_anatomy_asset='assets/exercises/anatomy/forward_lunge.png'}
  'dumbbell-curl' = @{category='strength';body_region='upper_body';movement_pattern='isolation';equipment=@('dumbbell');exercise_type='resistance';mechanics='isolation';laterality='bilateral';difficulty='beginner';primary_muscles=@('biceps');secondary_muscles=@('forearms');stabilizer_muscles=@();training_goals=@('hypertrophy','strength')}
  'hand-plank' = @{category='strength';body_region='core';movement_pattern='core';equipment=@('bodyweight');exercise_type='isometric';mechanics='compound';laterality='bilateral';difficulty='beginner';primary_muscles=@('core');secondary_muscles=@('anterior_deltoids','glutes');stabilizer_muscles=@('quadriceps','spinal_erectors');training_goals=@('stability','endurance')}
  'arc-trainer' = @{category='conditioning';body_region='full_body';movement_pattern='cardio';equipment=@('cardio_machine');exercise_type='cardio';mechanics='cyclical';laterality='alternating';difficulty='beginner';primary_muscles=@('quadriceps','glutes');secondary_muscles=@('hamstrings','calves');stabilizer_muscles=@('core');training_goals=@('cardiovascular_endurance','work_capacity')}
}

foreach ($exercise in $catalog.exercises) {
  $pilot = $pilots[$exercise.slug]
  if (-not $pilot) { continue }
  foreach ($key in $pilot.Keys) { $exercise.$key = $pilot[$key] }
  $exercise.metadata_status = 'verified'
  $exercise.validation_status = 'verified'
  $exercise.suitable_locations = @('gym')
  $exercise.setup_requirements = @('Use stable equipment and clear working space.')
  $exercise.contraindication_tags = @('pain_during_movement','acute_injury')
  $exercise.coaching_cues = @('Use a controlled range of motion.','Maintain stable alignment.','Stop if pain occurs.')
  $exercise.common_mistakes = @('Using momentum instead of control.','Losing alignment under fatigue.')
  $exercise.safety_notes = @('Choose a load and range that allow controlled technique.')
  $exercise.default_sets_min = 2
  $exercise.default_sets_max = 4
  $exercise.default_reps_min = if ($exercise.exercise_type -eq 'cardio') { $null } else { 6 }
  $exercise.default_reps_max = if ($exercise.exercise_type -eq 'cardio') { $null } else { 12 }
  $exercise.default_rest_seconds_min = 60
  $exercise.default_rest_seconds_max = 180
  $exercise.tempo_guidance = if ($exercise.exercise_type -eq 'cardio') { 'Use a sustainable, repeatable cadence.' } else { 'Controlled lowering; smooth, deliberate effort.' }
  if ($exercise.male_anatomy_asset) { $exercise.male_anatomy_status = 'approved_existing' }
}

if (@($catalog.exercises | Where-Object metadata_status -eq 'verified').Count -ne 10) {
  throw 'Pilot metadata must resolve to exactly 10 catalog records.'
}
$catalog | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $CatalogPath -Encoding utf8
Write-Output 'Applied independently authored pilot metadata to 10 exercises.'
