param(
	[string]$ServerName,
	[string]$CSVPath,
	[string]$SourcePath,
	[string]$InstanceName,
	[string]$DatabaseName,
	[string]$DatabaseServer,
	[string]$DatasourceName,
	[string]$User,
	[securestring]$Pass,
	[switch]$DeployFolders,
	[switch]$CreateDatasource
)

Write-Host "Populating a list of the reports to upload..."
$ReportArray = @()
foreach($Report in Get-ChildItem -af -Path $SourcePath -Recurse) {
	$Item = $Report
	$Name = [io.path]::GetFileNameWithoutExtension($Item)          #Strip the extension off of the filename - name of the item.
	$Path = Split-Path $Report.FullName
	if($Path -like "*:*") {
		$Path = $Path.Split("\")
		$Parent = ""
		for ($i = 1; $i -lt $Path.Count; $i++) {
			if($i -eq $Path.Count -1) {
				$Parent += $Path[$i]
			} else {
				$Parent += $Path[$i] + "/"
			}	
		}
	} elseif($Path -like "\\*") {
		$Path = $Path.Replace("\\", "")
		$Path = $Path.Split("\")
		$Parent = ""
		for ($i = 1; $i -lt $Path.Count; $i++) {
			if($i -eq $Path.Count) {
				$Parent += $Path[$i]
			} else {
				$Parent += $Path[$i] + "/"
			}			
		}
	} elseif($Path -match "^$") {
		$Parent = "/"
	} else {
		Write-Host "Please enter the root path to the reports using either UNC path or drive letter path"
		return
	}
	$Row = "" | Select-Object RDLFileName, ReportServerName, ReportBaseFolder, ReportName, ParentFolder
	$Row.RDLFileName = $Item
	$Row.ReportServerName = $InstanceName
	$Row.ReportBaseFolder = "/"
	$Row.ReportName = $Name
	$Row.ParentFolder = $Parent
	$ReportArray += $Row
}
	    
function New-SSRSFolder
(
		[string]$FolderName,		
		[string]$Parent	
)
{
	Write-Host "Creating $FolderName folder..."
	
	$ReportServerUri = "http://$ServerName/ReportServer_$InstanceName/ReportService2010.asmx"
	$Proxy = New-WebServiceProxy -Uri $ReportServerUri -UseDefaultCredential
	
	$Type = $Proxy.GetType().Namespace #Giving the variable a specific type, this is necessary due to the implied namespace and datatype confusion of 
										#Microsoft.ReportingServices.WebServer.ReportingService2010
	$Datatype = ($Type + '.Property')  #Cast that variable in to what we need
			
	$Property =New-Object ($Datatype); #Create the property variable with the datatype we need and set a couple properties for later
	$Property.Name = $FolderName
	$Property.Value = $FolderName
			
	$NumProperties = 1
	$Properties = New-Object ($Datatype + '[]')$NumProperties 
	$Properties[0] = $Property;
		
	$Proxy.CreateFolder($FolderName, $Parent, $Properties);  #Call the CreateFolder method from the ReportService2010 namespace	    
}
	
function Publish-SSRS
(	    
	[string[]]$ReportArray
)
{
	foreach($Report in $ReportArray) {
		$ReportServiceURI = "http://$ServerName/ReportServer_$InstanceName/ReportService2010.asmx"   
		$RDLFileName = $SourcePath + $Report.ParentFolder + "\" + $Report.RDLFileName
		$FinalPath = $Report.ReportBaseFolder + $Report.ParentFolder
	    #Write some updates to the user
	    Write-Host "----------------------------------------------------------------------------------------------------------------------------------------"
	    Write-Host "Deploying" $RDLFileName 
	    Write-Host " to" $FinalPath "as" $_.ReportName		
		
	    $SSRSproxy = New-WebServiceProxy -uri $ReportServiceURI -UseDefaultCredential 
	    $RDLStream = Get-Content $RDLFileName -Encoding byte
	    $Warnings =@();
	    $SSRSproxy.CreateCatalogItem("Report", $Report.Name, $Path, $true, $RDLStream, $null, [ref]$Warnings)
	
	    #Send any warnings to the user
	    if ($Warnings) {
	       foreach ($Warning in $Warnings) {
	            Write-Warning $Warning.Message
	        }
	    }
	}
}

function Set-DataSource
(
	[string]$ReportFolderPath
)
{
	$TargetDataSourcePath = "/DataSources/$DatasourceName"
	$TargetDataSourceName = "$DatasourceName"
	
	$Url = "http://$($ServerName)/ReportServer_$($InstanceName)/ReportService2010.asmx"	
	$SSRS = New-WebServiceProxy -Uri $Url -UseDefaultCredential	
	$CatalogItems = $SSRS.ListChildren("/", $true)

	foreach($CatalogItem in $CatalogItems) {
		if($CatalogItem.TypeName -eq "Report") {
			$ReportPath = $CatalogItem.Path
			$Datasources = $SSRS.GetItemDataSources($ReportPath)
			foreach($Datasource in $Datasources) {
				$ProxyNamespace = $Datasource.GetType().Namespace
				$TargetDataSource = New-Object ("$ProxyNamespace.DataSource")
				$TargetDataSource.Name = $TargetDataSourceName
				$TargetDataSource.Item = New-Object ("$ProxyNamespace.DataSourceReference")
				$TargetDataSource.Item.Reference = $TargetDataSourcePath
				$Datasource.item = $TargetDataSource.Item					
				$SSRS.SetItemDataSources($ReportPath, $Datasource) #Set the object to the new data source using the SetItemDataSources method of the ReportingServices2010 namespace
			}
		}
	}
}
function New-DataSource
(
	[string]$DatasourceName
)
{
	Write-Host "Creating Datasource..."
	$ReportServerUri  = "http://$($ServerName)/ReportServer_$($InstanceName)/ReportService2010.asmx"
	$Proxy = New-WebServiceProxy -Uri $ReportServerUri -UseDefaultCredential
	$Type = $Proxy.GetType().Namespace #Explicit cast to the namespace type of the $proxy object(compatability reasons)

	#create a DatasourceDefinition and set some properties of the new object
	$DatasourceDefinitionType = ($type + '.DatasourceDefinition')
	$DatasourceDefinition = New-Object($DatasourceDefinitionType)
	$DatasourceDefinition.CredentialRetrieval = "Store"
	$DatasourceDefinition.UserName = $User
	$DatasourceDefinition.Password = $Pass
	$DatasourceDefinition.ConnectString = "Data Source=$($DatabaseServer);Initial Catalog=$($DatabaseName)"
	$DatasourceDefinition.extension = "SQL"
	$DatasourceDefinition.enabled = $true
	$DatasourceDefinition.Prompt = $null
	$DatasourceDefinition.WindowsCredentials = $false

	$ParentFolder = "/DataSources"        #Parent folder
	$Overwrite = $true #Overwrite the datasource if it exists?             

	#Create the datasource from the parameters set above
	$Proxy.CreateDataSource($DatasourceName, $ParentFolder, $Overwrite, $DatasourceDefinition, $null)
}

if($DeployFolders)
{	
	foreach($Item in Get-ChildItem -Path $SourcePath -Recurse) {
		if($Item.Attributes -like "*Directory*") {
			$RelativePath = $Item.FullName.Replace($SourcePath, '')
			$RelativePath = $RelativePath.Replace('\', "/")
			$TargetPath = "/" + $RelativePath
			$TargetPath = $TargetPath.Split('/')
			$FolderName = $TargetPath[$TargetPath.Count -1]
			if($TargetPath[$TargetPath.Count -2] -match "^$") {
				$ParentFolder = "/"
			} else {
				$ParentFolder = $TargetPath[$TargetPath.Count -2]
			}
			New-SSRSFolder -FolderName $FolderName -Parent $ParentFolder
		}
	}
}

if($CreateDatasource)
{
	New-Datasource -DatasourceName "Datasource"
}

Publish-SSRS -InstanceName $InstanceName -ReportServer $ServerName 
Set-DataSource -InstanceName $InstanceName -ReportServer $ServerName -ReportFolderPath "/FHNetReports/System Reports"
Set-DataSource -InstanceName $InstanceName -ReportServer $ServerName -ReportFolderPath "/FHNetReports/System Reports/EMS"
Set-DataSource -InstanceName $InstanceName -ReportServer $ServerName -ReportFolderPath "/FHNetReports/System Reports/Incident"




#Use this to install a new RS instance - modify the instance name.
#Y:\InstallMedia\Microsoft\SQL\SQL2012EE\SQLServer2012EE\Setup.exe /qs /Action=Install UpdateEnabled=0 /InstanceName="SSRSMDFREDERICK" /IACCEPTSQLSERVERLICENSETERMS  /Action=Install /FEATURES=RS /RSINSTALLMODE=DEFAULTNATIVEMODE /RSSVCSTARTUPTYPE="Automatic"
Write-Host -ForegroundColor Yellow "Press any key to exit ..."
$host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
