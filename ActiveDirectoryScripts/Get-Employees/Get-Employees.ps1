<#
.Notes
    Developed by Steven Holtman in Powershell
    Website: https://StevenHoltman.com
    Get the latest scripts at https://github.com/stevenholtman

.Synopsis
    Exports the Employees out of Active Directory into a CSV File

.DESCRIPTION
    This uses Get-ADUser to export Employees Full Name, Email Address, Username, and Location, exporting it to a CSV File with realavent Headers

.EXAMPLE
    Get-Employees
#>
function Get-Employees {

    # Setting report location and filename
    $ReportLocation = "$Env:USERPROFILE\Reports"
    $ReportFile = "$ReportLocation\Employee Accounts.csv"

    # Checking if the report path exists, if it doesnt it creates it
    try {
        $TestReportLocation = Test-Path $ReportLocation
        if (!$TestReportLocation) {
            new-item $ReportLocation -ItemType Directory -force
        }
    }
    catch {  
        Write-Error "Failed to create the folder $($_.Exception.Message)"
        exit 1
    }

    # Sets Get-ADUser Filters to Employee Account Must Be Enabled
    $EmployeeFilters = { Enabled -eq $true }

    # Sets Get-ADUser Properties for just Name, Email, Username and Organizational (I do this for quicker query result)
    $EmployeeProperties = "Name", "SamAccountName", "EmailAddress", "DistinguishedName"

    # Sets the what Orginizational Unit to begin searching 
    $OU = "OU=Users,OU=MyBusiness,DC=YOURDOMAIN,DC=local" # Update this to your Orginizations Structure, this follows the SBS for Users

    # Sets exactly what fields to export, and what the header name should be
    $EmployeeObjects = @{l = 'Employee Name'; e = { $_.Name } }, `
    @{l = 'Username'; e = { $_.SamAccountName } }, `
    @{l = 'Email Address'; e = { $_.EmailAddress } }, `
    @{l = 'Location'; e = { $_.DistinguishedName.split(',')[1].split('=')[1] } }

    # Making the request to get Employees out of Active Directory and Export the Results
    Get-ADUser -Filter $EmployeeFilters -SearchBase $OU -Properties $EmployeeProperties | Select-Object $EmployeeObjects | Export-CSV $ReportFile -NoTypeInformation
    Invoke-Item $ReportFile
}