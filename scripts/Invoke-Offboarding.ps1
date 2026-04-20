<#
.SYNOPSIS
    Orchestrate a simple cloud leaver flow: disable, revoke sessions, optional group strip, optional licence removal, report.

.DESCRIPTION
    Cloud-first only. Hybrid sync caveats live in docs — if onPremisesSyncEnabled is true, expect surprises.

.NOTES
    High impact. Defaults to asking confirmation on licence removal unless you pass -Confirm:$false (please do not do that blindly).
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $UserPrincipalName,

    [Parameter(Mandatory = $false)]
    [switch] $SkipGroupRemoval,

    [Parameter(Mandatory = $false)]
    [switch] $SkipLicenceRemoval,

    [Parameter(Mandatory = $false)]
    [string] $ReportPath = ".\offboarding-report-$(Get-Date -Format 'yyyyMMddHHmmss').json",

    [Parameter(Mandatory = $false)]
    [string] $LogPath
)

function Write-LogLine {
    param([string] $Message)
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$ts] $Message"
    Write-Host $line
    if ($LogPath) {
        Add-Content -Path $LogPath -Value $line
    }
}

if ($LogPath) {
    $logDir = Split-Path -Parent $LogPath
    if ($logDir -and -not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not (Get-Module Microsoft.Graph.Users -ErrorAction SilentlyContinue)) {
    Import-Module Microsoft.Graph.Users -ErrorAction Stop
}

Write-LogLine "Resolving $UserPrincipalName"
$user = Get-MgUser -Filter "userPrincipalName eq '$UserPrincipalName'" -ConsistencyLevel eventual -ErrorAction Stop |
    Select-Object -First 1
if (-not $user) {
    throw "User not found: $UserPrincipalName"
}
$userId = $user.Id
Write-LogLine "Target Id: $userId"

if ($user.OnPremisesSyncEnabled -eq $true) {
    Write-LogLine "WARNING: onPremisesSyncEnabled is true — cloud-only steps may fight AD sync. Check docs."
}

& "$scriptDir\Export-OffboardingReport.ps1" -UserId $userId -OutputPath $ReportPath -LogPath $LogPath

# Disable account
Write-LogLine "Disabling sign-in"
if ($PSCmdlet.ShouldProcess($userId, 'Disable user account')) {
    Update-MgUser -UserId $userId -BodyParameter @{ accountEnabled = $false } -ErrorAction Stop
}

# Revoke sessions
& "$scriptDir\Revoke-UserSessions.ps1" -UserId $userId -LogPath $LogPath

if (-not $SkipGroupRemoval) {
    Write-LogLine "Removing cloud group memberships (best effort)"
    $memberships = Get-MgUserMemberOf -UserId $userId -All -ErrorAction Stop
    foreach ($m in $memberships) {
        if ($m.AdditionalProperties['@odata.type'] -match 'group') {
            $gid = $m.Id
            $name = $m.AdditionalProperties['displayName']
            if ($PSCmdlet.ShouldProcess("$name ($gid)", 'Remove user from group')) {
                try {
                    # DELETE /groups/{id}/members/{id}/$ref — cmdlet names differ between module versions.
                    Invoke-MgGraphRequest -Method DELETE -Uri "/v1.0/groups/$gid/members/$userId/`$ref" -ErrorAction Stop
                    Write-LogLine "Removed from group: $name"
                }
                catch {
                    Write-LogLine "Group remove failed for $name — might be dynamic, sync-owned, or insufficient rights: $($_.Exception.Message)"
                }
            }
        }
    }
}
else {
    Write-LogLine "Skipping group removal (-SkipGroupRemoval)."
}

if (-not $SkipLicenceRemoval) {
    & "$scriptDir\Remove-UserLicences.ps1" -UserId $userId -LogPath $LogPath
}
else {
    Write-LogLine "Skipping licence removal (-SkipLicenceRemoval)."
}

Write-LogLine "Done. Report: $ReportPath"
