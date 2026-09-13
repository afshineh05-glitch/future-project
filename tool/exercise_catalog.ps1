param(
  [ValidateSet('validate','count','duplicates','unresolved','metadata-pending','pilot','report')]
  [string]$Command = 'validate',
  [string]$CatalogPath = 'assets/data/exercise_library/movekit_complete_catalog.json'
)

$ErrorActionPreference = 'Stop'
$catalog = Get-Content -LiteralPath $CatalogPath -Raw | ConvertFrom-Json
$items = @($catalog.exercises)
$duplicateGroups = @($items | Group-Object normalized_name | Where-Object Count -gt 1)
$unresolved = @($items | Where-Object {
  -not $_.source_name -or -not $_.canonical_id -or -not $_.slug -or
  $_.validation_status -in @('needs_review','duplicate_candidate','invalid')
})
$pending = @($items | Where-Object metadata_status -eq 'metadata_pending')
$pilots = @($items | Where-Object metadata_status -eq 'verified')
$missingAssets = @($items | Where-Object {
  ($_.male_anatomy_asset -and -not (Test-Path -LiteralPath $_.male_anatomy_asset)) -or
  ($_.female_anatomy_asset -and -not (Test-Path -LiteralPath $_.female_anatomy_asset))
})
$brokenRefs = @()
$ids = @{}; foreach ($item in $items) { $ids[$item.canonical_id] = $true }
foreach ($item in $items) {
  foreach ($ref in @($item.regression_ids)+@($item.progression_ids)+@($item.alternative_ids)) {
    if ($ref -and -not $ids[$ref]) { $brokenRefs += "$($item.canonical_id):$ref" }
  }
}

$valid = $items.Count -eq 412 -and
  @($items.canonical_id | Sort-Object -Unique).Count -eq 412 -and
  @($items.slug | Sort-Object -Unique).Count -eq 412 -and
  @($items.normalized_name | Sort-Object -Unique).Count -eq 412 -and
  $unresolved.Count -eq 0 -and $missingAssets.Count -eq 0 -and
  $brokenRefs.Count -eq 0 -and $pilots.Count -eq 10

switch ($Command) {
  'count' { $items.Count }
  'duplicates' { $duplicateGroups | ForEach-Object { $_.Group.source_name -join ' | ' } }
  'unresolved' { $unresolved | Select-Object canonical_id,source_name,validation_status,review_reason }
  'metadata-pending' { $pending | Select-Object canonical_id,source_name }
  'pilot' { $pilots | Select-Object canonical_id,source_name,movement_pattern,metadata_status }
  'validate' {
    [pscustomobject]@{
      valid=$valid; count=$items.Count; unique_ids=@($items.canonical_id|Sort-Object -Unique).Count
      unique_slugs=@($items.slug|Sort-Object -Unique).Count
      unique_identities=@($items.normalized_name|Sort-Object -Unique).Count
      duplicate_candidates=$duplicateGroups.Count; unresolved=$unresolved.Count
      metadata_verified=$pilots.Count; metadata_pending=$pending.Count
      missing_anatomy_assets=$missingAssets.Count; broken_references=$brokenRefs.Count
      video_assets=@($items|Where-Object video_asset).Count
    } | ConvertTo-Json
    if (-not $valid) { exit 1 }
  }
  'report' {
    $directory = Split-Path -Parent $CatalogPath
    [ordered]@{
      generated_from='local_catalog'; expected_count=412; collected_count=$items.Count
      collection_complete=($items.Count -eq 412); unique_ids=@($items.canonical_id|Sort-Object -Unique).Count
      unique_slugs=@($items.slug|Sort-Object -Unique).Count
      unique_identities=@($items.normalized_name|Sort-Object -Unique).Count
      metadata_verified=$pilots.Count; metadata_pending=$pending.Count
      male_anatomy_approved_existing=@($items|Where-Object male_anatomy_status -eq 'approved_existing').Count
      male_anatomy_pending_generation=@($items|Where-Object male_anatomy_status -eq 'pending_generation').Count
      female_anatomy_approved_existing=@($items|Where-Object female_anatomy_status -eq 'approved_existing').Count
      female_anatomy_pending_generation=@($items|Where-Object female_anatomy_status -eq 'pending_generation').Count
      video_pending_license=@($items|Where-Object video_status -eq 'pending_license').Count
      runtime_network_dependency=$false; valid=$valid
    } | ConvertTo-Json | Set-Content -LiteralPath "$directory/collection_report.json" -Encoding utf8
    [ordered]@{
      duplicate_candidates=@($duplicateGroups|ForEach-Object {$_.Group.source_name})
      unresolved=@($unresolved|Select-Object canonical_id,source_name,validation_status,review_reason)
      unknown_muscles=@(); ambiguous_video_matches=@()
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$directory/review_queue.json" -Encoding utf8
    Write-Output "Generated $directory/collection_report.json and review_queue.json"
  }
}
