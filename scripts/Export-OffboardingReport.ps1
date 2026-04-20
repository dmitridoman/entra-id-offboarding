<#
.SYNOPSIS
    Dump a simple JSON report: user flags, group memberships, licence SKUs.

.DESCRIPTION
    Read-only aside from creating the output file. Useful before you start ripping licences out.

.NOTES
    Big groupsets: pagination can be slow. This uses -All on cmdlets where available.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $UserId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $OutputPath,

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

$mods = @(
    'Microsoft.Graph.Users',
    'Microsoft.Graph.Identity.DirectoryManagement'
)
foreach ($m in $mods) {
    if (-not (Get-Module $m -ErrorAction SilentlyContinue)) {
        Import-Module $m -ErrorAction Stop
    }
}

Write-LogLine "Building report for $UserId"

$user = Get-MgUser -UserId $UserId -Property Id, UserPrincipalName, DisplayName, AccountEnabled, UserType, OnPremisesSyncEnabled -ErrorAction Stop

$groups = @(
    Get-MgUserMemberOf -UserId $UserId -All -ErrorAction Stop |
        ForEach-Object {
            # MemberOf returns directoryObject — expand group ids you can read
            if ($_.AdditionalProperties['@odata.type'] -match 'group') {
                [pscustomobject]@{
                    Id          = $_.Id
                    DisplayName = $_.AdditionalProperties['displayName']
                }
            }
        }
)

$licences = @(
    Get-MgUserLicenseDetail -UserId $UserId -All -ErrorAction Stop |
        ForEach-Object {
            [pscustomobject]@{
                SkuId         = $_.SkuId
                SkuPartNumber = $_.SkuPartNumber # sometimes blank depending on Graph shape/version
            }
        }
)

$report = [pscustomobject]@{
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    user           = $user
    groups         = $groups
    licences       = $licences
}

$outDir = Split-Path -Parent $OutputPath
if ($outDir -and -not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$report | ConvertTo-Json -Depth 8 | Set-Content -Path $OutputPath -Encoding UTF8
Write-LogLine "Wrote $OutputPath"
