param([String]$ServerName='localhost', 				 # the server it is on
	  [String]$DirectoryToSaveTo='C:\MSSQL\SCRIPTS') # the directory where you want to store them

# Based on: http://www.simple-talk.com/sql/database-administration/automated-script-generation-with-powershell-and-smo/
# Usage: .\ScriptAllDatabasesToFile.ps1 -ServerName "localhost" -DirectoryToSaveTo "C:\MSSQL\SCRIPTS"

# Load SMO assembly, and if we're running SQL 2008 DLLs load the SMOExtended and SQLWMIManagement libraries
$v = [System.Reflection.Assembly]::LoadWithPartialName( 'Microsoft.SqlServer.SMO')
if ((($v.FullName.Split(','))[1].Split('='))[1].Split('.')[0] -ne '9') {
    [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMOExtended') | out-null
}
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SmoEnum') | out-null
set-psdebug -strict # catch a few extra bugs
$ErrorActionPreference = "stop"
$My='Microsoft.SqlServer.Management.Smo'
$srv = new-object ("$My.Server") $ServerName # attach to the server
if ($srv.ServerType-eq $null) # if it managed to find a server
   {
   Write-Error "Sorry, but I couldn't find Server '$ServerName' "
   return
}

"Scripting databases from SQL Server instance '$ServerName'"
"------------------------------------------------------------"

$dbs = $srv.Databases
foreach ($db in $dbs)
	{
	$Database = $db.Name
	if($Database -NotIn ("db_dba", "master", "model", "msdb", "tempdb")) #We don't want to script system databases
		{
		.\ScriptDatabaseToFolders.ps1 -ServerName $ServerName -Database $Database -DirectoryToSaveTo $DirectoryToSaveTo
	}
}
""
"Script generation complete"
RETURN
