param([string]$RequestJson,[string]$Model='gpt-image-1.5',[ValidateSet('low','medium','high')][string]$Quality='low',[ValidateRange(1,600)][int]$TimeoutSeconds=180,[switch]$AccessCheck)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'openai_anatomy_provider_contract.ps1')
function Fail([int]$ExitCode,$Record){[Console]::Error.WriteLine((ConvertTo-ProviderErrorJson $Record));exit $ExitCode}

$apiKey=[Environment]::GetEnvironmentVariable('OPENAI_API_KEY','Process')
if([string]::IsNullOrWhiteSpace($apiKey)){Fail 10 (New-ProviderError -Status 401 -ResponseBody $null -RequestId $null -TransportMessage 'OPENAI_API_KEY is not configured in the current process.')}
Add-Type -AssemblyName System.Net.Http
$client=[Net.Http.HttpClient]::new()
try{
  $client.Timeout=[TimeSpan]::FromSeconds($(if($AccessCheck){30}else{$TimeoutSeconds}))
  $client.DefaultRequestHeaders.Authorization=[Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer',$apiKey)
  if($AccessCheck){
    $response=$null;$responseText=$null;$requestId=$null
    try{
      $response=$client.GetAsync("https://api.openai.com/v1/models/$Model").GetAwaiter().GetResult()
      $responseText=$response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
      if($response.Headers.Contains('x-request-id')){$requestId=($response.Headers.GetValues('x-request-id')|Select-Object -First 1)}
      if(-not $response.IsSuccessStatusCode){Fail 14 (New-ProviderError -Status ([int]$response.StatusCode) -ResponseBody $responseText -RequestId $requestId -TransportMessage $null)}
      try{$modelResponse=$responseText|ConvertFrom-Json}catch{Fail 15 (New-ProviderError -Status ([int]$response.StatusCode) -ResponseBody $null -RequestId $requestId -TransportMessage 'Model access response_parse_error.')}
      if([string]$modelResponse.id -ne $Model){Fail 15 (New-ProviderError -Status ([int]$response.StatusCode) -ResponseBody $null -RequestId $requestId -TransportMessage 'Model access response did not match requested model.')}
      [ordered]@{category='access_confirmed';http_status=[int]$response.StatusCode;model=[string]$modelResponse.id;request_id=Protect-ProviderText $requestId;endpoint="GET /v1/models/$Model"}|ConvertTo-Json -Compress
      exit 0
    }catch [System.Threading.Tasks.TaskCanceledException]{Fail 14 (New-ProviderError -Status 408 -ResponseBody $null -RequestId $requestId -TransportMessage 'OpenAI model access check timed out.')}
    catch{Fail 14 (New-ProviderError -Status $null -ResponseBody $null -RequestId $requestId -TransportMessage $_.Exception.Message)}
    finally{if($response){$response.Dispose()}}
  }
  if([string]::IsNullOrWhiteSpace($RequestJson)){Fail 12 (New-ProviderError -Status 400 -ResponseBody $null -RequestId $null -TransportMessage 'Provider request is empty.')}
  try{$request=$RequestJson|ConvertFrom-Json}catch{Fail 12 (New-ProviderError -Status 400 -ResponseBody $null -RequestId $null -TransportMessage 'Provider request JSON is invalid.')}
  if(-not $request.prompt -or -not $request.output_path -or -not $request.reference_image_path -or -not $request.template_sha256){Fail 12 (New-ProviderError -Status 400 -ResponseBody $null -RequestId $null -TransportMessage 'Provider edit request is incomplete.')}
  if([IO.Path]::GetExtension([string]$request.output_path) -ne '.png'){Fail 12 (New-ProviderError -Status 400 -ResponseBody $null -RequestId $null -TransportMessage 'Provider destination must be PNG.')}
  if(Test-Path -LiteralPath ([string]$request.output_path)){Fail 13 (New-ProviderError -Status 409 -ResponseBody $null -RequestId $null -TransportMessage 'Provider destination already exists.')}
  if(-not(Test-Path -LiteralPath ([string]$request.reference_image_path))){Fail 12 (New-ProviderError -Status 400 -ResponseBody $null -RequestId $null -TransportMessage 'Locked reference image is missing.')}
  $actualHash=(Get-FileHash -LiteralPath ([string]$request.reference_image_path) -Algorithm SHA256).Hash
  if($actualHash -ne [string]$request.template_sha256){Fail 12 (New-ProviderError -Status 400 -ResponseBody $null -RequestId $null -TransportMessage 'Locked reference image hash mismatch.')}
  $form=[Net.Http.MultipartFormDataContent]::new();$httpResponse=$null;$responseText=$null;$requestId=$null
  try{
    foreach($entry in ([ordered]@{model=$Model;prompt=[string]$request.prompt;n='1';size='1024x1024';quality=$Quality;output_format='png'}).GetEnumerator()){$form.Add([Net.Http.StringContent]::new([string]$entry.Value),$entry.Key)}
    $imageContent=[Net.Http.ByteArrayContent]::new([IO.File]::ReadAllBytes([string]$request.reference_image_path));$imageContent.Headers.ContentType=[Net.Http.Headers.MediaTypeHeaderValue]::new('image/png')
    $form.Add($imageContent,'image[]',[IO.Path]::GetFileName([string]$request.reference_image_path))
    $httpResponse=$client.PostAsync('https://api.openai.com/v1/images/edits',$form).GetAwaiter().GetResult();$responseText=$httpResponse.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    if($httpResponse.Headers.Contains('x-request-id')){$requestId=($httpResponse.Headers.GetValues('x-request-id')|Select-Object -First 1)}
    if(-not $httpResponse.IsSuccessStatusCode){Fail 14 (New-ProviderError -Status ([int]$httpResponse.StatusCode) -ResponseBody $responseText -RequestId $requestId -TransportMessage $null)}
    try{$parsed=$responseText|ConvertFrom-Json}catch{Fail 15 (New-ProviderError -Status ([int]$httpResponse.StatusCode) -ResponseBody $null -RequestId $requestId -TransportMessage 'Successful provider response_parse_error: invalid JSON.')}
    $encoded=[string]$parsed.data[0].b64_json
    if([string]::IsNullOrWhiteSpace($encoded)){Fail 15 (New-ProviderError -Status ([int]$httpResponse.StatusCode) -ResponseBody $null -RequestId $requestId -TransportMessage 'Successful provider response_parse_error: missing data[0].b64_json.')}
    try{$bytes=[Convert]::FromBase64String($encoded)}catch{Fail 15 (New-ProviderError -Status ([int]$httpResponse.StatusCode) -ResponseBody $null -RequestId $requestId -TransportMessage 'Successful provider response_parse_error: invalid base64 image data.')}
  }catch [System.Threading.Tasks.TaskCanceledException]{Fail 14 (New-ProviderError -Status 408 -ResponseBody $null -RequestId $requestId -TransportMessage 'OpenAI image edit request timed out.')}
  catch{Fail 14 (New-ProviderError -Status $null -ResponseBody $null -RequestId $requestId -TransportMessage $_.Exception.Message)}
  finally{$form.Dispose();if($httpResponse){$httpResponse.Dispose()}}
  [IO.Directory]::CreateDirectory((Split-Path -Parent ([string]$request.output_path)))|Out-Null
  try{$stream=[IO.File]::Open([string]$request.output_path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}}
  catch{Fail 13 (New-ProviderError -Status 409 -ResponseBody $null -RequestId $requestId -TransportMessage 'Could not create provider output without overwriting an existing file.')}
  [ordered]@{category='success';http_status=200;request_id=Protect-ProviderText $requestId}|ConvertTo-Json -Compress
  exit 0
}finally{$client.Dispose()}
