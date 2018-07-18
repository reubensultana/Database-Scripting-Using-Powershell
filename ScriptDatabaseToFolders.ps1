param([String]$ServerName='localhost', 				 # the server it is on
	  [String]$Database='AdventureWorks2008R2', 	 # the name of the database you want to script as objects
	  [String]$DirectoryToSaveTo='C:\MSSQL\SCRIPTS') # the directory where you want to store them

# Based on: http://www.simple-talk.com/sql/database-administration/automated-script-generation-with-powershell-and-smo/
# Usage: .\ScriptDatabaseToFolders.ps1 -ServerName "localhost" -Database "AdventureWorksLT2008R2" -DirectoryToSaveTo "C:\MSSQL\SCRIPTS"

"Scripting"
"  Servername:       '$ServerName'"
"  Database Name:    '$Database' "
"  Scripts location: '$DirectoryToSaveTo'"

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
[bool] $fileExists = $false
# remove previous output
$fileExists = Test-Path $DirectoryToSaveTo\$ServerName\$Database
If ($fileExists -eq $true) {
    Remove-Item -Path $DirectoryToSaveTo\$ServerName\$Database -Recurse -Force
}
$scripter = new-object ("$My.Scripter") $srv # create the scripter
$scripter.Options.DRIAll = $false # primary and foreign keys, default and check constraints
$scripter.Options.ExtendedProperties= $true
$scripter.Options.FullTextCatalogs=$true
$scripter.Options.FullTextIndexes=$true
$scripter.Options.IncludeDatabaseContext = $true
$scripter.Options.IncludeHeaders = $false # of course
$scripter.Options.IncludeIfNotExists = $true # not necessary but it means the script can be more versatile
$scripter.Options.Indexes = $true # Yup, these would be nice
$scripter.Options.NoCollation = $true # specifies whether to include the collation clause in the generated script
$scripter.Options.NoAssemblies = $false # specifies whether assemblies are included in the generated script
$scripter.Options.Permissions = $false
$scripter.Options.SchemaQualify = $true
$scripter.Options.ScriptBatchTerminator = $true # this only goes to the file
$scripter.Options.ScriptData = $false
$scripter.Options.ScriptDrops = $false
$scripter.Options.ScriptOwner = $true
$scripter.Options.ScriptSchema = $true
$scripter.Options.Triggers = $true # This should be included when scripting a database
$scripter.Options.ToFileOnly = $true
# we now get all the object types except extended stored procedures
# first we get the bitmap of all the object types we want
$all =[long] [Microsoft.SqlServer.Management.Smo.DatabaseObjectTypes]::all `
    -bxor [Microsoft.SqlServer.Management.Smo.DatabaseObjectTypes]::ExtendedStoredProcedure
# and we store them in a datatable
$d = new-object System.Data.Datatable
# get everything except the servicebroker objects, the information schema and system views
$d=$srv.databases[$Database].EnumObjects([long]0x1FFFFFFF -band $all) | `
	Where-Object {($_.Schema -NotIn ("sys", "INFORMATION_SCHEMA")) -and ($_.DatabaseObjectTypes -NotIn ("AsymmetricKey", "Certificate", "DatabaseRole", "MessageType", "ServiceBroker", "ServiceContract", "ServiceQueue", "ServiceRoute", "SymmetricKey", "User"))} | `
	Where-Object {($_.Name -NotIn ("dbo", "guest", "INFORMATION_SCHEMA", "sys", "Microsoft-SqlServer-Types", "db_owner", "db_accessadmin", "db_securityadmin", "db_ddladmin", "db_backupoperator", "db_datareader", "db_datawriter", "db_denydatareader", "db_denydatawriter", "sp_helpdiagrams", "sp_helpdiagramdefinition", "sp_creatediagram", "sp_renamediagram", "sp_alterdiagram", "sp_dropdiagram", "sp_upgraddiagrams", "fn_diagramobjects", "sysdiagrams"))}
# and write out each scriptable object as a file in the directory you specify
$d| ForEach-Object { # for every object we have in the datatable.
   $SavePath="$($DirectoryToSaveTo)\$($ServerName)\$($Database)\$($_.DatabaseObjectTypes)\$($_.Schema)"
   # create the directory if necessary (SMO doesn't).
   if (!( Test-Path -path $SavePath )) # create it if not existing
        {Try { New-Item $SavePath -type directory | out-null }
			Catch [system.exception]{
				Write-Error "Error while creating '$SavePath' $_"
				return
			 }
		}
    # tell the scripter object where to write it
    $scripter.Options.Filename = "$SavePath\$($_.Name -replace '[\\\/\:\.]','-').sql";
    # Create a single element URN array
    $UrnCollection = new-object ('Microsoft.SqlServer.Management.Smo.urnCollection')
    $URNCollection.add($_.urn)
    # and write out the object to the specified file
"  Writing object:   $($_.Name -replace '[\\\/\:\.]','-')"
    $scripter.script($URNCollection)
}
""
"Script generation complete"
RETURN
