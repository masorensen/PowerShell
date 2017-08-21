function Publish-DSCResourceRemotely {
Param(
    [string[]]$Module,
    [string]$ComputerName
)

    foreach ($ModuleName in $Module)
    {
    
        $ModuleVersion = (Get-Module $ModuleName -ListAvailable).Version
        $ModulePath = (Get-Module $ModuleName -ListAvailable | Select-Object Path) | Split-Path | Split-Path
        $DestinationZipPath = "\\$ComputerName\c`$\Program Files\WindowsPowerShell\DscService\Modules\$($ModuleName)_$($ModuleVersion).zip"
    
        Compress-Archive -Update -Path "$ModulePath\*" -DestinationPath $DestinationZipPath
    
        New-DscChecksum $DestinationZipPath
    }

}