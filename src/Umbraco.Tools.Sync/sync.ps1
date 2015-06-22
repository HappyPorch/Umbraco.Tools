param(
    [Parameter(Mandatory=$True)]
    [string]$siteName,

    [Parameter(Mandatory=$True)]
    [string]$destinationSiteName,
     
    [Parameter(Mandatory=$True)]
    [string]$destinationRootPath,
     
    [Parameter(Mandatory=$True)]
    [string]$destinationServer, 

    [switch]$syncDb,

    [string]$databaseServer,

    [Parameter(Mandatory=$True)]
    [string]$remoteUserName, 

    [Parameter(Mandatory=$True)]
    [string]$remotePassword
)


if ($syncDb -eq $True -and -not $databaseServer) {
    throw "Db sync was requested but database server instance was not specified. Please provide a value for `databaseServer` paramter."
}


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
        $physicalPath = "$destinationRootPath\$destinationSiteName"

		Write-Host " - Syncing site '$siteName' to $hostname..." -NoNewline

        $CMD =  "`"C:\Program Files\IIS\Microsoft Web Deploy V3\msdeploy.exe`""

        $AllArgs =  @(
            "-verb:sync", 
            "-verbose", 
            "-source:appHostConfig=`'$siteName`'",
            "-dest:appHostConfig=`'$destinationSiteName`',computername=$destinationServer,username=$remoteUserName,password=$remotePassword",
            "-skip:objectName=environmentVariables",
            "-skip:objectName=binding",
            "-enableLink:AppPoolExtension",
            "-replace:objectName=virtualDirectory,scopeAttributeName=physicalPath,match=`'^.*:\\.*$`',replace=`'$physicalPath`'",
            "-postSync:runCommand=`"%windir%\system32\inetsrv\appcmd.exe set site /site.name:$destinationSiteName /+bindings.[protocol='http',bindingInformation='*:80:$hostname']`""
        )        
        
        $command = "$CMD $AllArgs"     
			
        cmd.exe /c "`"$command`"" | Write-Host

	} catch {
		$exception = $_.Exception
		Write-Host "ERROR" -ForegroundColor:Red
		throw " - Sync-WDSite failed: $exception"
	}
	
	Write-Host "OK" -ForegroundColor Green
    return $physicalPath
}

function Sync-Dbs ($localSite) {

	try {
        $destinationConnectionString = "Data Source=$databaseServer;Initial Catalog=$destinationSiteName;Integrated Security=True"

		Write-Host " - Syncing db to '$destinationServer' as ($destinationConnectionString)..." -NoNewline

        $sitePhysicalPath = $localSite.physicalPath;
        $xml = [xml](Get-Content "$sitePhysicalPath\Web.config")
        $connectionStringNode = $xml.configuration.connectionStrings.add | ? { $_.name -eq "umbracoDbDSN" }
        if ($connectionStringNode -eq $null) {
            $connectionStringNode = $xml.configuration.appSettings.add | ? { $_.key -eq "umbracoDbDSN" }
            $sourceConnectionString = $connectionStringNode.value
        } else {
            $sourceConnectionString = $connectionStringNode.connectionString
        }

        $Result = Sync-WDSQLDatabase -ErrorAction:Stop `
            -SourceDatabase $sourceConnectionString `
            -SourceSettings @{ 
               CopyAllUsers = $False;
               ScriptDropsFirst = $True;
            } `
            -DestinationDatabase "$destinationConnectionString" `
            -DestinationPublishSettings destination.publishsettings
		
	} catch {
		Write-Host "ERROR" -ForegroundColor:Red
		throw $_.Exception
	}
	
	Write-Host "OK" -ForegroundColor Green
    return $destinationConnectionString
}

function Replace-ConnectionString($siteFolder, $connectionString) {
    try {

		Write-Host " - Replacing the db conection string on the far side..." -NoNewline

        $webConfigFilename = "$siteFolder\Web.config"
        
        $script = "& {
            [xml]`$xml = Get-Content `"$webConfigFilename`"
            `$connectionStringNode = `$xml.configuration.connectionStrings.add | ? { `$_.name -eq `"umbracoDbDSN`" }
            if (`$connectionStringNode -eq `$null) {
                `$connectionStringNode = `$xml.configuration.appSettings.add | ? { `$_.key -eq `"umbracoDbDSN`" }
                `$connectionStringNode.value = `"$connectionString`"
            } else {
                `$connectionStringNode.connectionString = `"$connectionString`"
            }
            `$xml.Save(`"$webConfigFilename`") 
        }"

        $bytes = [System.Text.Encoding]::Unicode.GetBytes($script)
        $encodedCommand = [Convert]::ToBase64String($bytes)

        $command = "powershell.exe -encodedCommand $encodedCommand"

        $Result = Invoke-WDCommand $command `
            -ErrorAction:Stop `
            -DestinationPublishSettings destination.publishsettings `
            -DestinationSettings @{ dontUseCommandExe = $True }
		
	} catch {
		$exception = $_.Exception
		Write-Host "ERROR" -ForegroundColor:Red
		throw " - Sync-Dbs failed: $exception"
	}
	
	Write-Host "OK" -ForegroundColor Green
}

function Set-Permissions($localSite) {
	try {
		Write-Host " - Setting folder permissions for '$destinationSiteName' on '$destinationServer'..." -NoNewline

        $appPoolName = $localSite.applicationPool
        $rights = [System.Security.AccessControl.FileSystemRights]"ListDirectory,ReadData,Traverse,ExecuteFile,ReadAttributes,ReadPermissions,Read,ReadAndExecute,Modify,Write"

        Set-WDAcl -ErrorAction:Stop `
            -DestinationPublishSettings destination.publishsettings `
            -Destination $destinationSiteName `
            -SetAclUser "IIS AppPool\$appPoolName" `
            -SetAclAccess $rights | Out-Null

	} catch {
		Write-Host "ERROR" -ForegroundColor:Red
		throw $_.Exception
	}
	
	Write-Host "OK" -ForegroundColor Green
}

try {

	Write-Host "deployment started"
	
	Ensure-WDPowerShellMode
    Ensure-WebAdministrationModule
    Build-PublishProfiles
    $site = Get-Site
    try {
        Stop-SiteAndPool $site
        $remotePhysicalPath = Sync-Sites
        if ($syncDb) {
            $remoteConnectionString = Sync-Dbs $site -ErrorAction:Stop
            Replace-ConnectionString $remotePhysicalPath $remoteConnectionString 
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