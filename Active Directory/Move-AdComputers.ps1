Import-Module ActiveDirectory
$OUName = "Company"
$SearchBase = "OU=Workstations,DC=domain,DC=com"
$FilePath = Read-Host "Please enter the path to the file with list of assets:"
$Credential = Get-Credential -Message "Please enter credentials with access to move these workstations"

$WorkstationList = Get-Content $FilePath
$OUDistinguishedName = (Get-ADOrganizationalUnit -Filter {Name -eq $OUName} -SearchBase $SearchBase -Properties DistinguishedName).DistinguishedName
foreach($Workstation in $WorkstationList)
{
    $WorkstationObject = Get-ADObject -Filter {Name -eq $Workstation}
    Move-ADObject -Credential $Credential -Identity $WorkstationObject -TargetPath $OUDistinguishedName
}