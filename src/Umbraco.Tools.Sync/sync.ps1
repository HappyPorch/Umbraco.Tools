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

function Ensure-WebAdministrationModule {
	$WebAdministrationModule = Get-Module -Name WebAdministration -ErrorAction:SilentlyContinue
	
	if($WebAdministrationModule -eq $null) {
		
		Write-Host " - Importing 'Web Administration' module..." -NoNewline
		Import-Module WebAdministration -ErrorAction:SilentlyContinue -ErrorVariable e | Out-Null
		
		if($? -eq $false) {
			throw " - failed to import the Web Administration module: $e"
		} else {
			Write-Host "OK" -ForegroundColor Green
		}
	} else {
		Write-Host " - 'Web Administration' module already imported"
	}
}

function Build-PublishProfiles {
	try {
		Write-Host " - Creating publish profiles to source (localhost) and destination ('$destinationServer')..." -NoNewline

        New-WDPublishSettings -AgentType MSDepSvc -FileName source.publishsettings | Out-Null

        if($remoteUserName -eq $null) {
            $cred = Get-Credential -Message "Please provide credentials for the remote server"
            New-WDPublishSettings -AgentType MSDepSvc -ComputerName $destinationServer -Credentials $cred -FileName destination.publishsettings | Out-Null
        } else {
            New-WDPublishSettings -AgentType MSDepSvc -ComputerName $destinationServer -UserID $remoteUserName -Password $remotePassword -FileName destination.publishsettings | Out-Null
        }			
	} catch {
		$exception = $_.Exception
		Write-Host "ERROR" -ForegroundColor:Red
		throw " - Build-PublishProfiles failed: $exception"
	}
	
	Write-Host "OK" -ForegroundColor Green
}

function Sync-Sites {
	try {
		Write-Host " - Syncing site '$siteName' to server '$destinationServer'..." -NoNewline

        $Result = Sync-WDSite -ErrorAction:Stop `
            -SourceSite $siteName `
            -DestinationSite $siteName `
            -SourcePublishSettings source.publishsettings `
            -DestinationPublishSettings destination.publishsettings
            #            -IncludeAppPool `

			
	} catch {
		$exception = $_.Exception
		Write-Host "ERROR" -ForegroundColor:Red
		throw " - Sync-WDSite failed: $exception"
	}
	
	Write-Host "OK" -ForegroundColor Green
	Write-Host "Summary:" -NoNewline
	$Result | Out-String
}

function Set-Permissions {
	try {
		Write-Host " - Setting folder permissions for '$siteName' on '$destinationServer'..." -NoNewline

        $site = Get-Website -Name $siteName
        $appPoolName = $site.applicationPool
        $rights = [System.Security.AccessControl.FileSystemRights]"ListDirectory,ReadData,Traverse,ExecuteFile,ReadAttributes,ReadPermissions,Read,ReadAndExecute,Modify,Write"

        $Result = Set-WDAcl -ErrorAction:Stop `
            -DestinationPublishSettings destination.publishsettings `
            -Destination $siteName `
            -SetAclUser "IIS AppPool\$appPoolName" `
            -SetAclAccess $rights

	} catch {
		$exception = $_.Exception
		Write-Host "ERROR" -ForegroundColor:Red
		throw " - Set-WDAcl failed: $exception"
	}
	
	Write-Host "OK" -ForegroundColor Green
	Write-Host "Summary:" -NoNewline
	$Result | Out-String
}

try {
	
	Write-Host "deployment started"
	
	Ensure-WDPowerShellMode
    Ensure-WebAdministrationModule
    Build-PublishProfiles
	Sync-Sites
    Set-Permissions
	
	Write-Host "deployment finished successfully"
	
} catch {
	Write-Error $_.Exception
	exit 1
}