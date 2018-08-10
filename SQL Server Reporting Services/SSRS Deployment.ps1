param(
	[string]$ServerName,
	[string]$CSVPath,
	[string]$SourcePath,
	[string]$InstanceName,
	[string]$DatabaseName,
	[string]
)

$WorkingDirectory = (Get-Item $pwd).FullName
[xml]$settings = Get-Content "$WorkingDirectory\SSRSDeploymentSettings.xml"

$ServerName = $env:ComputerName
$CSVPath = $settings.Settings.Setting.CSVPath
$SourcePath = $settings.Settings.Setting.SourcePath
$InstanceName = $settings.Settings.Setting.InstanceName
$DatabaseName = $settings.Settings.Setting.DatabaseName
$DatabaseServer = $settings.Settings.Setting.DatabaseServer
$user = $settings.Settings.Setting.Username
$pass = $settings.Settings.Setting.Password
$DeployFolders = $settings.Settings.Setting.DeployFolders
$CreateDatasource = $settings.Settings.Setting.CreateDataSource


	
	function Get-Reports
	(#Define function parameters
	[Parameter(Position=0,Mandatory=$true)]
		[Alias("IName")]
		[string]$InstanceName
    )

{

        Write-Host "Populating a list of the reports to upload..."
	    gci -af -Path $SourcePath -Recurse  |`                          #load the directory in to memory and loop through its contents, adding
	    foreach{ 
                                                              #a row to the .csv file we are about to create with each iteration of the loop.
	    $Item = $_
	        $name = [io.path]::GetFileNameWithoutExtension($Item)          #Strip the extension off of the filename - name of the report.
	        $Path = $_.FullName
            $parent = Split-Path (Split-Path $Path -Parent) -Leaf 
	
	
	        $Path | Select-Object `
	            @{n="RDLFileName";e={$Item}},`                             #Define the contents of the .csv file
	            @{n="ReportServerName";e={$InstanceName}},`
	            @{n="ReportBaseFolder";e={"/FHNetReports/System Reports/"}},`
	            @{n="ReportName";e={$Name}},`
                @{n="ParentFolder";e={$parent}}`
                
         
	}| Export-Csv $CSVPath -NoTypeInformation   #Specify where we want the .csv file to go.
	    
	}
	<#
	    .Synopsis
	       Creates a .CSV file with the contents of the Y:\NetReports directory
	    .DESCRIPTION
	      The script creates a .csv file with 4 sections: RDLFileName, ReportServerName, TargetReportFolder, and ReportName; filling in the appropriate information
	      for each section. It then sends this to Y:\Scripts\SSRS\Report Uploads\Reports.csv, overwriting if necessary. All parameters are mandatory.
	    .EXAMPLE
	       Get-Reports -InstanceName SSRS115040BLANK
	    .INPUTS
	    .OUTPUTS
	       
	#>
	
	function New-SSRSFolder
	(#Define function parameters
	[Parameter(Position=0,Mandatory=$true)]
		[Alias("IName")]
		[string]$InstanceName,
	
	[Parameter(Position=0,Mandatory=$true)]
		[Alias("Folder")]
		[string]$FolderName,
	
	    [Parameter(Position=0,Mandatory=$true)]
		[Alias("Server")]
		[string]$ReportServer,

	[Parameter(Position=0,Mandatory=$true)]
		[Alias("ParentFolder")]
		[string]$Parent
	
	
	)
	{
        Write-Host "Creating $FolderName folder..."
	    
	   $ReportServerUri = "http://$($ReportServer)/ReportServer_" + $InstanceName + "/ReportService2010.asmx"
       $global:proxy = New-WebServiceProxy -Uri $ReportServerUri -UseDefaultCredential
      	
	    $type = $Proxy.GetType().Namespace #Giving the variable a specific type, this is necessary due to the implied namespace and datatype confusion of 
	                                       #Microsoft.ReportingServices.WebServer.ReportingService2010
	    $datatype = ($type + '.Property')  #Cast that variable in to what we need
	            
	    $property =New-Object ($datatype); #Create the property variable with the datatype we need and set a couple properties for later
	    $property.Name = $FolderName
        #$property.Parent = $Parent       
	    $property.Value = $FolderName
	            
	    $numproperties = 1
	    $properties = New-Object ($datatype + '[]')$numproperties 
	    $properties[0] = $property;
	     
	    $newFolder = $proxy.CreateFolder($FolderName, $Parent, $properties);  #Call the CreateFolder method from the ReportService2010 namespace
	    
	}
	<#
	    .Synopsis
	      Creates a new folder in a native mode SSRS deployment based upon the 3 parameters it is given
	    .DESCRIPTION
	      The cmdlet creates a folder based upon $ReportServer(host), $InstanceName(Instance of SSRS that you wish to deploy a folder to), and
	      $FolderName(the name of the folder you wish to create). It creates a proxy of the Report Service URL for SSRS, calling the 
	      CreateFolder method to do the leg work of the function. All parameters are mandatory.
	    .EXAMPLE
	       New-SSRSFolder -ReportServer localhost -InstanceName 115040BLANK -FolderName FHNETReports
	    .INPUTS
	    .OUTPUTS
	       
	#>
	
	
	function Publish-SSRS
	(#Define function parameters
	
	    [Parameter(Position=0,Mandatory=$true)]
		[Alias("Instance")]
		[string]$InstanceName,
	    
	    
	    [Parameter(Position=0,Mandatory=$true)]
		[Alias("Server")]
		[string]$ReportServer
	
	)
	{
	#variables
	$SourceDirectory = $SourcePath
	
	$DeploymentFileName = $CSVPath
	#Load the csv in to memory and then loop through its contents
	Import-Csv $DeploymentFileName | foreach {          
	   $ReportServiceURI = "http://$($ReportServer)/ReportServer_$($InstanceName)/ReportService2010.asmx"  
        if($_.ParentFolder -eq "EMS Patient Care Report")
        {
            $RDLFileName = $SourceDirectory + "EMS\" + $_.ParentFolder + "\"  + $_.RDLFileName
            $FinalPath = $_.ReportBaseFolder + "EMS/" + $_.ParentFolder
        }
        Elseif($_.ParentFolder -eq "FHnet Incident Report")
        {
            $RDLFileName = $SourceDirectory + "Incident\" + $_.ParentFolder + "\"  + $_.RDLFileName
            $FinalPath = $_.ReportBaseFolder + "Incident/" + $_.ParentFolder
        }
        Else
        {
            	   $RDLFileName = $SourceDirectory + $_.ParentFolder + "\" + $_.RDLFileName
                   $FinalPath = $_.ReportBaseFolder + $_.ParentFolder
        }
	   $Output = $_.ReportName
	    #Write some updates to the user
	    write-host "----------------------------------------------------------------------------------------------------------------------------------------"
	    write-host "Deploying" $RDLFileName 
	    write-host " to" $FinalPath "as" $Output
	    
	    #Call the Upload-Reports function to do most of the legwork here.
	    Push-Reports -RDLFileName $RDLFileName -ReportName $_.ReportName -Path $FinalPath -ReportServer $ReportServer -InstanceName $InstanceName
	
	    #Send any warnings to the user
	    if ($Warnings) {
	       foreach ($Warning in $Warnings) {
	            write-warning $Warning.Message
	        }
	    }
	}
	#Set-DataSource -InstanceName $InstanceName -ReportServer $ReportServer
	}
	<#
	    .Synopsis
	      Uploads all the reports in the $SourceDirectory to the specified SSRS instance
	    .DESCRIPTION
	      The script imports a .csv file that was previously created to guide it through the process of 
	      uploading reports to a SSRS instance. It does this through a foreach loop, calling a seperate function to do the 
	      bulk of the work by passing it $InstanceName and $ReportServer. All parameters are mandatory.
	    .EXAMPLE
	       Deploy-SSRS -ReportServer localhost -InstanceName SSRS115040BLANK
	    .INPUTS
	    .OUTPUTS
	       
	#>
	function Push-Reports
	(#Define function parameters
	    [Parameter(Position=0,Mandatory=$true)]
		[Alias("FileName")]
		[string]$RDLFileName,
	
	    [Parameter(Position=0,Mandatory=$true)]
		[Alias("Rname")]
		[string]$ReportName,
	
	    [Parameter(Position=0,Mandatory=$true)]
		[Alias("Rpath")]
		[string]$Path,
	
	    [Parameter(Position=0,Mandatory=$true)]
		[Alias("Server")]
		[string]$ReportServer,
	    
	    [Parameter(Position=0,Mandatory=$true)]
		[Alias("Instance")]
		[string]$InstanceName
	)
	
	{
	    $ReportServiceURI = "http://$($ReportServer)/ReportServer_$($InstanceName)/ReportService2010.asmx"
	    $SSRSproxy = New-WebServiceProxy -uri $ReportServiceURI -UseDefaultCredential #Create a WebServiceProxy to help us do our work
	    $stream = Get-Content $RDLFileName -Encoding byte                             #load the contents of the .rdl file in to memory
	    $warnings =@();
        $ExtensionTest = [System.IO.Path]::GetExtension($RDLFileName) 
	    $SSRSproxy.CreateCatalogItem("Report",$ReportName,$Path,$true,$stream,$null,[ref]$warnings) #Create the report on the server from the .rdl definition
	}
	<#
	    .Synopsis
	      Uploads a report to the given ReportService URI when given 5 parameters: $RDLFileName, $ReportName, $Path,, $InstanceName and $ReportServer.
	    .DESCRIPTION
	      The Script takes a series of parameters and then calls the CreateCatalogItem method of the ReportService2010 namespace
	      in order to upload/create a report from an .rdl definition to a SSRS native mode instance. All parameters are mandatory.
	    .EXAMPLE
	     Upload-Reports -RDLFileName $RDLFileName -ReportName $_.ReportName -Path $_.TargetReportFolder -ReportServer $ReportServer -InstanceName $InstanceName
	
	    .INPUTS
	    .OUTPUTS
	       
	#>
	function Set-DataSource
	(#Define function parameters
	    [Parameter(Position=0,Mandatory=$true)]
		[Alias("IName")]
		[string]$InstanceName,
        [Parameter(Position=0,Mandatory=$true)]
		[Alias("RFolderPath")]
		[string]$ReportFolderPath,
	    [Parameter(Position=0,Mandatory=$true)]
		[Alias("Server")]
		[string]$ReportServer
	)
	{
	# Set variables:
	    Write-Host "Setting the Datasource for the reports we just uploaded..."
	    $newDataSourcePath = "/DataSources/DataSourceFHNet"
	    $newDataSourceName = "DataSourceFHNet";
	    #$reportFolderPath = "/FHNetReports/System Reports"# make this a parameter and call it twice, specifying /FHNETReports/System Reports/EMS
        
	    $url = "http://$($Reportserver)/reportserver_$($InstanceName)/reportservice2010.asmx"
	#------------------------------------------------------------------------
	
	$ssrs = New-WebServiceProxy -uri $url -UseDefaultCredential
	
	$reports = $ssrs.ListChildren($reportFolderPath, $true)                  #Load all the report locations in to memory
	
	$reports | ForEach-Object {                                               #loop through all the reports    
	            $reportPath = $_.path                                         #$reportPath = the path property of the item currently looping
	            Write-Host "Report: " $reportPath
	            $dataSources = $ssrs.GetItemDataSources($reportPath)          #Get the current data source of the object
	            $dataSources | ForEach-Object {
	                            $proxyNamespace = $_.GetType().Namespace
	                            $myDataSource = New-Object ("$proxyNamespace.DataSource")    #explicit cast of $myDataSource in to the Datasource type of 
	                                                                                         #Microsoft.ReportingServices.WebServer.ReportingService2010
	                            $myDataSource.Name = $newDataSourceName
	                            $myDataSource.Item = New-Object ("$proxyNamespace.DataSourceReference")#explicit cast of $myDataSource in to the DatasourceReference type of 
	                                                                                                   #Microsoft.ReportingServices.WebServer.ReportingService2010
	
	                            $myDataSource.Item.Reference = $newDataSourcePath
	
	                            $_.item = $myDataSource.Item
	                               
	                            $ssrs.SetItemDataSources($reportPath, $_) #Set the object to the new data source using the SetItemDataSources method of the ReportingServices2010 namespace
	
	                            Write-Host "Report's DataSource Reference ($($_.Name)): $($_.Item.Reference)"#write result to user before looping through the next item.
	                            }
	
	            Write-Host "------------------------" 
	            }
	}
	
	<#
	    .Synopsis
	      Sets a previously created report's datasource.
	    .DESCRIPTION
	      Sets a previously created report's datasource based upon 2 parameters: $InstanceName and $ReportServer.
	      The Script creates a WebServiceProxy to the user specified instance of SSRS and then collects the names of all the 
	      reports in the specified directory. It then calls the SetItemDataSources method of the ReportService2010 namespace in order
	      to set the DataSource of all reports. All parameters are mandatory.
	    .EXAMPLE
	        Set-DataSource -InstanceName $Global:InitialCatalog -ReportServer $Global:ServerName
	    .INPUTS
	    .OUTPUTS
	       
	#>
	
	function New-DataSource
	(#Define function parameters
	    [Parameter(Position=0,Mandatory=$true)]
		[Alias("Catalog")]
		[string]$InitialCatalog,
	
	    [Parameter(Position=0,Mandatory=$true)]
		[Alias("Server")]
		[string]$ReportServer,

        [Parameter(Position=0,Mandatory=$true)]
		[Alias("Database")]
		[string]$DatabaseName,

        [Parameter(Position=0,Mandatory=$true)]
		[Alias("databaseServer")]
		[string]$dbServer
	)
	{
        Write-Host "Creating Datasource..."
	    $ReportServerUri  = "http://$($ReportServer)/ReportServer_$($InitialCatalog)/ReportService2010.asmx"
	    $proxy = New-WebServiceProxy -Uri $ReportServerUri -UseDefaultCredential
	    $type = $Proxy.GetType().Namespace #Explicit cast to the namespace type of the $proxy object(compatability reasons)
	
	    #create a DataSourceDefinition and set some properties of the new object
	    $dataSourceDefinitionType = ($type + '.DataSourceDefinition')
	    $dataSourceDefinition = New-Object($dataSourceDefinitionType)
	    $dataSourceDefinition.CredentialRetrieval = "Store"
        $dataSourceDefinition.UserName = $user
        $dataSourceDefinition.Password = $pass
	    $dataSourceDefinition.ConnectString = "Data Source=$($dbServer);Initial Catalog=$($DatabaseName)"
	    $dataSourceDefinition.extension = "SQL"
	    $dataSourceDefinition.enabled = $true
	    $dataSourceDefinition.Prompt = $null
	    $dataSourceDefinition.WindowsCredentials = $false
	
	    $dataSource = "DataSourceFHNet" #define the new datasource
	    $parent = "/DataSources"        #Parent folder
	    $overwrite = $true              
	
	    $newDataSource = $proxy.CreateDataSource($dataSource, $parent, $overwrite,$dataSourceDefinition, $null)# Create the data source from our parameters.
	}
	<#
	    .Synopsis
	      Creates a new DataSource ##NOTE## This cmdlet is only intended for Native Mode, you will need to make changes to the connection if you are using Sharepoint
	    .DESCRIPTION
	      Creates a new DataSource based upon 3 parameters: $InitialCatalog, $DataSource, and $ParentDirectory. This script 
	      then instantiates a variable of the same type as the SSRS object we are working with so there will be no type errors,
	      then we set some various properties of the new object, and call the CreateDataSource from the ReportService2010 namespace
	      to create the DataSource for us. All parameters are mandatory.
	    .EXAMPLE
	        New-DataSource -InitialCatalog SSRS115040BLANK -$DataSource DataSourceFHNet -ParentDirectory DataSources -ReportServer localhost
	    .INPUTS
	    .OUTPUTS
	       
	#>
if($DeployFolders -match "true")
   {
        
        Write-Host -ForegroundColor Green "Deploying Folders"
        New-SSRSFolder -FolderName "DataSources" -InstanceName $InstanceName -ReportServer $ServerName -Parent "/"
        New-SSRSFolder -FolderName "FHNetReports" -InstanceName $InstanceName -ReportServer $ServerName -Parent "/"
        New-SSRSFolder -FolderName "System Reports" -InstanceName $InstanceName -ReportServer $ServerName -Parent "/FHNETReports"
        New-SSRSFolder -FolderName "User Defined Reports" -InstanceName $InstanceName -ReportServer $ServerName -Parent "/FHNETReports"
        New-SSRSFolder -FolderName "Administrative" -InstanceName $InstanceName -ReportServer $ServerName -Parent "/FHNetReports/System Reports"
        New-SSRSFolder -FolderName "EMS" -InstanceName $InstanceName -ReportServer $ServerName -Parent "/FHNetReports/System Reports"
        New-SSRSFolder -FolderName "Hydrant" -InstanceName $InstanceName -ReportServer $ServerName -Parent "/FHNetReports/System Reports"
        New-SSRSFolder -FolderName "EMS Patient Care Report" -InstanceName $InstanceName -ReportServer $ServerName -Parent "/FHNETReports/System Reports/EMS"
        New-SSRSFolder -FolderName "Incident" -InstanceName $InstanceName -ReportServer $ServerName -Parent "/FHNetReports/System Reports"
        New-SSRSFolder -FolderName "FHnet Incident Report" -InstanceName $InstanceName -ReportServer $ServerName -Parent "/FHNETReports/System Reports/Incident"
        New-SSRSFolder -FolderName "Inspection" -InstanceName $InstanceName -ReportServer $ServerName -Parent "/FHNetReports/System Reports"
        New-SSRSFolder -FolderName "Inventory" -InstanceName $InstanceName -ReportServer $ServerName -Parent "/FHNetReports/System Reports"
        New-SSRSFolder -FolderName "Investigation" -InstanceName $InstanceName -ReportServer $ServerName -Parent "/FHNetReports/System Reports"
        New-SSRSFolder -FolderName "Occupancy" -InstanceName $InstanceName -ReportServer $ServerName -Parent "/FHNetReports/System Reports"
        New-SSRSFolder -FolderName "Schedule" -InstanceName $InstanceName -ReportServer $ServerName -Parent "/FHNetReports/System Reports"
        New-SSRSFolder -FolderName "Staff" -InstanceName $InstanceName -ReportServer $ServerName -Parent "/FHNetReports/System Reports"
        New-SSRSFolder -FolderName "Staff Activities" -InstanceName $InstanceName -ReportServer $ServerName -Parent "/FHNetReports/System Reports"
        New-SSRSFolder -FolderName "Training" -InstanceName $InstanceName -ReportServer $ServerName -Parent "/FHNetReports/System Reports"
        New-SSRSFolder -FolderName "Training Programs" -InstanceName $InstanceName -ReportServer $ServerName -Parent "/FHNetReports/System Reports"

    }

if($CreateDatasource -match "true")
{
    New-DataSource -InitialCatalog $InstanceName -ReportServer $ServerName -Database $DatabaseName -dbserver $DatabaseServer
}
Get-Reports -InstanceName $InstanceName
Publish-SSRS -InstanceName $InstanceName -ReportServer $ServerName 
Set-DataSource -InstanceName $InstanceName -ReportServer $ServerName -ReportFolderPath "/FHNetReports/System Reports"
Set-DataSource -InstanceName $InstanceName -ReportServer $ServerName -ReportFolderPath "/FHNetReports/System Reports/EMS"
Set-DataSource -InstanceName $InstanceName -ReportServer $ServerName -ReportFolderPath "/FHNetReports/System Reports/Incident"




#Use this to install a new RS instance - modify the instance name.
#Y:\InstallMedia\Microsoft\SQL\SQL2012EE\SQLServer2012EE\Setup.exe /qs /Action=Install UpdateEnabled=0 /InstanceName="SSRSMDFREDERICK" /IACCEPTSQLSERVERLICENSETERMS  /Action=Install /FEATURES=RS /RSINSTALLMODE=DEFAULTNATIVEMODE /RSSVCSTARTUPTYPE="Automatic"
Write-Host -ForegroundColor Yellow "Press any key to exit ..."
$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
# SIG # Begin signature block
# MIINMAYJKoZIhvcNAQcCoIINITCCDR0CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUCylKYYt8iP7VbLKfdkma3JiM
# XLCgggpyMIIFMDCCBBigAwIBAgIQBAkYG1/Vu2Z1U0O1b5VQCDANBgkqhkiG9w0B
# AQsFADBlMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1cmVk
# IElEIFJvb3QgQ0EwHhcNMTMxMDIyMTIwMDAwWhcNMjgxMDIyMTIwMDAwWjByMQsw
# CQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cu
# ZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFzc3VyZWQgSUQg
# Q29kZSBTaWduaW5nIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA
# +NOzHH8OEa9ndwfTCzFJGc/Q+0WZsTrbRPV/5aid2zLXcep2nQUut4/6kkPApfmJ
# 1DcZ17aq8JyGpdglrA55KDp+6dFn08b7KSfH03sjlOSRI5aQd4L5oYQjZhJUM1B0
# sSgmuyRpwsJS8hRniolF1C2ho+mILCCVrhxKhwjfDPXiTWAYvqrEsq5wMWYzcT6s
# cKKrzn/pfMuSoeU7MRzP6vIK5Fe7SrXpdOYr/mzLfnQ5Ng2Q7+S1TqSp6moKq4Tz
# rGdOtcT3jNEgJSPrCGQ+UpbB8g8S9MWOD8Gi6CxR93O8vYWxYoNzQYIH5DiLanMg
# 0A9kczyen6Yzqf0Z3yWT0QIDAQABo4IBzTCCAckwEgYDVR0TAQH/BAgwBgEB/wIB
# ADAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwMweQYIKwYBBQUH
# AQEEbTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQwYI
# KwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFz
# c3VyZWRJRFJvb3RDQS5jcnQwgYEGA1UdHwR6MHgwOqA4oDaGNGh0dHA6Ly9jcmw0
# LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwOqA4oDaG
# NGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RD
# QS5jcmwwTwYDVR0gBEgwRjA4BgpghkgBhv1sAAIEMCowKAYIKwYBBQUHAgEWHGh0
# dHBzOi8vd3d3LmRpZ2ljZXJ0LmNvbS9DUFMwCgYIYIZIAYb9bAMwHQYDVR0OBBYE
# FFrEuXsqCqOl6nEDwGD5LfZldQ5YMB8GA1UdIwQYMBaAFEXroq/0ksuCMS1Ri6en
# IZ3zbcgPMA0GCSqGSIb3DQEBCwUAA4IBAQA+7A1aJLPzItEVyCx8JSl2qB1dHC06
# GsTvMGHXfgtg/cM9D8Svi/3vKt8gVTew4fbRknUPUbRupY5a4l4kgU4QpO4/cY5j
# DhNLrddfRHnzNhQGivecRk5c/5CxGwcOkRX7uq+1UcKNJK4kxscnKqEpKBo6cSgC
# PC6Ro8AlEeKcFEehemhor5unXCBc2XGxDI+7qPjFEmifz0DLQESlE/DmZAwlCEIy
# sjaKJAL+L3J+HNdJRZboWR3p+nRka7LrZkPas7CM1ekN3fYBIM6ZMWM9CBoYs4Gb
# T8aTEAb8B4H6i9r5gkn3Ym6hU/oSlBiFLpKR6mhsRDKyZqHnGKSaZFHvMIIFOjCC
# BCKgAwIBAgIQDPQXY1pCdBNoD32e1CJn2TANBgkqhkiG9w0BAQsFADByMQswCQYD
# VQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGln
# aWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFzc3VyZWQgSUQgQ29k
# ZSBTaWduaW5nIENBMB4XDTE1MDMzMTAwMDAwMFoXDTE4MDQwNDEyMDAwMFowgYAx
# CzAJBgNVBAYTAlVTMQ0wCwYDVQQIEwRJb3dhMRIwEAYDVQQHEwlVcmJhbmRhbGUx
# JjAkBgNVBAoTHVhlcm94IEdvdmVybm1lbnQgU3lzdGVtcywgTExDMSYwJAYDVQQD
# Ex1YZXJveCBHb3Zlcm5tZW50IFN5c3RlbXMsIExMQzCCASIwDQYJKoZIhvcNAQEB
# BQADggEPADCCAQoCggEBALVI2Sca1uGibwFPa0Y61L5xQGI4Kpjknw0MKhnWtoZv
# UskWa36AS/ujFg806WLi415b0SJs4aw1egehKryR3IpzElmRHk/xj9SIMpKwJzTV
# ElNOnlH2RqPiMdrq8VHlZZeFLKR47puOWViRj70aE7KkLl+H0esE4YPCYEswLUlo
# qnRcSusfnB4VTCXhj/ETIOckCUtofkxTSD7HpGctERFNLvf+yXGMYsXWMPu9V5JT
# dy9kAq59uPrf2b7BtVM8KYH3jGRnNbstLsMA0eHuCf29SZvGMMkANGaZCEXC0aYo
# NbIOQ0Ho8L3hyXOvkmdCvN+Ex/jN/670jGeMM3cA0DkCAwEAAaOCAbswggG3MB8G
# A1UdIwQYMBaAFFrEuXsqCqOl6nEDwGD5LfZldQ5YMB0GA1UdDgQWBBQhgwM05wJx
# 4tp0U6dUA7+krD2ZlzAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUH
# AwMwdwYDVR0fBHAwbjA1oDOgMYYvaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL3No
# YTItYXNzdXJlZC1jcy1nMS5jcmwwNaAzoDGGL2h0dHA6Ly9jcmw0LmRpZ2ljZXJ0
# LmNvbS9zaGEyLWFzc3VyZWQtY3MtZzEuY3JsMEIGA1UdIAQ7MDkwNwYJYIZIAYb9
# bAMBMCowKAYIKwYBBQUHAgEWHGh0dHBzOi8vd3d3LmRpZ2ljZXJ0LmNvbS9DUFMw
# gYQGCCsGAQUFBwEBBHgwdjAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNl
# cnQuY29tME4GCCsGAQUFBzAChkJodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20v
# RGlnaUNlcnRTSEEyQXNzdXJlZElEQ29kZVNpZ25pbmdDQS5jcnQwDAYDVR0TAQH/
# BAIwADANBgkqhkiG9w0BAQsFAAOCAQEAt9TEdvtulxC/O4pa/coYANUpT3X1rm2V
# pX7KbrOg6OlX1oCWqQEA18NizSco2xUMMCcgwXo8nl/56vhAQWQhIjuQSQIX8gnC
# yagYbI9yofoz5RNVvL7fM+sdIG4lg9/kn5Wi7uqol9cmbQd3UQgHKYfr1GMtqlp3
# PftMKpn6cceaE/f/ESF/x+SqXf7WGe/3rpdjulW5P4PC+79jwnujXbpijk1Sz4GX
# ztSlKHmqcCA9kUmzEJm3laa/qeF9BioRKiGC1snbjPlrvgq8XOluvsvhchUHKlcu
# mwCjC7/3XAj/gxTthFxKRLpU0LcWbbF/bpk8XdNMT+phKoCoU10n2jGCAigwggIk
# AgEBMIGGMHIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAX
# BgNVBAsTEHd3dy5kaWdpY2VydC5jb20xMTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIg
# QXNzdXJlZCBJRCBDb2RlIFNpZ25pbmcgQ0ECEAz0F2NaQnQTaA99ntQiZ9kwCQYF
# Kw4DAhoFAKB4MBgGCisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkD
# MQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJ
# KoZIhvcNAQkEMRYEFJQoAAsKd6d+KySmDbopxUC3roNDMA0GCSqGSIb3DQEBAQUA
# BIIBABW4cVTlG0HT03EPBM8JBN7N2accYaLo109Oj5VEi3P703/n3Yo4M4rYweu4
# eNntTdfWbLU9rvxfv9KC4hqIom1tq5XpeOgA4vG+NeJPxdT/bonOe3Pryl63WOAv
# oiXJ+ZT9SVm3RPzhKyA5W7hp6HbvuGineXg1tAcHCJdvFe8y8A3Drc1CByFJoJww
# 8uv33hyF1JfFVRCa+8j44COEb6T+ZGVMaEvXmSJ6bl+nCzAfN4rVxEurGdVY2MgQ
# lU3MZ6h+06kOLgSJKZE9f5za60NW3mihTTBqnG/y8D9s4/5/HNx6JzPJ1xJKu4re
# 4xfI1SBbFVgxI21yrmEc68ZWLsw=
# SIG # End signature block
