$x64Path = "HKLM:\SOFTWARE\WOW6432Node\Policies\Adobe\Adobe Acrobat\2017\FeatureLockDown\bUpdater"
$x86Path = "HKLM:\SOFTWARE\Policies\Adobe\Adobe Acrobat\2017\FeatureLockDown\bUpdater"

if([intpr]::Size -eq 4) {
    #Machine is using x86 architecture, use the x86Path
    Set-ItemProperty -Path $x86Path -Name "Value" -Value "0"
} elseif([intpr]::Size -eq 8) {
    #Machine is using x64 architecture, use the x64Path
    Set-ItemProperty -Path $x64Path -Name "Value" -Value "0"
}

