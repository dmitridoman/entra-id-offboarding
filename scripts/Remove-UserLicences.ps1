<#
.SYNOPSIS
    Remove all directly assigned licences from a user via assignLicense.

.DESCRIPTION
    Reads current licence details, then removes SKU IDs. If you use group-based licensing only, this may do little — check assignments first.

.NOTES
    Destructive. Supports -WhatIf via ShouldProcess on the update call (approximate — Graph does not always honour WhatIf server-side).
    Run Export-OffboardingReport.ps1 before you get brave.
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $UserId,

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

if (-not (Get-Module Microsoft.Graph.Users -ErrorAction SilentlyContinue)) {
    Import-Module Microsoft.Graph.Users -ErrorAction Stop
}

Write-LogLine "Reading licence details for $UserId"
$details = Get-MgUserLicenseDetail -UserId $UserId -All -ErrorAction Stop
$skuIds = @($details | ForEach-Object { $_.SkuId } | Where-Object { $_ })

if ($skuIds.Count -eq 0) {
    Write-LogLine "No direct licence SKUs found on user (might be group-based only)."
    return
}

Write-LogLine "Removing SKUs: $($skuIds -join ', ')"

if ($PSCmdlet.ShouldProcess($UserId, "Remove $($skuIds.Count) licence SKU(s)")) {
    $payload = @{
        addLicenses    = @()
        removeLicenses = @($skuIds)
    }
    # assignLicense POST — body must be JSON with GUID strings, not objects.
    Invoke-MgGraphRequest -Method POST -Uri "/v1.0/users/$UserId/assignLicense" -Body ($payload | ConvertTo-Json -Depth 6) -ErrorAction Stop
    Write-LogLine "assignLicense remove submitted."
}
