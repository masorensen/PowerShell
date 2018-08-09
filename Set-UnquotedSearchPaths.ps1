#Script needs to be run in an elevated PowerShell session
#The following code will prompt for elevation if not already elevated
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {   
    $Arguments = "& '" + $MyInvocation.MyCommand.Definition + "'"
    #This opens a new PowerShell session, running as administrator
    Start-Process powershell -Verb runAs -ArgumentList $Arguments
    break
}
Function Write-Log {    
    Param (
        [parameter(Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true,
            Position=0)]
        [AllowEmptyString()]
        [AllowNull()]
            [String[]]$Value,
        [parameter(Mandatory=$true,
            Position=1)]
        [alias("File","Filename","FullName")]
        [ValidateScript({
            If (Test-Path $_){
                -NOT ((Get-Item $_).Attributes -like "*Directory*")
            }
            ElseIf (-NOT (Test-Path $_)){
                $Tmp = $_
                $Tmp -match '(?''path''^\w\:\\([^\\]+\\)+)(?''filename''[^\\]+)' | Out-Null
                $TmpPath = $Matches['path']
                $Tmpfilename = $Matches['filename']
                New-Item -ItemType Directory $TmpPath -Force -ErrorAction Stop
                New-Item -ItemType File $TmpPath$Tmpfilename -ErrorAction Stop
            }
        })]
        [String]$Logname,
        [String]$AddAtBegin,
        [String]$AddToEnd,
        [String]$AddAtBeginRegOut,
        [String]$AddToEndRegOut,
        [switch]$SkipNullString,
        [switch]$OutOnScreen,
        [String]$OutRegexpMask
    )
    $Value -split '\n' | ForEach-Object {
        if ($SkipNullString -and (-not (([string]::IsNullOrEmpty($($_))) -or ([string]::IsNullOrWhiteSpace($($_)))))){
            if ([String]::IsNullOrEmpty($OutRegexpMask)){
                If ($OutOnScreen){"$AddAtBegin$($_ -replace '\r')$AddToEnd"}
                "$AddAtBegin$($_ -replace '\r')$AddToEnd" | out-file $Logname -Append
            }
            elseif (![String]::IsNullOrEmpty($OutRegexpMask)){
                if ($($_ -replace '\r') -match $OutRegexpMask){
                    "$AddAtBeginRegOut$($_ -replace '\r')$AddToEndRegOut"
                    "$AddAtBeginRegOut$($_ -replace '\r')$AddToEndRegOut" | out-file $Logname -Append
                }
                else {
                    "$AddAtBegin$($_ -replace '\r')$AddToEnd" | out-file $Logname -Append
                }
            }
        }
        elseif (-not ($SkipNullString)){
            if ([String]::IsNullOrEmpty($OutRegexpMask)){
                if ($OutOnScreen){"$AddAtBegin$($_ -replace '\r')$AddToEnd"}
                "$AddAtBegin$($_ -replace '\r')$AddToEnd" | out-file $Logname -Append
            }
            elseif (![String]::IsNullOrEmpty($OutRegexpMask)){
                if (($($_ -replace '\r') -match $OutRegexpMask) -or ([string]::IsNullOrEmpty($($_))) -or ([string]::IsNullOrWhiteSpace($($_)))){
                    "$AddAtBeginRegOut$($_ -replace '\r')$AddToEndRegOut"
                    "$AddAtBeginRegOut$($_ -replace '\r')$AddToEndRegOut" | out-file $Logname -Append
                }
                else {
                    "$AddAtBegin$($_ -replace '\r')$AddToEnd" | out-file $Logname -Append
                }
            }
        }
    }
}

