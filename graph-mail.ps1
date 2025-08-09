#!/usr/sbin/pwsh
# /etc/local/bin/graph-mail.ps1

param(
  [Parameter(Mandatory=$true)][string[]]$To,
  [string]$Subject = "",
  [ValidateSet("Text","HTML")][string]$ContentType = "Text"
)

# Gather environment variables
$envs = Get-Content /etc/graph-mail.env | Where-Object {$_ -match "="} |
  ForEach-Object {
    $k,$v = $_ -split "=",2; @{ Key=$k; Value=$v }
  }
$TENANT_ID = ($envs | ?{$_.Key -eq "TENANT_ID"}).Value
$APPLICATION_ID = ($envs | ?{$_.Key -eq "APPLICATION_ID"}).Value
$CLIENT_SECRET = ($envs | ?{$_.Key -eq "CLIENT_SECRET"}).Value
$SENDER = ($envs | ?{$_.Key -eq "SENDER"}).Value

# Read mail body from STDIN
$BodyText = [System.IO.StreamReader]::new([Console]::OpenStandardInput()).ReadToEnd()

# Get token (client credentials)
$TokenResp = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token" -Body @{
  client_id     = $APPLICATION_ID
  scope         = "https://graph.microsoft.com/.default"
  client_secret = $CLIENT_SECRET
  grant_type    = "client_credentials"
}
$Headers = @{ Authorization = "Bearer $($TokenResp.access_token)" }

# If Bash gave one string with commas/semicolons/spaces, split it:
if ($To.Count -eq 1 -and $To[0] -match '[,; ]') {
  $To = $To[0] -split '[,; ]+' | Where-Object { $_ }
}

# Build recipients array
$recips = @(
  foreach ($addr in $To) {
    @{ emailAddress = @{ address = $addr } }
  }
)

# Send
$payload = @{
  message = @{
    subject = $Subject
    body = @{ contentType = $ContentType; content = $BodyText }
    toRecipients = @($recips)
  }
  saveToSentItems = $false
} | ConvertTo-Json -Depth 6

#Write-Output $payload

Invoke-RestMethod -Method Post -Uri "https://graph.microsoft.com/v1.0/users/$SENDER/sendMail" -Headers $Headers -ContentType "application/json" -Body $payload
