$ServiceCount=0
$ServicePaths = @()
$ResolveEnvironmentVariables = $True
Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\" | ForEach-Object {
    $OriginalPath = (Get-ItemProperty "$($($_).name.replace('HKEY_LOCAL_MACHINE', 'HKLM:'))")
    if ($ResolveEnvironmentVariables){
        if ($($OriginalPath.ImagePath) -match '%(?''envVar''[^%]+)%'){
            $EnvVar = $Matches['envVar']
            $FullVar = (Get-ChildItem env: | Where-Object Name -eq $EnvVar).Value
            $ImagePath = $OriginalPath.ImagePath -replace "%$EnvVar%",$FullVar
            
            Clear-Variable Matches
        } else {
            $ImagePath = $OriginalPath.ImagePath
        }
    } else {
        $ImagePath = $OriginalPath.ImagePath
    }

    # Get all services with unquoted path vulerability
    If ($ImagePath -like "* *.exe*" -and $ImagePath -notlike '"*"*'){
        $ServiceCount++
        $ServicePaths += $ImagePath
    }
}

$UninstallCount = 0
$UninstallPaths = @()
Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\" | ForEach-Object {
    $OriginalPath = (Get-ItemProperty "$($($_).name.replace('HKEY_LOCAL_MACHINE', 'HKLM:'))")
    $UninstallString = $OriginalPath.UninstallString
    if ($ResolveEnvironmentVariables){
        if ($($OriginalPath.UninstallString) -match '%(?''envVar''[^%]+)%'){
            $EnvVar = $Matches['envVar']
            $FullVar = (Get-ChildItem env: | Where-Object Name -eq $EnvVar).Value
            $UninstallString = $OriginalPath.UninstallString -replace "%$EnvVar%",$FullVar

            Clear-Variable Matches
        }
        else {
            $UninstallString = $OriginalPath.UninstallString
        }
    }
    else{
        $UninstallString = $OriginalPath.UninstallString
    }
    If ($UninstallString -like "* *.exe*" -and $UninstallString -notlike '"*"*'){
        $UninstallCount++
        $UninstallPaths += $UninstallString
    }
}


If ($ServiceCount -gt 0 -or $UninstallCount -gt 0) {
   Write-Output "Unquoted Paths Exist"
}
elseif($ServiceCount -eq 0 -and $UninstallCount -eq 0) {
    Write-Output "Unquoted Paths Do Not Exist"
}
