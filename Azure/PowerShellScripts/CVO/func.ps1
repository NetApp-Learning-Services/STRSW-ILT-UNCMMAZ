# GET TOKEN FROM AUTH0 FOR GIVEN REFRESH TOKEN
function getToken {
 param( [String]$refToken )
 $body = @{
  "grant_type"="refresh_token"
  "refresh_token"="$refToken"
  "client_id"="Mu0V1ywgYteI6w1MbD15fKfVIUrNXGWC"
 } | ConvertTo-Json

 $header = @{
  "Accept"="application/json"
  "Content-Type"="application/json"
  "Referer"="pwsh"
 }

 Write-Host ("Getting token from auth0")

 $tokenResponse = Invoke-RestMethod -Uri "https://netapp-cloud-account.auth0.com/oauth/token" -Method 'Post' -Body $body -Headers $header

 $token=$tokenResponse.token_type + " " + $tokenResponse.access_token

return $token
}


# WAIT FOR OCCM TO BE UP AND RUNNING ACCORDING TO GIVEN IP ADDRESS
function waitForOCCM {
  param ( [String]$occmIP)

  Write-Host ("######  The Cloud Manager IP is: $occmIP ######")

  Write-Host ("Waiting for OCCM: $occmIP to be up...")
  		$timeoutSeconds = 6*60 #6 minutes
  		$wait = $true

  		while($wait -and $timeoutSeconds -gt 0)
  		{
  			$wait = $false
  			$httpAddress = "http://" + $occmIP + "/occm/api/occm/system/about"
  			try{
  				$request = Invoke-WebRequest -method GET -Uri $httpAddress
  				if(!$request){
  					if($request.StatusCode -ne 200) {
  						Write-Host "OCCM IP address $occmIP is not up yet"
  						$wait = $true
  						$timeoutSeconds -= 40
  						start-sleep -s 40
  					}
  				} else {
  				Write-Host "OCCM in IP address $occmIP is up" -ForegroundColor Green
          Write-Host "$request"
  				}
  			}
  			catch {
  					Write-Host "OCCM in IP address $occmIP is not up yet"
  					$wait = $true
  					$timeoutSeconds -= 40
  					start-sleep -s 40
  			}

  		}
  		if ($timeoutSeconds -le 0){
  			Write-Host ("OCCM in IP address $occmIP is down") -ForegroundColor Red
        throw ("OCCM in IP address " + $occmIP + " failed to start.")
  		}

  Write-Host ("OCCM is UP and Ready") -ForegroundColor Green
}

#WAIT FOR ACTION TO COMPLETE ACCORDING TO GIVEN REQUEST ID
#ACTION IS USED TO DESCRIBE THE ACTION IN THE OnPremWorkingEnvironments
#TIMEOUT IS USED FOR HOW MUCH TIME TO WAIT BETWEEN THE CHECKS
#INTERVAL IS USED FOR THE NUMBER OF THE CHECKS
function waitForAction {
  param ( [String]$oncloud_request_id, [String]$action,[int]$timeout, [int]$interval)

  Start-Sleep -s 30
  $timeoutSeconds = $interval*$timeout #6 minutes
  $wait = $true
  $counter = 1

  while($wait -and $timeoutSeconds -gt 0)
  {
    $wait = $false
    $httpAddress = "http://" + $occmIP + "/occm/api/audit/$oncloud_request_id"
    try{
      $status = (Invoke-RestMethod -method GET -Uri $httpAddress -Headers $initHeader).status
        if($status -eq "Received") {
          Write-Host "Status is: $status, Action $action is still in progress... - Counter: $counter"
          $wait = $true
          $timeoutSeconds -= $timeout
          $counter += 1
          start-sleep -s $timeout
        } else {
            if($status -eq "Success") {
              Write-Host "Action $action completed successfully, Status is: $status" -ForegroundColor Green
            } else{
              Write-Host "Action $action failed, Status is: $status" -ForegroundColor Red
            }
        }
    }
    catch {
        Write-Host "catch - Status is: $status, Action $action is still in progress... - Counter: $counter"
        $wait = $true
        $timeoutSeconds -= $timeout
        $counter += 1
        start-sleep -s $timeout
    }

  }

}