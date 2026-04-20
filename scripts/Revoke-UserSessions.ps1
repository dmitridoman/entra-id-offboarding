<#
.SYNOPSIS
    Revoke refresh tokens for a user (sign-out everywhere Graph can reach).

.DESCRIPTION
    Wraps the revokeSignInSessions API. Does not uninstall local creds from every weird LOB client.

.NOTES
    Needs User.ReadWrite.All (or equivalent). Graph sometimes returns 204 with a body — either way, verify in Entra sign-in logs if you are paranoid.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
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

Write-LogLine "Revoking sign-in sessions for $UserId"

if ($PSCmdlet.ShouldProcess($UserId, 'Revoke sign-in sessions')) {
    # Cmdlet name varies by module generation — request is boring and portable.
    $result = Invoke-MgGraphRequest -Method POST -Uri "/v1.0/users/$UserId/revokeSignInSessions" -ErrorAction Stop
    Write-LogLine "Graph response: $($result | ConvertTo-Json -Compress)"
}
