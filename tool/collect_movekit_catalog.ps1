param(
  [string]$OutputPath = "assets/data/exercise_library/movekit_complete_catalog.json"
)

$ErrorActionPreference = "Stop"
$libraryUrl = "https://movekit.com/library"
$sourceCatalog = "movekit_complete_2026"

function Normalize-ExerciseName([string]$Value) {
  $normalized = $Value.Trim().ToLowerInvariant()
  $normalized = [regex]::Replace($normalized, "[^a-z0-9]+", " ")
  return [regex]::Replace($normalized, "\s+", " ").Trim()
}

function Read-ExistingRecords([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return @{} }
  $existing = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
  $bySlug = @{}
  foreach ($record in @($existing.exercises)) {
    if ($record.slug) { $bySlug[$record.slug] = $record }
  }
  return $bySlug
}

$page = (Invoke-WebRequest -UseBasicParsing $libraryUrl).Content
$scriptPaths = [regex]::Matches($page, '<script[^>]+src="([^"]+)"') |
  ForEach-Object { $_.Groups[1].Value.Replace('&amp;', '&') } |
  Select-Object -Unique

$collected = @()
foreach ($scriptPath in $scriptPaths) {
  $script = (Invoke-WebRequest -UseBasicParsing ("https://movekit.com" + $scriptPath)).Content
  $matches = [regex]::Matches(
    $script,
    '\{"id":"[^"]+","slug":"(?<slug>[^"]+)","name":"(?<name>[^"]+)"'
  )
  foreach ($match in $matches) {
    $collected += [pscustomobject]@{
      slug = $match.Groups['slug'].Value
      source_name = [System.Text.RegularExpressions.Regex]::Unescape(
        $match.Groups['name'].Value
      )
    }
  }
}

$collected = @($collected | Sort-Object slug -Unique)
$uniqueNames = @($collected.source_name | Sort-Object -Unique)
if ($collected.Count -ne 412 -or $uniqueNames.Count -ne 412) {
  throw "Collection is incomplete: $($collected.Count) slugs and $($uniqueNames.Count) unique names. Existing catalog was not overwritten."
}

$existingBySlug = Read-ExistingRecords $OutputPath
$records = foreach ($item in $collected) {
  $previous = $existingBySlug[$item.slug]
  $normalized = Normalize-ExerciseName $item.source_name
  [ordered]@{
    canonical_id = if ($previous.canonical_id) { $previous.canonical_id } else { "mu_ex_$($item.slug.Replace('-', '_'))" }
    slug = $item.slug
    display_name = if ($previous.display_name) { $previous.display_name } else { $item.source_name }
    normalized_name = $normalized
    aliases = [object[]]$(if ($previous.aliases) { @($previous.aliases) } else { @() })
    source_name = $item.source_name
    source_catalog = $sourceCatalog
    source_public_url = "https://movekit.com/exercises/$($item.slug)"
    public_category = if ($previous.public_category) { $previous.public_category } else { $null }
    active = if ($null -ne $previous.active) { [bool]$previous.active } else { $true }
    metadata_status = if ($previous.metadata_status) { $previous.metadata_status } else { "metadata_pending" }
    validation_status = "verified"
    review_reason = if ($previous.review_reason) { $previous.review_reason } else { $null }
    category = if ($previous.category) { $previous.category } else { $null }
    body_region = if ($previous.body_region) { $previous.body_region } else { $null }
    movement_pattern = if ($previous.movement_pattern) { $previous.movement_pattern } else { $null }
    equipment = [object[]]$(if ($previous.equipment) { @($previous.equipment) } else { @() })
    exercise_type = if ($previous.exercise_type) { $previous.exercise_type } else { $null }
    mechanics = if ($previous.mechanics) { $previous.mechanics } else { $null }
    laterality = if ($previous.laterality) { $previous.laterality } else { $null }
    difficulty = if ($previous.difficulty) { $previous.difficulty } else { $null }
    primary_muscles = [object[]]$(if ($previous.primary_muscles) { @($previous.primary_muscles) } else { @() })
    secondary_muscles = [object[]]$(if ($previous.secondary_muscles) { @($previous.secondary_muscles) } else { @() })
    stabilizer_muscles = [object[]]$(if ($previous.stabilizer_muscles) { @($previous.stabilizer_muscles) } else { @() })
    training_goals = [object[]]$(if ($previous.training_goals) { @($previous.training_goals) } else { @() })
    suitable_locations = [object[]]$(if ($previous.suitable_locations) { @($previous.suitable_locations) } else { @() })
    setup_requirements = [object[]]$(if ($previous.setup_requirements) { @($previous.setup_requirements) } else { @() })
    contraindication_tags = [object[]]$(if ($previous.contraindication_tags) { @($previous.contraindication_tags) } else { @() })
    regression_ids = [object[]]$(if ($previous.regression_ids) { @($previous.regression_ids) } else { @() })
    progression_ids = [object[]]$(if ($previous.progression_ids) { @($previous.progression_ids) } else { @() })
    alternative_ids = [object[]]$(if ($previous.alternative_ids) { @($previous.alternative_ids) } else { @() })
    coaching_cues = [object[]]$(if ($previous.coaching_cues) { @($previous.coaching_cues) } else { @() })
    common_mistakes = [object[]]$(if ($previous.common_mistakes) { @($previous.common_mistakes) } else { @() })
    safety_notes = [object[]]$(if ($previous.safety_notes) { @($previous.safety_notes) } else { @() })
    default_sets_min = $previous.default_sets_min
    default_sets_max = $previous.default_sets_max
    default_reps_min = $previous.default_reps_min
    default_reps_max = $previous.default_reps_max
    default_rest_seconds_min = $previous.default_rest_seconds_min
    default_rest_seconds_max = $previous.default_rest_seconds_max
    tempo_guidance = if ($previous.tempo_guidance) { $previous.tempo_guidance } else { $null }
    male_anatomy_asset = if ($previous.male_anatomy_asset) { $previous.male_anatomy_asset } elseif ($previous.anatomy_asset) { $previous.anatomy_asset } else { $null }
    male_anatomy_status = if ($previous.male_anatomy_status) { $previous.male_anatomy_status } elseif ($previous.anatomy_status) { $previous.anatomy_status } else { "pending_generation" }
    female_anatomy_asset = if ($previous.female_anatomy_asset) { $previous.female_anatomy_asset } else { $null }
    female_anatomy_status = if ($previous.female_anatomy_status) { $previous.female_anatomy_status } else { "pending_generation" }
    video_asset = $null
    video_status = "pending_license"
    future_vendor_asset_key = $null
  }
}

$document = [ordered]@{
  schema_version = 1
  source_catalog = $sourceCatalog
  expected_count = 412
  collected_count = $records.Count
  collection_complete = $true
  exercises = @($records)
}

$parent = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Force -Path $parent | Out-Null
$document | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding utf8
Write-Output "Saved $($records.Count) verified exercise identities to $OutputPath"
