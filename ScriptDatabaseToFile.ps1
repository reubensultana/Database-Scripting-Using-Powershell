param([String]$ServerName,        # the server it is on
	  [String]$Database,          # the name of the database you want to script as objects
	  [String]$DirectoryToSaveTo) # the directory where you want to store them


function Script-DatabaseToFile {
    param(
        [Parameter(Position=0, Mandatory=$true)]  [string]$ServerName,        # the server it is on
	    [Parameter(Position=1, Mandatory=$true)]  [string]$Database,          # the name of the database you want to script as objects
	    [Parameter(Position=2, Mandatory=$true)]  [string]$DirectoryToSaveTo) # the directory where you want to store them

    # Based on: http://www.simple-talk.com/sql/database-administration/automated-script-generation-with-powershell-and-smo/
    # Usage: .\ScriptDatabaseToFile.ps1 -ServerName "localhost" -Database "AdventureWorksLT2008R2" -DirectoryToSaveTo "C:\MSSQL\SCRIPTS"

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
    $db= $srv.Databases[$Database]
    if ($db.name -ne $Database){Throw "Can't find the database '$Database' in $ServerName"};
    # write out each scriptable object to a single file in the directory you specify
    $SavePath="$($DirectoryToSaveTo)\$($ServerName)\$($Database)"
    # create the directory if necessary (SMO doesn't).
    if (!( Test-Path -path $SavePath )) # create it if not existing
	    {Try { New-Item $SavePath -type directory | out-null }
		    Catch [system.exception]{
			    Write-Error "Error while creating '$SavePath' $_"
			    return
		     }
	    }
    # create a timestamp for the file name
    $DateStamp = get-date -uformat "%Y%m%d%H%M%S"
    # set scripting options
    $transfer = new-object ("$My.Transfer") $db
    # start script options - see "https://msdn.microsoft.com/en-us/library/microsoft.sqlserver.management.smo.scriptingoptions.aspx" for details
    $CreationScriptOptions = new-object ("$My.ScriptingOptions")
    $CreationScriptOptions.AppendToFile = $true
    $CreationScriptOptions.DRIAll = $true # primary and foreign keys, default and check constraints
    $CreationScriptOptions.ExtendedProperties = $false # yes, we want these
    $CreationScriptOptions.Filename = "$($SavePath)\$($ServerName.Replace("\", "$"))_$($Database)_$($DateStamp).sql"
    $CreationScriptOptions.FullTextCatalogs = $true
    $CreationScriptOptions.FullTextIndexes = $true
    $CreationScriptOptions.IncludeDatabaseContext = $true
    $CreationScriptOptions.IncludeDatabaseRoleMemberships = $true # of course
    $CreationScriptOptions.IncludeHeaders = $false # of course
    $CreationScriptOptions.IncludeIfNotExists = $false # not necessary but it means the script can be more versatile
    $CreationScriptOptions.Indexes = $true # Yup, these would be nice
    $CreationScriptOptions.NoCollation = $true # specifies whether to include the collation clause in the generated script
    $CreationScriptOptions.NoAssemblies = $false # specifies whether assemblies are included in the generated script
    $CreationScriptOptions.Permissions = $false # of course
    $CreationScriptOptions.SchemaQualify = $true
    $CreationScriptOptions.ScriptBatchTerminator = $true # this only goes to the file
    $CreationScriptOptions.ScriptData = $false
    $CreationScriptOptions.ScriptDrops = $false
    $CreationScriptOptions.ScriptOwner = $true
    $CreationScriptOptions.ScriptSchema = $true
    $CreationScriptOptions.ToFileOnly = $true #no need of string output as well
    $CreationScriptOptions.Triggers = $true # This should be included when scripting a database
    # end script options
    $transfer = new-object ("$My.Transfer") $srv.Databases[$Database]
    $transfer.options=$CreationScriptOptions # tell the transfer object of our preferences
    $scripter = new-object ("$My.Scripter") $srv # script out the database creation
    $scripter.options=$CreationScriptOptions # with the same options
    $scripter.Script($srv.Databases[$Database]) # do it
    # start writing to the file
    "USE $Database" | Out-File -Append -FilePath $CreationScriptOptions.Filename #"$($SavePath)\$($Database)_$($DateStamp).sql"
    "GO" | Out-File -Append -FilePath $CreationScriptOptions.Filename #"$($SavePath)\$($Database)_$($DateStamp).sql"
    # add the database object build script
    $transfer.ScriptTransfer()
    ""
    "Script generation complete"
    RETURN
}


Clear-Host
# run this only if the parameters have been passed to the script
# interface implemented to be called from Windows Task Scheduler or similar applications
if (($ServerName -ne '') -and ($Database -ne '') -and ($DirectoryToSaveTo -ne '')) {
    Script-DatabaseToFile -ServerName $ServerName -Database $Database -DirectoryToSaveTo $DirectoryToSaveTo
}
# otherwise, do nothing
