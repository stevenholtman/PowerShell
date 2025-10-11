<#
.SYNOPSIS
    Scans folder permissions recursively and generates a grouped, color-coded HTML report.

.DESCRIPTION
    Collects NTFS permissions (including inheritance and explicit settings) and produces
    a visually grouped HTML report organized by folder path.
#>

# ---------------------------
# PREP
# ---------------------------
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'SilentlyContinue'
$results = @()
$skipped = @()
$username = $env:Username
$fullName = (Get-LocalUser -Name $username -ErrorAction SilentlyContinue).FullName
if (-not $fullName) { $fullName = $username }

# ---------------------------
# PROMPT FOR ROOT FOLDER
# ---------------------------
$folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
$folderBrowser.Description = "Select the root folder to scan for permissions"
$folderBrowser.ShowNewFolderButton = $false

if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    $RootPath = $folderBrowser.SelectedPath
} else {
    Write-Host "Operation cancelled by user." -ForegroundColor Yellow
    exit
}

# ---------------------------
# PROMPT FOR SAVE LOCATION
# ---------------------------
$saveDialog = New-Object System.Windows.Forms.SaveFileDialog
$saveDialog.Title = "Save HTML Report As"
$saveDialog.Filter = "HTML Files (*.html)|*.html"
$saveDialog.FileName = "FolderPermissionsReport.html"

if ($saveDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    $OutputPath = $saveDialog.FileName
} else {
    Write-Host "Operation cancelled by user." -ForegroundColor Yellow
    exit
}

# Ensure output directory exists
$dir = Split-Path $OutputPath
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }

# ---------------------------
# FUNCTION: Get-FolderPermissions
# ---------------------------
function Get-FolderPermissions {
    param ([string]$FolderPath)

    try {
        $acl = Get-Acl -Path $FolderPath -ErrorAction Stop

        # Folder inheritance setting (are rules protected from parent?)
        $folderInheritance = if ($acl.AreAccessRulesProtected) { 
            "Inheritance Disabled (Explicit Permissions Only)" 
        } else { 
            "Inheritance Enabled (Inherits from Parent)" 
        }

        foreach ($access in $acl.Access) {
            $permissionOrigin = if ($access.IsInherited) { 
                "Inherited from Parent" 
            } else { 
                "Explicitly Set on This Folder" 
            }

            [PSCustomObject]@{
                FolderPath             = $FolderPath
                Identity               = $access.IdentityReference
                Rights                 = $access.FileSystemRights
                AccessType             = $access.AccessControlType
                'Folder Inheritance'   = $folderInheritance
                'Permission Source'    = $permissionOrigin
            }
        }
    } catch {
        $script:skipped += $FolderPath
    }
}

# ---------------------------
# MAIN EXECUTION
# ---------------------------
Write-Host "`nScanning folder permissions for $RootPath ..." -ForegroundColor Cyan

$folders = Get-ChildItem -Path $RootPath -Directory -Recurse -ErrorAction SilentlyContinue
$allTargets = @($RootPath) + ($folders.FullName)

foreach ($folder in $allTargets) {
    $results += Get-FolderPermissions -FolderPath $folder
}

Write-Host "`nScan complete. Building grouped HTML report..." -ForegroundColor Cyan

# ---------------------------
# HTML STYLING
# ---------------------------
$css = @"
<style>
body {
    font-family: 'Segoe UI', Tahoma, sans-serif;
    background-color: #f4f6f8;
    color: #333;
    margin: 40px;
}
h1 {
    color: #2c3e50;
    text-align: center;
}
h2 {
    color: #34495e;
    border-bottom: 2px solid #bdc3c7;
    padding-bottom: 4px;
    margin-top: 40px;
}
table {
    width: 100%;
    border-collapse: collapse;
    margin-top: 10px;
    margin-bottom: 20px;
}
th {
    background-color: #34495e;
    color: white;
    padding: 8px;
    text-align: left;
}
td {
    border-bottom: 1px solid #ddd;
    padding: 6px;
}
tr:nth-child(even) {
    background-color: #ecf0f1;
}
.inherit-enabled {
    color: green;
    font-weight: bold;
}
.inherit-disabled {
    color: red;
    font-weight: bold;
}
.source-inherited {
    color: green;
}
.source-explicit {
    color: red;
}
footer {
    text-align: center;
    margin-top: 40px;
    color: #888;
    font-size: 12px;
}
.warning {
    color: #c0392b;
    font-weight: bold;
}
</style>
"@

# ---------------------------
# BUILD GROUPED HTML
# ---------------------------
$htmlBody = "<h1>Folder Permissions Report</h1>"
$htmlBody += "<p><strong>Root Path:</strong> $RootPath</p>"
$htmlBody += "<p><strong>Generated On:</strong> $(Get-Date)</p>"

# Group by FolderPath
$grouped = $results | Group-Object FolderPath | Sort-Object Name

foreach ($group in $grouped) {
    $folder = $group.Name
    $folderRows = ""

    foreach ($item in $group.Group) {
        $inheritClass = if ($item.'Folder Inheritance' -like "*Enabled*") { "inherit-enabled" } else { "inherit-disabled" }
        $sourceClass = if ($item.'Permission Source' -like "*Inherited*") { "source-inherited" } else { "source-explicit" }

        $folderRows += "<tr>
            <td>$($item.Identity)</td>
            <td>$($item.Rights)</td>
            <td>$($item.AccessType)</td>
            <td class='$inheritClass'>$($item.'Folder Inheritance')</td>
            <td class='$sourceClass'>$($item.'Permission Source')</td>
        </tr>"
    }

    $htmlBody += "<h2>$folder</h2>
    <table>
        <tr>
            <th>Identity</th>
            <th>Rights</th>
            <th>Access Type</th>
            <th>Folder Inheritance</th>
            <th>Permission Source</th>
        </tr>
        $folderRows
    </table>"
}

# Skipped folders section
if ($skipped.Count -gt 0) {
    $skippedTable = ($skipped | Sort-Object | ForEach-Object { "<tr><td>$_</td></tr>" }) -join "`n"
    $htmlBody += "<h2>Skipped Folders (Access Denied or Error)</h2>
    <table><tr><th>Folder Path</th></tr>$skippedTable</table>"
} else {
    $htmlBody += "<h2>No Folders Were Skipped 🎉</h2>"
}

# ---------------------------
# FINALIZE HTML
# ---------------------------
$fullHtml = @"
<html>
<head>
<meta charset='UTF-8'>
<title>Folder Permissions Report</title>
$css
</head>
<body>
$htmlBody
<footer>
Generated by $FullName on $(Get-Date -Format "yyyy-MM-dd") Using PowerShell Permissions Script
</footer>
</body>
</html>
"@

# ---------------------------
# OUTPUT
# ---------------------------
$fullHtml | Out-File -FilePath $OutputPath -Encoding UTF8

Write-Host "`n✅ Report saved to: $OutputPath" -ForegroundColor Green
Start-Process $OutputPath
