﻿param(
    [Parameter(Mandatory=$True)]
    [string]$siteName,

    [Parameter(Mandatory=$True)]
    [string]$destinationSiteName,
     
    [Parameter(Mandatory=$True)]
    [string]$destinationRootPath,
     
    [Parameter(Mandatory=$True)]
    [string]$destinationServer, 

    [switch]$changeDbFromServerToFile,

    [string]$remoteUserName, 

    [string]$remotePassword
)

function Ensure-WDPowerShellMode {
	$WDPowerShellSnapin = Get-PSSnapin -Name WDeploySnapin3.0 -ErrorAction:SilentlyContinue
	
	if( $WDPowerShellSnapin -eq $null) {
		
		Write-Host " - Adding 'Web Deploy 3.0' to console..." -NoNewline
		Add-PsSnapin -Name WDeploySnapin3.0 -ErrorAction:SilentlyContinue -ErrorVariable e | Out-Null
		
		if($? -eq $false) {
            Write-Host "ERROR" -ForegroundColor:Red
			throw $e
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
            Write-Host "ERROR" -ForegroundColor:Red
			throw $e
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

function Get-Site {
	try {
		Write-Host " - Obtaining local site information for '$siteName'..." -NoNewline

        $site = Get-Website -Name "*$siteName"       
	} catch {
		$exception = $_.Exception
		Write-Host "ERROR" -ForegroundColor:Red
		throw " - Get-Website failed: $exception"
	}
	
	Write-Host "OK" -ForegroundColor Green
    return $site
}

function Stop-SiteAndPool($localSite) {
	try {
		Write-Host " - Stopping local site '$siteName'..." -NoNewline

        Stop-WebSite $siteName
	} catch {
		$exception = $_.Exception
		Write-Host "ERROR" -ForegroundColor:Red
		throw " - Stop-WebSite: $exception"
	}
	
	Write-Host "OK" -ForegroundColor Green

	try {
        $appPool = $localSite.applicationPool
        Write-Host " - Stopping local app pool '$appPool'..." -NoNewline

        Stop-WebAppPool $appPool
	} catch {
		$exception = $_.Exception
		Write-Host "ERROR" -ForegroundColor:Red
		throw " - Stop-WebAppPool: $exception"
	}
	
	Write-Host "OK" -ForegroundColor Green
}

function Start-SiteAndPool($localSite) {
	try {
        $appPool = $localSite.applicationPool
        Write-Host " - Starting local app pool '$appPool'..." -NoNewline

        Start-WebAppPool $appPool
	} catch {
		$exception = $_.Exception
		Write-Host "ERROR" -ForegroundColor:Red
		throw " - Start-WebAppPool: $exception"
	}
	
	Write-Host "OK" -ForegroundColor Green

	try {
		Write-Host " - Starting local site '$siteName'..." -NoNewline

        Start-WebSite $siteName
	} catch {
		$exception = $_.Exception
		Write-Host "ERROR" -ForegroundColor:Red
		throw " - Start-WebSite: $exception"
	}
	
	Write-Host "OK" -ForegroundColor Green
}

function Sync-Sites {
	try {
        $hostname = "$destinationSiteName.$destinationServer" 

		Write-Host " - Syncing site '$siteName' to $hostname..." -NoNewline

        $Result = Sync-WDSite -ErrorAction:Stop `
            -SourceSite $siteName `
            -DestinationSite $destinationSiteName `
            -SitePhysicalPath "$destinationRootPath\$destinationSiteName" `
            -SourcePublishSettings source.publishsettings `
            -DestinationPublishSettings destination.publishsettings `
            -SiteBinding "*:80:$hostname" `
            -IncludeAppPool
			
	} catch {
		$exception = $_.Exception
		Write-Host "ERROR" -ForegroundColor:Red
		throw " - Sync-WDSite failed: $exception"
	}
	
	Write-Host "OK" -ForegroundColor Green
	Write-Host "Summary:" -NoNewline
	$Result | Out-String
}

function Sync-Dbs ($localSite) {

	try {
        $destinationConnectionString = "Data Source=.\SQLEXPRESS;Initial Catalog=$destinationSiteName;Integrated Security=True"

		Write-Host " - Syncing db to '$destinationServer' as ($destinationConnectionString)..." -NoNewline

        $sitePhysicalPath = $localSite.physicalPath;
        $xml = [xml](Get-Content "$sitePhysicalPath\Web.config")
        $connectionStringNode = $xml.configuration.connectionStrings.add | ? { $_.name -eq "umbracoDbDSN" }

        $sourceConnectionString = $connectionStringNode.connectionString

        $Result = Sync-WDSQLDatabase -ErrorAction:Stop `
            -SourceDatabase $sourceConnectionString `
            -DestinationDatabase "$destinationConnectionString" `
            -DestinationSettings @{ dropDestinationDatabase = $True } `
            -SourcePublishSettings source.publishsettings `
            -DestinationPublishSettings destination.publishsettings
		
	} catch {
		$exception = $_.Exception
		Write-Host "ERROR" -ForegroundColor:Red
		throw " - Sync-Dbs failed: $exception"
	}
	
	Write-Host "OK" -ForegroundColor Green
	Write-Host "Summary:" -NoNewline
	$Result | Out-String
}

function Set-Permissions($localSite) {
	try {
		Write-Host " - Setting folder permissions for '$siteName' on '$destinationServer'..." -NoNewline

        $appPoolName = $localSite.applicationPool
        $rights = [System.Security.AccessControl.FileSystemRights]"ListDirectory,ReadData,Traverse,ExecuteFile,ReadAttributes,ReadPermissions,Read,ReadAndExecute,Modify,Write"

        $Result = Set-WDAcl -ErrorAction:Stop `
            -DestinationPublishSettings destination.publishsettings `
            -Destination $destinationSiteName `
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
    $site = Get-Site
    try {
        Stop-SiteAndPool $site
        Sync-Sites
        if ($changeDbFromServerToFile) {
            Sync-Dbs $site -ErrorAction:Stop
        }
    } finally {
        Start-SiteAndPool $site
    }
    Set-Permissions $site

	Write-Host "deployment finished successfully"
	
} catch {
	Write-Error $_.Exception
	exit 1
}