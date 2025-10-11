# === CONFIGURATION ===
$FolderPath = "C:\Data"
$OutputCsv  = "C:\Data\PermissionsBackup.csv"
# ======================

$permissions = @()

Write-Host "Scanning folder and subfolders from $FolderPath..." -ForegroundColor Cyan

Get-ChildItem -Path $FolderPath -Recurse -Directory | ForEach-Object {
    try {
        $acl = Get-Acl $_.FullName
        $inheritanceEnabled = -not $acl.AreAccessRulesProtected

        foreach ($access in $acl.Access) {
            $permissions += [PSCustomObject]@{
                FolderPath          = $_.FullName
                IdentityReference    = $access.IdentityReference.ToString()
                AccessControlType    = $access.AccessControlType
                FileSystemRights     = $access.FileSystemRights
                IsInherited          = $access.IsInherited
                InheritanceFlags     = $access.InheritanceFlags
                PropagationFlags     = $access.PropagationFlags
                InheritanceEnabled   = $inheritanceEnabled
            }
        }
    }
    catch {
        Write-Warning "Failed to read permissions for: $($_.FullName) - $_"
    }
}

$backupDir = Split-Path $OutputCsv
if (!(Test-Path $backupDir)) { New-Item -Path $backupDir -ItemType Directory | Out-Null }

$permissions | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host "Permissions exported to: $OutputCsv" -ForegroundColor Green
