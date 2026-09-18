$ErrorActionPreference='Stop'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'tool/openai_anatomy_provider_contract.ps1')
function Assert-Equal($Expected,$Actual,[string]$Name){if($Expected -ne $Actual){throw "$Name expected=$Expected actual=$Actual"}}
function Fixture([int]$Status,[string]$Type,[string]$Code,[AllowNull()][string]$Param,[string]$Message){$body=@{error=@{type=$Type;code=$Code;param=$Param;message=$Message}}|ConvertTo-Json -Compress;New-ProviderError -Status $Status -ResponseBody $body -RequestId 'req_fixture' -TransportMessage $null}
$cases=@(
  @{name='authentication_error';record=(Fixture 401 'invalid_api_key' 'invalid_api_key' $null 'Incorrect API key')},
  @{name='billing_error';record=(Fixture 400 'invalid_request_error' 'insufficient_quota' $null 'Billing quota exceeded')},
  @{name='rate_limit_error';record=(Fixture 429 'rate_limit_error' 'rate_limit_exceeded' $null 'Too many requests')},
  @{name='safety_rejection';record=(Fixture 400 'image_generation_user_error' 'content_policy_violation' 'prompt' 'Safety system rejected request')},
  @{name='invalid_request';record=(Fixture 400 'invalid_request_error' 'invalid_value' 'image' 'Invalid image field')},
  @{name='network_error';record=(New-ProviderError -Status $null -ResponseBody $null -RequestId $null -TransportMessage 'Connection refused')},
  @{name='timeout';record=(New-ProviderError -Status 408 -ResponseBody $null -RequestId $null -TransportMessage 'Request timed out')},
  @{name='response_parse_error';record=(New-ProviderError -Status 200 -ResponseBody $null -RequestId 'req_parse' -TransportMessage 'Successful response_parse_error: invalid JSON')}
)
foreach($case in $cases){Assert-Equal $case.name $case.record.category $case.name}
$redacted=Fixture 401 'invalid_api_key' 'invalid_api_key' 'Authorization: Bearer sk-secret' 'Key sk-secret is invalid'
if((ConvertTo-ProviderErrorJson $redacted) -match 'sk-secret'){throw 'Secret redaction failed'}
Assert-Equal 401 $redacted.http_status 'http_status';Assert-Equal 'req_fixture' $redacted.request_id 'request_id'
$providerSource=Get-Content -Raw (Join-Path (Split-Path -Parent $PSScriptRoot) 'tool/openai_anatomy_image_provider.ps1')
foreach($contract in @("PostAsync('https://api.openai.com/v1/images/edits'","'image[]'","'image/png'","size='1024x1024'","quality=`$Quality","output_format='png'")){if(-not $providerSource.Contains($contract)){throw "Missing provider contract: $contract"}}
"Provider tests passed: $($cases.Count) categories plus redaction and request contract assertions"
