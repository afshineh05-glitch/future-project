$ErrorActionPreference = 'Stop'

function Protect-ProviderText([AllowNull()][string]$Value) {
  if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
  $clean = $Value -replace 'sk-[A-Za-z0-9_-]+', '[REDACTED]'
  $clean = $clean -replace '(?i)(Authorization\s*[:=]\s*Bearer\s+)[^\s,;"}]+', '$1[REDACTED]'
  $clean = $clean -replace '(?i)(Bearer\s+)[A-Za-z0-9._-]+', '$1[REDACTED]'
  if ($clean.Length -gt 2000) { $clean = $clean.Substring(0, 2000) + '[TRUNCATED]' }
  return $clean
}

function Get-ProviderCategory([Nullable[int]]$Status, [AllowNull()][string]$Type, [AllowNull()][string]$Code, [AllowNull()][string]$Message) {
  $haystack = "$Type $Code $Message".ToLowerInvariant()
  if ($Status -in @(401, 403) -or $haystack -match 'auth|api[_ -]?key|permission') { return 'authentication_error' }
  if ($Status -eq 429 -or $haystack -match 'rate[_ -]?limit|too many requests') { return 'rate_limit_error' }
  if ($haystack -match 'billing|quota|credit|payment|insufficient_quota') { return 'billing_error' }
  if ($haystack -match 'safety|content_policy|moderation|rejected') { return 'safety_rejection' }
  if ($Status -eq 408 -or $haystack -match 'timed?\s*out|timeout|taskcanceled') { return 'timeout' }
  if ($Status -ge 400 -and $Status -lt 500) { return 'invalid_request' }
  if ($haystack -match 'json|parse|base64|response.*data|response body') { return 'response_parse_error' }
  return 'network_error'
}

function New-ProviderError {
  param([Nullable[int]]$Status,[AllowNull()][string]$ResponseBody,[AllowNull()][string]$RequestId,[AllowNull()][string]$TransportMessage)
  $type=$null;$code=$null;$param=$null;$message=$null
  if (-not [string]::IsNullOrWhiteSpace($ResponseBody)) {
    try {$parsed=$ResponseBody|ConvertFrom-Json;$type=[string]$parsed.error.type;$code=[string]$parsed.error.code;$param=[string]$parsed.error.param;$message=[string]$parsed.error.message}
    catch {$message='Provider returned an unparseable error response.'}
  }
  if ([string]::IsNullOrWhiteSpace($message)) { $message=$TransportMessage }
  if ([string]::IsNullOrWhiteSpace($message)) { $message='Provider request failed without an error message.' }
  [ordered]@{category=(Get-ProviderCategory -Status $Status -Type $type -Code $code -Message $message);http_status=if($null -eq $Status){$null}else{[int]$Status};error_type=Protect-ProviderText $type;error_code=Protect-ProviderText $code;error_param=Protect-ProviderText $param;message=Protect-ProviderText $message;request_id=Protect-ProviderText $RequestId}
}

function ConvertTo-ProviderErrorJson($ErrorRecord) {return ($ErrorRecord|ConvertTo-Json -Depth 5 -Compress)}
