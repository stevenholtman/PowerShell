<#
.Notes
    Developed by Steven Holtman in Powershell
    Website: https://StevenHoltman.com
    Get the latest scripts at https://github.com/stevenholtman

.Synopsis
    Retrieves all the groups the employee is a part of in Active Directory

.DESCRIPTION
   Requests the Active Directory username for the employee you want to get its Active Directory groups they are a part of. 
   
.EXAMPLE
   Get-EmployeeADGroups -Username User.Name
#>
function Get-EmployeeADGroups {
    [CmdletBinding(SupportsShouldProcess = $True)]
    param (
        #Requests the username
        [Parameter(Mandatory = $true)]
        [string]$Username
    )
    Begin {
        #Returning the full name from the username
        $FullName = (Get-ADUser $Username).Name
    }    

    Process {
        #Requesting the groups for the username specified
        $EmployeeADUser = Get-ADPrincipalGroupMembership $username -ErrorAction SilentlyContinue
    }

    End {
        Try {
            $Results = $EmployeeADUser | Select-Object @{l = "Groups for $FullName"; e = { $_.Name } }
            Write-Output $Results
        }

        Catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
            "Not able to locate $Username, please check the spelling and try again"
        }
    }
}