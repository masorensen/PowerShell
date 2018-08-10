function Connect-MySQL([string]$user, [string]$pass, [string]$MySQLHost, [string]$database) { 
    # Load MySQL .NET Connector Objects 
    [void][system.reflection.Assembly]::LoadWithPartialName("MySql.Data") 
 
    # Open Connection 
    $connStr = "server=" + $MySQLHost + ";port=3306;uid=" + $user + ";pwd=" + $pass + ";database="+$database+";Pooling=FALSE" 
    try {
        $conn = New-Object MySql.Data.MySqlClient.MySqlConnection($connStr) 
        $conn.Open()
    } catch [System.Management.Automation.PSArgumentException] {
        #Log "Unable to connect to MySQL server, do you have the MySQL connector installed..?"
        #Log $_
        Exit
    } catch {
        #Log "Unable to connect to MySQL server..."
        #Log $_.Exception.GetType().FullName
        #Log $_.Exception.Message
        exit
    }
    #Log "Connected to MySQL database $MySQLHost\$database"
 
    return $conn 
}

function Send-Mail
	(#Define function parameters
	[Parameter(Position=0,Mandatory=$true)]
		[Alias("out")]
		[string]$TotalContent

    )

{
   #SMTP server name
     $smtpServer = "mailhost.fhcloud.local"

     #Creating a Mail object
     $msg = new-object Net.Mail.MailMessage

     #Creating SMTP server object
     $smtp = new-object Net.Mail.SmtpClient($smtpServer)

     #Email structure 
     $msg.From = "psreports@fhcloud.com"
     $msg.ReplyTo = "noreply@fhcloud.com"
     $msg.To.Add("mike.sorensen@xerox.com")
     $msg.To.Add("Christopher.Darville@xerox.com")

     $msg.subject = "FHNET Concurrent Usage Report Demo (November)"
     $msg.body = $TotalContent

     #Sending email 
     $smtp.Send($msg) 
}




function Execute-MySQLQuery([string]$query) { 
  # NonQuery - Insert/Update/Delete query where no return data is required
  $cmd = New-Object MySql.Data.MySqlClient.MySqlCommand($query, $connMySQL)    # Create SQL command
  $dataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($cmd)      # Create data adapter from query command
  $dataSet = New-Object System.Data.DataSet                                    # Create dataset
  $dataAdapter.Fill($dataSet, "data")                                          # Fill dataset from data adapter, with name "data"              
  $cmd.Dispose()
  return $dataSet.Tables["data"]                                               # Returns an array of results
}

# Connection Variables 
$user = 'root' 
$pass = 'Thesbi3on' 
$database = 'logontrack' 
$MySQLHost = 'localhost' 
 
# Connect to MySQL Database 
$connMySQL = Connect-MySQL $user $pass $MySQLHost $database


$query = "SELECT org_unit as Department,COUNT(*) as UserCount FROM logon_events WHERE login_time > DATE_SUB(NOW(), INTERVAL 1 MONTH) GROUP BY Department ORDER BY UserCount DESC;"
$result = Execute-MySQLQuery $query
$result = $result[1..($result.Length-1)]
$TotalOutput = $result | Format-Table -AutoSize


$i = 1
$StartTime = "00:00:00"
$EndTime = "01:00:00"
$HourOutput = @()

DO
{
    $query = "SELECT org_unit as Department,COUNT(*) as UserCount FROM logon_events WHERE HOUR(login_time) between '$StartTime' and '$EndTime' GROUP BY Department ORDER BY UserCount DESC;"
    $result = Execute-MySQLQuery $query
    $result = $result[1..($result.Length-1)]
    $HourOutput += "FHNET Logins by Department from $StartTime to $EndTime for the Month of November:"
    $HourOutput += $result | Format-Table -AutoSize 
    $StartTime = (Get-Date $StartTime).AddHours(1)
    $StartTime = Get-Date $StartTime -Format 'HH:mm:ss'
    $EndTime = (Get-Date $EndTime).AddHours(1)
    $EndTime = Get-Date $EndTime -Format 'HH:mm:ss'
    $i++

}until ($i -eq 25)

$Test = $TotalOutput + $HourOutput
$Test = $Test | Out-String

Send-Mail -TotalContent $Test