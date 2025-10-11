# === CONFIGURATION ===
$InputCsv = "C:\Data\PermissionsBackup.csv"
# ======================

if (!(Test-Path $InputCsv)) {
    Write-Error "Backup file not found: $InputCsv"
    exit
}

$permissions = Import-Csv -Path $InputCsv
Write-Host "Restoring folder permissions from backup..." -ForegroundColor Cyan

# Group by folder so we can handle inheritance per folder
$grouped = $permissions | Group-Object -Property FolderPath

foreach ($folderGroup in $grouped) {
    $folder = $folderGroup.Name
    if (-not (Test-Path $folder)) {
        Write-Warning "Folder not found: $folder"
        continue
    }

    try {
        $acl = Get-Acl $folder
        $inheritanceEnabled = ($folderGroup.Group | Select-Object -First 1).InheritanceEnabled

        # Enable or disable inheritance to match backup
        if ($inheritanceEnabled) {
            $acl.SetAccessRuleProtection($false, $true) # Enable inheritance
        } else {
            $acl.SetAccessRuleProtection($true, $true)  # Disable inheritance, preserve existing inherited rules
        }

        # Clear explicit rules if inheritance is disabled (fresh start)
        $acl.Access | ForEach-Object {
            if (-not $_.IsInherited) {
                $acl.RemoveAccessRule($_)
            }
        }

        foreach ($entry in $folderGroup.Group) {
            # Only restore explicit (non-inherited) permissions
            if ($entry.IsInherited -eq "False") {
                $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                    $entry.IdentityReference,
                    $entry.FileSystemRights,
                    $entry.InheritanceFlags,
                    $entry.PropagationFlags,
                    $entry.AccessControlType
                )
                $acl.AddAccessRule($accessRule)
            }
        }

        Set-Acl -Path $folder -AclObject $acl
        Write-Host "Restored permissions for: $folder" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to restore permissions on $folder - $_"
    }
}

Write-Host "Permission restore complete." -ForegroundColor Yellow
