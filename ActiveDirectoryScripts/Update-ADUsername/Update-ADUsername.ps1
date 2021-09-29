<#
.NOTES
    Developed by Steven Holtman in Powershell
    Website: https://StevenHoltman.com
    Get the latest scripts at https://github.com/stevenholtman

.Synopsis
    Quick method to update an employees username and email fields in Active Directory

.DESCRIPTION
    This will search Active Directory for the employees name specified and update their username to first.last formate, update their email field to ensure it is also first.last@domain.com

.EXAMPLE
    Update-ADUsername "Steven Holtman" "steven.holtman"

.NOTES
    You can use the Get-Employees PowerShell script I created to get the Employee's names
#>
function Update-ADUsername {
    [CmdletBinding(
        SupportsShouldProcess = $True
    )]
    Param
    (
        [parameter(
            Position = 0, 
            Mandatory = $true, 
            ValueFromPipeline = $true
        )]
        [string]$EmployeeName,

        [parameter(
            Position = 1, 
            Mandatory = $true, 
            ValueFromPipeline = $true
        )]
        [string]$NewUsername
    )

    Begin {
        $Date = Get-Date
        $LogPath = "$ENV:UserProfile\"
        $LogName = "Updated-ADUsername.log"
        $LogFile = $LogPath + $LogName
        [string]$UPN = '@YOURDOMAIN.local' # Update this with your Domain Name
        [string]$OrginizationalUnit = "OU=Users,OU=MyBusiness,DC=YOURDOMAIN,DC=local" # Update this to your Orginizations Structure, this follows the SBS for Users
        [string]$FinalUPN = $NewUsername + $UPN
        [string]$EmailDomain = '@YOURWEBSITEDOMAIN.com' # Change this to your Website's Domain Name
        [string]$EmailAddress = $NewUsername + $EmailDomain

    }    
    Process {
        Foreach ($Employee in $EmployeeName) {
            $OldUsername = (Get-ADuser -Filter 'Name -like $Employee' -SearchBase "$OrginizationalUnit").SamAccountName
            $OldEmailAddress = (Get-ADuser -Properties * -Filter 'Name -like $Employee' -SearchBase "$OrginizationalUnit").EmailAddress
            $EmployeeAccount = Get-ADuser -Filter 'Name -like $Employee' -SearchBase ("$OrginizationalUnit")
            if ($EmployeeAccount.Enabled -eq $True) { 
                $ErrorActionPreference = 'SilentlyContinue'

                # Attempting to update employees account with the correct username and email address attributes            
                Try {
                    Set-ADUser $EmployeeAccount -UserPrincipalName $FinalUPN.ToLower()  -SamAccountName $NewUsername.ToLower()  -emailaddress $EmailAddress.ToLower()
                    Write-Output "Employees username has been updated to $($NewUsername) and Email has been updated to $EmailAddress"
                    $SucessResults = Write-Output "Employee Name: $EmployeeName "`r`n" Date of Changes: $Date "`r`n" Existing Username: $OldUsername "`r`n" Existing Email: $OldEmailAddress "`r`n" New Username: $($NewUsername) "`r`n" New Email: $EmailAddress "`r`n""
                    $SucessResults | Out-File -FilePath "$Logfile" -Append 
                    Write-Verbose "$SucessResults"
                }
                                
                # Writing any failures
                Catch {
                    Write-Warning "FAILED to update the username to $($NewUsername) and email to $EmailAddress for $EmployeeName"
                    $FailedResults = Write-Output "$Date FAILED to update the username to $($NewUsername) and email to $EmailAddress for $EmployeeName"
                    $FailedResults | Out-File -FilePath "$Logfile" -Append 
                    Write-Verbose "$FailedResults"
                }
            }
        }
    }
}