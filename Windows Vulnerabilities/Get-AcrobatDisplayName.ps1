if((Get-WmiObject Win32_OperatingSystem  | Select-Object OSArchitecture).OSArchitecture -eq "64-bit") {
    $UninstallRegistryPath = "HKLM:SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{AC76BA86-1033-FFFF-7760-0E1108756300}"
} elseif((Get-WmiObject -ComputerName "ComputerName" Win32_OperatingSystem  | Select-Object OSArchitecture).OSArchitecture -eq "32-bit") {
    $UninstallRegistryPath = "HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{AC76BA86-1033-FFFF-7760-0E1108756300}"
}

if(Get-ItemProperty -Path $UninstallRegistryPath -Name 'DisplayName' -ErrorAction SilentlyContinue){
    $DisplayName = Get-ItemProperty -Path $UninstallRegistryPath -Name 'DisplayName'
} else {
    Write-Output "Adobe Acrobat uninstall key not present"
    break
}

if($DisplayName -ne 'Acrobat 2017 Professional' -and $DisplayName -ne 'Acrobat 2017 Standard') {
    Write-Output 'Registry value is incorrect'
} elseif($DisplayName -eq 'Acrobat 2017 Professional' -or $DisplayName -eq 'Acrobat 2017 Standard') {
    Write-Output 'Registry value is correct'
}

