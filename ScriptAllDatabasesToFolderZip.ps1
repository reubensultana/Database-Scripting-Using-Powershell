param([String]$ServerName='localhost', 				 # the server it is on
	  [String]$DirectoryToSaveTo='C:\MSSQL\SCRIPTS', # the directory where you want to store them
      [int]$FileAgeHours=768)                        # the maximum age for file retention (default 32 days)

# Based on: http://www.simple-talk.com/sql/database-administration/automated-script-generation-with-powershell-and-smo/
# Usage: .\ScriptAllDatabasesToFolderZip.ps1 -ServerName "localhost" -DirectoryToSaveTo "C:\MSSQL\SCRIPTS" -FileAgeHours 768

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

Write-Host "Scripting databases from SQL Server instance '$ServerName'"
Write-Host "------------------------------------------------------------"
[bool] $fileExists = $false
[String] $CurrentLocation = $MyInvocation.MyCommand.Path
$DirOnly = Split-Path $CurrentLocation

# temporarily change to the correct folder
Push-Location $DirOnly

# check if 7-zip command line program exists in current folder
if (-not (Test-Path "./7za.exe")) {Throw "7za.exe is needed"}

# remove ZIP files older than $FileAgeHours days (default 32 days OR 768 hours)
$fileExists = Test-Path $DirectoryToSaveTo\$ServerName
If ($fileExists -eq $true) {
    ./DeleteFilesOlderThan.ps1 -FolderName $DirectoryToSaveTo\$ServerName -FileFilter "*.ZIP" -FileAgeHours $FileAgeHours
}

# remove previous output
$fileExists = Test-Path $DirectoryToSaveTo\_TEMP\$ServerName
If ($fileExists -eq $true) {
    Remove-Item -Path $DirectoryToSaveTo\_TEMP\$ServerName -Recurse -Force
}

$dbs = $srv.Databases
foreach ($db in $dbs)
	{
	$Database = $db.Name
	if(($Database -NotIn ("db_dba", "master", "model", "msdb", "tempdb")) -and ($Database -NotLike "ReportServer*") -and ($Database -NotLike "AdventureWorks*")) #We don't want to script system databases
		{
		# script database
		.\ScriptDatabaseToFolders.ps1 -ServerName $ServerName -Database $Database -DirectoryToSaveTo $DirectoryToSaveTo\_TEMP
		
		# create a timestamp for the file name
		$DateStamp = Get-Date -uformat "%Y%m%d%H%M%S"
		# zip scripted database output
		#.\CompressFolderToFile.ps1 -CompressFolder $DirectoryToSaveTo\_TEMP\$ServerName\$Database -BackupFolder $DirectoryToSaveTo\$ServerName\$Database -ZipFileName "$($Database)_$($DateStamp).zip"

        # Using the command-line version of 7-ZIP
		./7za.exe a -tzip "$DirectoryToSaveTo\$ServerName\$Database\$($Database)_$($DateStamp).zip" "$DirectoryToSaveTo\_TEMP\$ServerName\$Database" 
    }
}
# now back to previous directory
Pop-Location
# remove previous output
$fileExists = Test-Path $DirectoryToSaveTo\_TEMP\$ServerName
If ($fileExists -eq $true) {
    Remove-Item -Path $DirectoryToSaveTo\_TEMP\$ServerName -Recurse -Force -Verbose:$true
}
Write-Host ""
Write-Host "Script generation complete"
EXIT
