$CurrentMonth = Get-Date -Format MMMM
$DateRange = (Get-Date).AddMinutes(-60)
$EndDate = Get-Date
$DateRange.tostring("MM-dd-yyyy"), $env:Computername
function Get-LogonEvents

	(#Define function parameters
	[Parameter(Position=0,Mandatory=$true)]
		[Alias("server")]
		[string]$ServerName
    )
{
$EventTrack = @()
$Events = Get-WinEvent `
    -computerName $ServerName `
    -FilterHashtable @{LogName="Security";Id=4624; `
                       StartTime = $DateRange; EndTime = $EndDate}
ForEach ($Event in $Events){
$eventXML = [xml]$Event.ToXML()
$UserName = $eventXML.Event.EventData.Data[5].'#text'
$NewTime = $Event | Select-Object TimeCreated
if ($UserName -notlike "*$" -and $UserName -ne "OMAGENT" -and $UserName -notlike "fhnet*" -and $UserName -ne $OldUser -and $UserName -ne "SYSTEM")
{
    $OldUser = $UserName
    $Time = $Event | Select-Object TimeCreated
    $ADuser = Get-ADUser -identity $UserName -Properties *
    $OUCheck = $ADuser.CanonicalName.ToString().Split('/')[1]
    if($OUCheck -eq "OU_Fire")
    {
    $OU = $ADuser.CanonicalName.ToString().Split('/')[2]
    $row = "" | Select UserName, LoginTime, OrganizationalUnit, Server
    $Time = $Time.TimeCreated
    $Time = Get-Date $Time -Format 'yyyy-MM-dd HH:mm:ss'
    $row.UserName = $UserName
    $row.LoginTime = $Time
    $row.OrganizationalUnit = $OU
    $row.Server = $ServerName
    $EventTrack += $row
    #Write to db
    $query = "INSERT INTO logon_events (login_time,org_unit,server,usr_name) `
			VALUES('$Time','$OU','$ServerName','$UserName')"
    $Rows = WriteMySQLQuery $conn $query
    #$gpo_mod_tag = $false
    }
}
}

}




function ConnectMySQL([string]$user,[string]$pass,[string]$MySQLHost,[string]$database) {
	# Load MySQL .NET Connector Objects  
	[void][system.reflection.Assembly]::LoadFrom("C:\Program Files (x86)\MySQL\MySQL Connector Net 6.9.4\Assemblies\v2.0\MySQL.Data.dll")   
	# Open Connection  
	$connStr = "server=" + $MySQLHost + ";port=3306;uid=" + $user + ";pwd=" + $pass + ";database="+$database+";Pooling=FALSE"  
	$conn = New-Object MySql.Data.MySqlClient.MySqlConnection($connStr)  
	$conn.Open() 
	$cmd = New-Object MySql.Data.MySqlClient.MySqlCommand("USE $database", $conn)  
	return $conn 
}
 
function WriteMySQLQuery($conn, [string]$query) {6
	$command = $conn.CreateCommand()  
	$command.CommandText = $query  
	$RowsInserted = $command.ExecuteNonQuery()  
	$command.Dispose()  
	if ($RowsInserted) {    
		return $RowInserted  
	} 
	else {    
		return $false  
	}
}
# setup vars
$user = 'root'
$pass = 'Thesbi3on'
$database = 'logontrack'
$MySQLHost = 'localhost' #MySQL server IP address 
$conn = ConnectMySQL $user $pass $MySQLHost $database


#Write to db
#$query = "INSERT INTO logon_events (login_time,org_unit,server,usr_name) `#
#			VALUES('$Time','$OU','$ServerName','$UserName')"
#$Rows = WriteMySQLQuery $conn $query
#$gpo_mod_tag = $false
#$conn.close()


Get-LogonEvents -ServerName "fhnapp1"
Get-LogonEvents -ServerName "fhnapp2"
Get-LogonEvents -ServerName "fhnapp3"
Get-LogonEvents -ServerName "fhnapp4"
Get-LogonEvents -ServerName "fhnapp5"
Get-LogonEvents -ServerName "fhnapp6"
Get-LogonEvents -ServerName "fhnapp7"
Get-LogonEvents -ServerName "fhnapp8"
Get-LogonEvents -ServerName "fhnapp9"

    $conn.close()
