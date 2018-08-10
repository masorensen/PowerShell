#Script needs to be run in an elevated PowerShell session to read/create/update registry keys that aren't...
#...accessible by a regular user
#The following code will prompt for elevation, if not already elevated
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {   
    $Arguments = "& '" + $MyInvocation.MyCommand.Definition + "'"
    #This opens a new PowerShell module, running as Administrator
    Start-Process powershell -Verb runAs -ArgumentList $Arguments
    break
}
#Define registry path, property, and value for disabling SSL 2.0
$RegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0"
$Name = "DisabledByDefault"
$Value = "00000001"

#Check if registry path exists
if(!(Test-Path $RegistryPath)) {
    #Path doesn't exist, create it and create the property with the value of $Value
    New-Item -Path $RegistryPath -Force | Out-Null
    New-ItemProperty -Path $RegistryPath -Name $name -Value $Value -PropertyType DWORD -Force | Out-Null
} else {
    #Path exists, create/update property value with $Value
    New-ItemProperty -Path $RegistryPath -Name $name -Value $Value -PropertyType DWORD -Force | Out-Null
} 