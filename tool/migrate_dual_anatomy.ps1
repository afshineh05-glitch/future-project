param(
  [string]$CatalogPath = 'assets/data/exercise_library/movekit_complete_catalog.json'
)

$ErrorActionPreference = 'Stop'
$catalog = Get-Content -LiteralPath $CatalogPath -Raw | ConvertFrom-Json
$beforeIdentities = @($catalog.exercises | ForEach-Object {
  "$($_.canonical_id)|$($_.slug)|$($_.source_name)|$($_.normalized_name)"
})

foreach ($exercise in $catalog.exercises) {
  $legacyAsset = $exercise.anatomy_asset
  $legacyStatus = $exercise.anatomy_status
  if (-not $exercise.PSObject.Properties['male_anatomy_asset']) {
    $exercise | Add-Member NoteProperty male_anatomy_asset $legacyAsset
  }
  if (-not $exercise.PSObject.Properties['male_anatomy_status']) {
    $status = if ($legacyStatus) { $legacyStatus } else { 'pending_generation' }
    $exercise | Add-Member NoteProperty male_anatomy_status $status
  }
  if (-not $exercise.PSObject.Properties['female_anatomy_asset']) {
    $exercise | Add-Member NoteProperty female_anatomy_asset $null
  }
  if (-not $exercise.PSObject.Properties['female_anatomy_status']) {
    $exercise | Add-Member NoteProperty female_anatomy_status 'pending_generation'
  }
  $exercise.PSObject.Properties.Remove('anatomy_asset')
  $exercise.PSObject.Properties.Remove('anatomy_status')
}

$afterIdentities = @($catalog.exercises | ForEach-Object {
  "$($_.canonical_id)|$($_.slug)|$($_.source_name)|$($_.normalized_name)"
})
if ($catalog.exercises.Count -ne 412 -or
    (Compare-Object $beforeIdentities $afterIdentities)) {
  throw 'Dual-anatomy migration changed canonical identities; catalog not written.'
}

$catalog | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $CatalogPath -Encoding utf8
Write-Output 'Migrated 412 records to dual anatomy fields without changing identities.'
