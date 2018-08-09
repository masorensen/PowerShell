param(
    [string]$ComputerName
)

if (((Get-WmiObject -Namespace "root\CIMV2\Security\MicrosoftVolumeEncryption" -Class Win32_EncryptableVolume -ComputerName $ComputerName).GetProtectionStatus().ProtectionStatus) = 1) {
    Write-Output 'BitLocker is enabled'
} else {
    Write-Output 'BitLocker is not enabled'
}