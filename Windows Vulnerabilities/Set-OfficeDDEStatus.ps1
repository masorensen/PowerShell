#Script needs to be run in an elevated PowerShell session in order to read/create/update...
#...registry keys that aren't owned by the current user
#The following code will prompt for elevation, if not already elevated
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {   
    $Arguments = "& '" + $MyInvocation.MyCommand.Definition + "'"
    #This opens a new PowerShell module, running as administrator
    Start-Process powershell -Verb runAs -ArgumentList $Arguments
    break
}

#Must create a HKU: PS drive to interact with the HKEY_Users hive
New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_Users -ErrorAction SilentlyContinue | Out-Null
#Dynamically pull the Office version in use on the machine
$Version = (New-Object -ComObject Excel.Application).Version
#Define the registry wildcard pattern to use with Get-ChildItem
$Path = "HKU:\*\Software\Microsoft\Office\$Version"

#Define the Excel registry property/value to use
$ExcelProperty = "WorkbookLinkWarnings"
$ExcelValue = 2

#Define the Outlook & Word registry property/value to use
$OWProperty = "DontUpdateLinks"
$OWValue = 1

#Loop through the registry using the wildcard & pattern defined in $Path
foreach($RegPath in Get-ChildItem -Path $Path -ErrorAction SilentlyContinue) {
    $RegPath = $RegPath.Name
    $RegPath = $RegPath -replace ("HKEY_Users", "HKU:")
    #Check Excel
    $ExcelPath = $RegPath + "\Excel\Security"
    if(!(Test-Path $ExcelPath)) {
        #Path doesn't exist, create it
        New-Item -Path ($ExcelPath) -Force | Out-Null
    }
    #Create or update the property for Excel
    New-ItemProperty -Path $ExcelPath -Name $ExcelProperty -Value $ExcelValue -PropertyType DWORD -Force | Out-Null

    #Check Outlook
    $OutlookPath = $RegPath + "\Word\Options\WordMail"
    if(!(Test-Path $OutlookPath)) {
        #Path doesn't exist, create it
        New-Item -Path ($OutlookPath) -Force | Out-Null
    }
    #Create or update the property for Outlook
    New-ItemProperty -Path $OutlookPath -Name $OWProperty -Value $OWValue -PropertyType DWORD -Force | Out-Null   

    #Check Word
    $WordPath = $RegPath + "\Word\Options"
    if(!(Test-Path $WordPath)) {
        #Path doesn't exist, create it
        New-Item -Path ($WordPath) -Force | Out-Null
    }
    #Create or update the property for Word
    New-ItemProperty -Path $WordPath -Name $OWProperty -Value $OWValue -PropertyType DWORD -Force | Out-Null   
}