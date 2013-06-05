#  --- [Get-PendingReboot] PowerShell Script  ---
#
# Original Author:  Brian Wilhite
# Author(s):        Ryan Irujo
# Inception:        05.30.2013
# Last Modified:    06.05.2013
#
# Description:      Script that determines if a Server is in a Pending Reboot State. This script is a modified version of Brian Wilhite's script
#                   which can be found at the link below:
#                
#                   http://gallery.technet.microsoft.com/scriptcenter/Get-PendingReboot-Query-bdb79542
#
#
#                   This Script has been purposely modified to work with Orchestrator 2012.
#
#
# Changes:          05.31.2013 - [R. Irujo]
#                   - Removed comments and retooled the order in which the checks are completed.
#                   - Wrappe the main part of the script in an Invoke-Command Cmdlet for use in Orchestrator.
#                   - Added Variables at the end of the Script that are returned to Orchestrator.
#
#		    06.05.2013 - [R. Irujo]
#		    - Added Error Checking so that Errors are exposed and stored in a variable called ReturnedErrors.
#		      Anything that is found is returned back to Orchestrator in the ErrorResults variable at the end
#		      of the script.
#
#
# Syntax:          ./Get-PendingReboot.ps1 <Remote_Server>
#
# Example:         ./Get-PendingReboot.ps1 SCOMServer101.scom.local

param($Computer)

# Checking to make sure the Parameter Values are not Null or blank.
if (($Computer -eq $null) -or ($Computer -eq ""))
  {
	echo "A Computer Name (NetBIOS or FQDN) must be provided."
	exit 1
	}
	
# Storing Credentials to connect via Windows RM on Remote Host.
$Username = "<USERNAME>"
$Password = "<PASSWORD>" | ConvertTo-SecureString -AsPlainText -Force
$Creds    = New-Object System.Management.Automation.PSCredential($Username,$Password)


# Returned Values from the Remote Host are stored in the $Results Variable.
$Results  = Invoke-Command -ComputerName $Computer -Credential $Creds -ErrorAction SilentlyContinue -ErrorVariable ReturnedErrors -ScriptBlock {

	# Adjusting ErrorActionPreference to stop on all errors, since using [Microsoft.Win32.RegistryKey]
	# does not have a native ErrorAction Parameter
	$TempErrAct            = $ErrorActionPreference
	$ErrorActionPreference = "Stop"
	
	# Retrieving the Name of the Machine via WMI to use within the rest of the WMI and Registry Calls
	# below in the Script.
	$Computer = (gwmi -Class Win32_OperatingSystem).CSName

	# Querying WMI for build version
	$WMI_OS = gwmi -Class Win32_OperatingSystem -ComputerName $Computer -Property BuildNumber, CSName 

	# Determine SCCM 2012 Client Reboot Pending Status
	# To avoid nested 'if' statements and unneeded WMI calls to determine if the CCM_ClientUtilities class exist, setting EA = 0
	$CCMClientSDK = $null

	$CCMSplat = @{
		NameSpace    = 'ROOT\ccm\ClientSDK'
		Class        = 'CCM_ClientUtilities'
	    Name         = 'DetermineIfRebootPending'
		ComputerName = $Computer
		ErrorAction  = 'SilentlyContinue'
		}

	$CCMClientSDK = Invoke-WmiMethod @CCMSplat

	If ($CCMClientSDK)
		{
		If ($CCMClientSDK.ReturnValue -ne 0)
			{
			Write-Warning "Error: DetermineIfRebootPending returned error code $($CCMClientSDK.ReturnValue)"
			If ($CCMClientSDK.IsHardRebootPending -or $CCMClientSDK.RebootPending)
				{
				$SCCM = $true
				}
			}
			Else
				{
				$SCCM = $false
				}
			}
		Else
		{
		$SCCM = $null
		}

	# Making registry connection to the local/remote computer
	$RegCon = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]"LocalMachine",$Computer)


	# If Vista/2008 & Above query the CBS Reg Key
	If ($WMI_OS.BuildNumber -ge 6001)
		{
		$RegSubKeysCBS = $RegCon.OpenSubKey("SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\").GetSubKeyNames()
		$CBSRebootPend = $RegSubKeysCBS -contains "RebootPending"
		If ($CBSRebootPend)
			{
			$CBS = $true
			}
		Else
			{
			$CBS = $false
			}
		}

	# Query WUAU from the registry
	$RegWUAU          = $RegCon.OpenSubKey("SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\")
	$RegWUAURebootReq = $RegWUAU.GetSubKeyNames()
	$WUAURebootReq    = $RegWUAURebootReq -contains "RebootRequired"
		If ($WUAURebootReq)
			{
			$WUAU = $true
			}
		Else
			{
			$WUAU = $false
			}

	# Query PendingFileRenameOperations from the registry
	$RegSubKeySM      = $RegCon.OpenSubKey("SYSTEM\CurrentControlSet\Control\Session Manager\")
	$RegValuePFRO     = $RegSubKeySM.GetValue("PendingFileRenameOperations",$null)
		If ($RegValuePFRO)
			{
			$PendFileRename = $true
			}
		Else
			{
			$PendFileRename = $false
			}

	# Closing registry connection
	$RegCon.Close()


	# If Component Based Servicing, Windows Update, SCCM, or PendingFileRenameOperations are found to be True,
	# then the RebootPending Value is set to True. Otherwise, the RebootPending Value is set to False.
	If ($CBS -or $WUAU -or $SCCM -or $PendFileRename) 
		{
		$Pending = $true
		}
	Else
		{
		$Pending = $false
		}


	New-Object PSObject -Property @{
		Computer       = $WMI_OS.CSName
		CBServicing    = $CBS
		WindowsUpdate  = $WUAU
		CCMClientSDK   = $SCCM
		PendFileRename = $PendFileRename
		RebootPending  = $Pending
		}		
	}

# Returning Results Back to PowerShell Console.
echo "Computer Name: $($($Results).Computer)"
echo "CCMClientSDK:  $($($Results).CCMClientSDK)"
echo "Component Based Servicing: $($($Results).CBServicing)"
echo "Windows Update: $($($Results).WindowsUpdate)"
echo "PendingFileRenameOperations: $($($Results).PendFileRename)"
echo "Reboot Pending: $($($Results).RebootPending)"

#Any Error Messages are passed back to the PowerShell Console.
echo "Returned Errors: $($($ReturnedErrors).ErrorDetails)"

# Returning Results Back to Orchestrator.
$ComputerName              = $Results.Computer
$CCMClientSDK              = $Results.CCMClientSDK
$ComponentBasedServicing   = $Results.CBServicing
$WindowsUpdate             = $Results.WindowsUpdate
$PendingFileRenameOptions  = $Results.PendFileRename
$RebootPending             = $Results.RebootPending
$ErrorResults              = echo "$($($ReturnedErrors).ErrorDetails)"

