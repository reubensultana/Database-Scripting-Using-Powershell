param([String]$FolderName='C:\MSSQL\SCRIPTS', # the directory storing the files
	  [String]$FileFilter='*.TXT', # a filter for the files being deleted
	  [Int]$FileAgeHours=24) # the maximum age for file retention

# Usage: .\DeleteFilesOlderThan.ps1 -FolderName "C:\MSSQL\SCRIPTS" -FileFilter "*.TXT" -FileAgeHours 24

$RetentionDate= (Get-Date).AddHours(-$FileAgeHours)

Get-ChildItem (Join-Path $FolderName $FileFilter) -Recurse |? {($_.PSIsContainer -eq $false) -and ($_.LastWriteTime -lt $RetentionDate)} | Remove-Item -Verbose:$true
RETURN
