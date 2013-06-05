#  --- [Get-SystemUptime] PowerShell Script  ---
#
# Author(s):        Ryan Irujo
# Inception:        06.02.2013
# Last Modified:    06.05.2013
#
# Description:      Script that determines the length of time a Server has been up. This Script can be modified
#                   slightly to work within Orchestrator by removing the Initial Parameter check for the 
#                   $Computer variable and placing in values for both the $Username and $Password variables.
#                
#
#
# Changes:          06.03.2013 - [R. Irujo]
#                   - Wrapped the main part of the script in an Invoke-Command Cmdlet for use in Orchestrator.
#                   - Added Variables at the end of the Script that are returned to Orchestrator.
#                   - Additional Documentation added in Description section.
#
#		    06.05.2013 - [R. Irujo]
#		    - Added Error Checking so that Errors are exposed and stored in a variable called ReturnedErrors.
#		      Anything that is found is returned back to Orchestrator in the ErrorResults variable at the end
#		      of the script.
#
# Syntax:          ./Get-SystemUptime.ps1 <Remote_Server>
#
# Example:         ./Get-SystemUptime.ps1 SCOMServer101.scom.local

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
$Results = Invoke-Command -ComputerName $Computer -Credential $Creds -ErrorAction SilentlyContinue -ErrorVariable ReturnedErrors -ScriptBlock {

	# Getting LastBootUptime
	$LastBootUptime = (gwmi -Class Win32_OperatingSystem).LastBootUptime

	# Converting LastBootUptime into a usable Date Time format.
	$ConvertLastBootUptime = [System.Management.ManagementDateTimeConverter]::ToDateTime($LastBootUptime)

	# Calculating the Current Uptime of the Host.
	$CurrentUptime = New-TimeSpan -Start $ConvertLastBootUptime -end (Get-Date)

	# Formatting the Current Uptime of the Host into Minutes.
	$CurrentUptimeMinutes = $CurrentUptime.TotalMinutes.ToString("0.00")
	
	
	    # Adding returned values into a PowerShell Property values to pass them later to Orchestrator.
		New-Object PSObject -Property @{
			CurrentUptimeMinutes = $CurrentUptimeMinutes
			}
		}


# Final Results are passed to the PowerShell Console		
echo "Current Uptime (Minutes): $($($Results).CurrentUptimeMinutes)"

#Any Error Messages are passed back to the PowerShell Console.
echo "Returned Errors: $($($ReturnedErrors).ErrorDetails)"

# Final Results are passed to Orchestrator
$CurrentUptimeMinutes = $Results.CurrentUptimeMinutes
$ErrorResults         = echo "$($($ReturnedErrors).ErrorDetails)"

