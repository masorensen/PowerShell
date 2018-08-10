$SourceFile = "C:\ProgramData\regid.1986-12.com.adobe\regid.1986-12.com.adobe*"
[XML]$XML = Get-Content -Path $SourceFile
$SerialNumber = $XML.GetElementsByTagName('swid:serial_number')
$SerialNumber = $SerialNumber.'#Text'
$UninstallRegistryPath = 'HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{AC76BA86-1033-FFFF-7760-0E1108756300}'
$Year = '2017'

if($SerialNumber -like "9707*") {
    Set-ItemProperty -Path $UninstallRegistryPath -Name DisplayName -Value "Acrobat $Year Professional"
} elseif($SerialNumber -like "9101*") {
    Set-ItemProperty -Path $UninstallRegistryPath -Name DisplayName -Value "Acrobat $Year Standard"
}