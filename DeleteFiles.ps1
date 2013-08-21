#  --- [DeleteFiles] PowerShell Script  ---
#
# Author(s):        Ryan Irujo
# Inception:        07.07.2013
# Last Modified:    07.07.2013
#
# Description:      Script that deletes files on a Host based upon Network Path. This script was designed
#                   to work with the Split Fields Activity in Orchestrator. The Computer and FilePath
#                   variables are parsed out by using a semi-colon as a delimiter.
#
#
# Changes:          
#
#
# Syntax:           ./DeleteFiles.ps1 <Remote_Server>
#
# Example:          ./DeleteFiles.ps1 SCOMServer101.scom.local C$\Temp\Files


# Field One and Two from Split Field Activity go here in their respective Variables.
$Computer = "<Split_Value_1>"
$FilePath = "<Split_Value_2>"

# Combining the $Computer and $FilePath Variables to create the Network Path to the Files to be removed.
$FullPath  = "\\$($Computer)\$($FilePath)"

# Storing Credentials to connect via Windows RM on Remote Host.	
$Username = "<Username>"
$Password = "<Password>" | ConvertTo-SecureString -AsPlainText -Force
$Creds    = New-Object System.Management.Automation.PSCredential($Username,$Password)


# Returned Values from the Remote Host are stored in the $Results Variable.
$Results = Invoke-Command -ComputerName $Computer -Credential $Creds -EA SilentlyContinue -EV ReturnedErrors -ArgumentList $FullPath,$Computer -ScriptBlock {

    # Making sure the Directory we are going to work with in exists.
    $Directory = [System.IO.Directory]::Exists($args[0])

    # If the Directory is not found, Script returns $DirectoryNotFound variable back to Orchestrator and Exits.
    If (!$Directory) 
		{
		    $DirectoryNotFound += echo "The Directory Path: '$($args[0])' was not found on $($args[1])"
	    }


	# Getting the list of Files in the Directory.
	$RemoteFiles = [System.IO.Directory]::GetFiles($args[0])
	
	
	# Adding the Filenames being deleted to the $DeletedFiles variable.
	ForEach ($File in $RemoteFiles) 
		{
			$DeletedFiles += echo "'$($File)'`n"
		}
	
	# Deleting the Files in the Remote Directory.
	ForEach ($File in $RemoteFiles) 
		{	
			[System.IO.File]::Delete($File)
		}


	# Adding returned values into a PowerShell Property values to pass them later to Orchestrator.
	New-Object PSObject -Property @{
		FullPath          = $args[0]
		Computer          = $args[1]
		DeletedFiles      = $DeletedFiles
        DirectoryNotFound = $DirectoryNotFound
		RemoteFilesCount  = $RemoteFiles.Count
		}
	}


# Final Results are passed to the PowerShell Console		
echo "The following Files have been deleted:`n$($DeletedFiles)"

#Any Error Messages are passed back to the PowerShell Console.
echo "Returned Errors: $($($ReturnedErrors).ErrorDetails)"


# Final Results are passed to Orchestrator
$ListOfDeletedFiles     = $Results.DeletedFiles
$DirectoryNotFound      = $Results.DirectoryNotFound
$ListRemoteFilesCount   = $Results.RemoteFilesCount
$ErrorResults           = echo "$($($ReturnedErrors).ErrorDetails)"

