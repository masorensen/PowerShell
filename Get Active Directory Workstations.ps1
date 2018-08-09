Import-Module ActiveDirectory
$Domain = "domain.com"
$OUToExclude = "*=Workstations,DC=domain,DC=com"

$Computers = @()
if($OUToExclude -match "^$") {
    foreach($Computer in Get-ADObject -Filter 'objectClass -eq "computer" -and operatingSystem -notlike "*Server*" -and operatingSystem -like "Windows*"' -Server $Domain -Properties DistinguishedName, Name) {
        $Row = "" | Select-Object OU, Name
        $Row.OU = ($Computer.DistinguishedName).Replace("CN=$($Computer.Name),", "")
        $Row.Name = $Computer.Name
        $Computers += $Row
    }    
} else {
    foreach($Computer in Get-ADObject -Filter 'objectClass -eq "computer" -and operatingSystem -notlike "*Server*" -and operatingSystem -like "Windows*"' -Server $Domain -Properties DistinguishedName, Name | Where-Object DistinguishedName -like $OUToExclude) {
        $Row = "" | Select-Object OU, Name
        $Row.OU = ($Computer.DistinguishedName).Replace("CN=$($Computer.Name),", "")
        $Row.Name = $Computer.Name
        $Computers += $Row
    }
}
#Show number of computers outside the given OU
$Computers.Count
#Show each of the OUs that contain workstations outside of OU
$Computers.OU | Sort-Object -Unique