Function Set-UnquotedPaths
{
    Param (
        [Switch]$FixEnvironmentVariables
    ) 

    "$(Get-Date -Format u)  :  INFO  :  Computername: $($Env:COMPUTERNAME)" 
#region Services Image Path
    Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\" | ForEach-Object {
        $OriginalPath = (Get-ItemProperty "$($($_).name.replace('HKEY_LOCAL_MACHINE', 'HKLM:'))")
        if ($FixEnvironmentVariables){
            if ($($OriginalPath.ImagePath) -match '%(?''envVar''[^%]+)%'){
                $EnvironmentVariables = $Matches['envVar']
                $FullVariable = (Get-Childitem env: | Where-Object Name -eq $EnvironmentVariables).value
                $ImagePath = $OriginalPath.ImagePath -replace "%$EnvironmentVariables%",$FullVariable
                Clear-Variable Matches
            } else {
                $ImagePath = $OriginalPath.ImagePath
            }
        } else {
            $ImagePath = $OriginalPath.ImagePath
        }
        if (($ImagePath -like "* *") -and ($ImagePath -notlike '"*"*') -and ($ImagePath -like '*.exe*')){             
            $NewPath = ($ImagePath -split ".exe ")[0]
            $Key = ($ImagePath -split ".exe ")[1]
            $Trigger = ($ImagePath -split ".exe ")[2]
            
            if (-not ($Trigger | Measure-Object).count -ge 1){
                if (($NewPath -like "* *") -and ($NewPath -notlike "*.exe")){
                    $NewValue = "`"$NewPath.exe`" $Key"
                } elseif (($NewPath -like "* *") -and ($NewPath -like "*.exe")){    
                    $NewValue = "`"$NewPath`""
                }
                
                if ((-not ([string]::IsNullOrEmpty($NewValue))) -and ($NewPath -like "* *")) {
                    try {
                        "$(Get-Date -Format u)  :  Old Value :  Service: '$($OriginalPath.PSChildName)' - $($OriginalPath.ImagePath)" 
                        "$(Get-Date -Format u)  :  Expected  :  Service: '$($OriginalPath.PSChildName)' - $NewValue" 
                        Set-ItemProperty -Path $OriginalPath.PSPath -Name "ImagePath" -Value $NewValue -ErrorAction Stop
                        if ((Get-ItemProperty -Path $OriginalPath.PSPath).imagepath -eq $NewValue){
                            "$(Get-Date -Format u)  :  SUCCESS  : New Value of ImagePath was changed for service '$($OriginalPath.PSChildName)'" 
                        }
                        else {
                            "$(Get-Date -Format u)  :  ERROR  : Something is going wrong. Value changing failed in service '$($OriginalPath.PSChildName)'."
                        } 
                    } catch {
                        "$(Get-Date -Format u)  :  ERROR  : Something is going wrong. Value changing failed in service '$($OriginalPath.PSChildName)'."
                        "$(Get-Date -Format u)  :  ERROR  :  $($Error[0].Exception.Message)"
                    }
                    Clear-Variable NewValue
                }
            }
        }
        
        if (($Trigger | Measure-Object).count -ge 1) { 
            "$(Get-Date -Format u)  :  ERROR  :  Can't parse  $($OriginalPath.ImagePath) in registry  $($OriginalPath.PSPath -replace 'Microsoft\.PowerShell\.Core\\Registry\:\:') " 
        }
    }
#endregion

#region Uninstall String
    Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\" | ForEach-Object {
        $UninstallPath = (Get-ItemProperty "$($($_).name.replace('HKEY_LOCAL_MACHINE', 'HKLM:'))")
        if ($FixEnvironmentVariables){
            if ($($UninstallPath.UninstallString) -match '%(?''envVar''[^%]+)%'){
                $EnvironmentVariables = $Matches['envVar']
                $FullVariable = (Get-Childitem env: | Where-Object Name -eq $EnvironmentVariables).value
                $UninstallString = $UninstallPath.UninstallString -replace "%$EnvironmentVariables%",$FullVariable
                Clear-Variable Matches
            } else {
                $UninstallString = $UninstallPath.UninstallString
            }
        } else{
            $UninstallString = $UninstallPath.UninstallString
        }

        if (($UninstallString -like "* *") -and ($UninstallString -notlike '"*"*') -and ($UninstallString -like '*.exe*')){             
            $NewPath = ($UninstallString -split ".exe ")[0]
            $Key = ($UninstallString -split ".exe ")[1]
            $Trigger = ($UninstallString -split ".exe ")[2]
            
            if (-not ($Trigger | Measure-Object).count -ge 1){
                if (($NewPath -like "* *") -and ($NewPath -notlike "*.exe")){
                    $NewValue = "`"$NewPath.exe`" $Key"
                }

                elseif (($NewPath -like "* *") -and ($NewPath -like "*.exe")){    
                    $NewValue = "`"$NewPath`""
                }
                
                if ((-not ([string]::IsNullOrEmpty($NewValue))) -and ($NewPath -like "* *")) {
                    try {
                        "$(Get-Date -Format u)  :  Old Value :  Service: '$($OriginalPath.PSChildName)' - $($OriginalPath.UninstallString)" 
                        "$(Get-Date -Format u)  :  Expected  :  Service: '$($OriginalPath.PSChildName)' - $NewValue" 
                        Set-ItemProperty -Path $OriginalPath.PSPath -Name "UninstallString" -Value $NewValue -ErrorAction Stop
                        if ((Get-ItemProperty -Path $OriginalPath.PSPath).UninstallString -eq $NewValue){
                            "$(Get-Date -Format u)  :  SUCCESS  : New Value of ImagePath was changed for service '$($OriginalPath.PSChildName)'" 
                        } else {
                            "$(Get-Date -Format u)  :  ERROR  : Something is going wrong. Value changing failed in service '$($OriginalPath.PSChildName)'."
                        } 
                    } catch {
                        "$(Get-Date -Format u)  :  ERROR  : Something is going wrong. Value changing failed in service '$($OriginalPath.PSChildName)'."
                        "$(Get-Date -Format u)  :  ERROR  :  $($Error[0].Exception.Message)"
                    }
                    Clear-Variable NewValue
                }
            }
        }
        
        if (($Trigger | Measure-Object).count -ge 1) { 
            "$(Get-Date -Format u)  :  ERROR  :  Can't parse  $($OriginalPath.UninstallString) in registry  $($OriginalPath.PSPath -replace 'Microsoft\.PowerShell\.Core\\Registry\:\:') " 
        }
#endregion
    }
}

$Logname = "C:\Temp\UnquotedPathsFix-3.0.Log"

Set-UnquotedPaths -FixEnvironmentVariables | Write-Log -Logname $Logname -OutOnScreen
