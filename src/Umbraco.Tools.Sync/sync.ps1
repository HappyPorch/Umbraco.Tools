param($siteName, $destinationServer, $remoteUserName, $remotePassword)

function Ensure-WDPowerShellMode {
	$WDPowerShellSnapin = Get-PSSnapin -Name WDeploySnapin3.0 -ErrorAction:SilentlyContinue
	
	if( $WDPowerShellSnapin -eq $null) {
		
		Write-Host " - Adding 'Web Deploy 3.0' to console..." -NoNewline
		Add-PsSnapin -Name WDeploySnapin3.0 -ErrorAction:SilentlyContinue -ErrorVariable e | Out-Null
		
		if($? -eq $false) {
			throw " - failed to load the Web Deploy 3.0 PowerShell snap-in: $e"
		} else {
			Write-Host "OK" -ForegroundColor Green
		}
	} else {
		Write-Host " - 'Web Deploy 3.0' already added to console"
	}
}

function Sync-Sites {
	try {
		Write-Host " - Syncing site '$siteName' to server '$destinationServer'..." -NoNewline

        
        New-WDPublishSettings -AgentType MSDepSvc -FileName source.publishsettings | Out-Null

        if($remoteUserName -eq $null) {
            $cred = Get-Credential -Message "Please provide credentials for the remote server"
            New-WDPublishSettings -AgentType MSDepSvc -ComputerName $destinationServer -Credentials $cred -FileName destination.publishsettings | Out-Null
        } else {
            New-WDPublishSettings -AgentType MSDepSvc -ComputerName $destinationServer -UserID $remoteUserName -Password $remotePassword -FileName destination.publishsettings | Out-Null
        }
        
        $Result = Sync-WDSite -ErrorAction:Stop -Verbose -Debug `
            -IncludeAppPool `
            -SourceSite $siteName `
            -DestinationSite $siteName `
            -SourcePublishSettings source.publishsettings `
            -DestinationPublishSettings destination.publishsettings

			
	} catch {
		$exception = $_.Exception
		Write-Host "ERROR" -ForegroundColor:Red
		throw " - Sync-WDSite failed: $exception"
	}
	
	Write-Host "OK" -ForegroundColor Green
	Write-Host "Summary:"
	$Result | Out-String
}

try {
	
	Write-Host "deployment started"
	
	Ensure-WDPowerShellMode
	Sync-Sites
	
	Write-Host "deployment finished successfully"
	
} catch {
	Write-Error $_.Exception
	exit 1
}