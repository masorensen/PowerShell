﻿# Configuration data 
[string] $server   = ".\";        # SQL Server Instance. 
[string] $database = "ReportServer_WVSouthBerkely";        # ReportServer Database. 
[string] $folder   = "C:\ReportExport_WV_SouthBerkely";          # Path to export the reports to. 
 
# Select-Statement for file name & blob data with filter. 
$sql = "SELECT CT.[Path] 
              ,CT.[Type] 
              ,CONVERT(varbinary(max), CT.[Content]) AS BinaryContent 
        FROM dbo.[Catalog] AS CT 
        WHERE CT.[Type] IN (2, 3, 5)"; 
 
# Open ADO.NET Connection with Windows authentification. 
$con = New-Object Data.SqlClient.SqlConnection; 
$con.ConnectionString = "Data Source=$server;Initial Catalog=$database;Integrated Security=True;"; 
$con.Open(); 
 
Write-Output ((Get-Date -format yyyy-MM-dd-HH:mm:ss) + ": Started ..."); 
 
# New command and reader. 
$cmd = New-Object Data.SqlClient.SqlCommand $sql, $con; 
$rd = $cmd.ExecuteReader(); 
 
$invalids = [System.IO.Path]::GetInvalidFileNameChars(); 
# Looping through all selected datasets. 
While ($rd.Read()) 
{ 
    Try 
    { 
        # Get the name and make it valid. 
        $name = $rd.GetString(0); 
        foreach ($invalid in $invalids) 
           {    $name = $name.Replace($invalid, "-");    } 
 
        If ($rd.GetInt32(1) -eq 2) 
            {    $name = $name + ".rdl";    } 
        ElseIf ($rd.GetInt32(1) -eq 5) 
            {    $name = $name + ".rds";    } 
 
        Write-Output ((Get-Date -format yyyy-MM-dd-HH:mm:ss) + ": Exporting {0}" -f $name); 
 
        $name = [System.IO.Path]::Combine($folder, $name); 
 
        # New BinaryWriter; existing file will be overwritten. 
        $fs = New-Object System.IO.FileStream ($name), Create, Write; 
        $bw = New-Object System.IO.BinaryWriter($fs); 
 
        # Read of complete Blob with GetSqlBinary 
        $bt = $rd.GetSqlBinary(2).Value; 
        $bw.Write($bt, 0, $bt.Length); 
        $bw.Flush(); 
        $bw.Close(); 
        $fs.Close(); 
    } 
    Catch 
    { 
        Write-Output ($_.Exception.Message) 
    } 
    Finally 
    { 
        $fs.Dispose(); 
    } 
} 
 
# Closing & Disposing all objects 
$rd.Close(); 
$cmd.Dispose(); 
$con.Close(); 
$con.Dispose(); 
 
Write-Output ((Get-Date -format yyyy-MM-dd-HH:mm:ss) + ": Finished");
