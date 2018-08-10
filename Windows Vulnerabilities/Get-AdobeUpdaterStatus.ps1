$x64Path = "HKLM:\SOFTWARE\WOW6432Node\Policies\Adobe\Adobe Acrobat\2017\FeatureLockDown\bUpdater"
$x86Path = "HKLM:\SOFTWARE\Policies\Adobe\Adobe Acrobat\2017\FeatureLockDown\bUpdater"
function Test-RegistryValue{
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]$Path,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]$Value,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]$FinalValue
    )
    try{
        if([intpr]::Size -eq 4) {
            #Machine is using x86 architecture, use the x86Path
            $Value = Get-ItemProperty -Path $x86Path | Select-Object -ExpandProperty $Value -ErrorAction Stop | Out-Null
        } elseif([intpr]::Size -eq 8) {
            #Machine is using x64 architecture, use the x64Path
            $Value = Get-ItemProperty -Path $x64Path | Select-Object -ExpandProperty $Value -ErrorAction Stop | Out-Null
        }
        
        if($Value -eq $FinalValue) {
            return $true
        } else {
            return $false
        }
    } catch {
        return $false
    }
}

if((Test-RegistryValue -Path $Path -Value "Value" -FinalValue "0") -eq $true) {
    Write-Output "Adobe Updater Status is Correct"
} else {
    Write-Output "Adobe Updater Status is not Correct"
}