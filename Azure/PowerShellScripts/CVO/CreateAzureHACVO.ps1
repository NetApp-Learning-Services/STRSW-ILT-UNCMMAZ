param
(
  [parameter(Mandatory=$false, HelpMessage="Azure Subscription ID")]
  #[string]$SubscriptionId="xxxxxxx-xxxxxxx-xxxx-xxxxxxxxxxxx",
  [string]$SubscriptionId="<Your Subscription Id>",
  
  [parameter(Mandatory=$false, HelpMessage="Resource Group to deploy CVO HA")]
  #[string]$resourceGroupName="xxxxxxx",
  [string]$resourceGroupName="RT#######_CVOHA",

  [parameter(Mandatory=$false, HelpMessage="CVO Name")]
  #[string]$cvoName="CvoTest",
  [string]$cvoName="CVOHA1",

  [parameter(Mandatory=$false, HelpMessage="Refresh token of Cloud Manager")]
  #[string]$refToken="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  [string]$refToken="<YourRefresh Token>",

  [parameter(Mandatory=$false, HelpMessage="OCCM IP")]
  #[string]$occmIP="1.1.1.1"
  [string]$occmIP="<Private IP of your Connector>"

)

Import-module .\func.ps1 -Force

waitForOCCM $occmIP

$token = getToken $refToken

Write-Host ("Token = $token")

Write-Host ("Getting Workspace ID")

$initHeader = @{
 "Accept"="application/json"
 "Content-Type"="application/json"
 "Authorization"="$token"
 "Referer"="pwsh"
}

$tenantId = (Invoke-RestMethod -Uri "http://$occmIP/occm/api/tenants" -Method 'GET' -Headers $initHeader).publicId

Write-Host ("tenantId = " + $tenantId)

# Reading request file

$ha_request = (Get-Content -Raw -Path ./templates/AzureHA.json | ConvertFrom-Json)

# UPDATE REQUEST PARAMS
$ha_request.tenantId = $tenantId
$ha_request.name = $cvoName
#$ha_request.resourceGroup = $cvoName + "-rg"
$ha_request.resourceGroup = $resourceGroupName
$ha_request.subscriptionId = $SubscriptionId


$createBody = ($ha_request | ConvertTo-Json)

Write-Host ("Creating CVO " + $cvoName)
$request = (Invoke-WebRequest -Uri "http://$occmIP/occm/api/azure/ha/working-environments" -Method 'POST' -Body $createBody -Headers $initHeader)
#$request

$oncloud_request_id = $request.Headers."OnCloud-Request-Id"
$content = ConvertFrom-Json $([String]::new($request.Content))
#$content
Write-Host ("publicId = " + $content.publicId)
Write-Host ("request_id = " + $oncloud_request_id)

# WAIT FOR CVO TO BE UP
waitForAction $oncloud_request_id "Create CVO" 60 35

