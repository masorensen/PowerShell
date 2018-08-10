#Script needs to be run in an elevated PowerShell session to read registry keys that aren't...
#...owned by the current user
#The following code will prompt for elevation, if not already elevated
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {   
    $Arguments = "& '" + $MyInvocation.MyCommand.Definition + "'"
    #This opens a new PowerShell module, running as administrator
    Start-Process powershell -Verb runAs -ArgumentList $Arguments
    break
}

New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_Users -ErrorAction SilentlyContinue | Out-Null
$Version = (New-Object -ComObject Excel.Application).Version
$Path = "HKU:\*\Software\Microsoft\Office\$Version"
$ExcelProperty = "WorkbookLinkWarnings"
$ExcelValue = 2

$OWProperty = "DontUpdateLinks"
$OWValue = 1

$Incorrect = 0

foreach($RegPath in Get-ChildItem -Path $Path -ErrorAction SilentlyContinue) {
    if($RegPath) {
        $RegPath = $RegPath.Name
        $RegPath = $RegPath -replace ("HKEY_Users", "HKU:")  
        $ExcelPath = $RegPath + "\Excel\Security"
        if(-not (Test-Path ($ExcelPath) -ErrorAction SilentlyContinue)) {
            $Incorrect++
        }

        try{
            if(-not ((Get-ItemPropertyValue -Path $ExcelPath -Name $ExcelProperty -ErrorAction SilentlyContinue) -eq $ExcelValue)) {
                $Incorrect++
            }
        } catch {
            $Incorrect++
        }
        
        $OutlookPath = $RegPath + "\Word\Options\WordMail"
        if(-not (Test-Path ($OutlookPath) -ErrorAction SilentlyContinue)) {
            $Incorrect++
        }
        
        
        try 
        {
            if(-not ((Get-ItemPropertyValue -Path $OutlookPath -Name $OWProperty -ErrorAction SilentlyContinue) -eq $OWValue)) {
                $Incorrect++
            }
        } catch {
            $Incorrect++
        }
        

        $WordPath = $RegPath + "\Word\Options"
        if(-not (Test-Path ($WordPath) -ErrorAction SilentlyContinue)) {
            $Incorrect++
        }

        try {
            if(-not ((Get-ItemPropertyValue -Path $WordPath -Name $OWProperty -ErrorAction SilentlyContinue) -eq $OWValue)) {
                $Incorrect++
            }
        } catch {
            $Incorrect++
        }        
    }
}

if($Incorrect -gt 0) {
    Write-Output "Configuration is not correct"
} else {
    Write-Output "Configuration is correct"
}