# Set-EpcOsdCloudComputerName.ps1 - Evidi AutopilotV2
# Kjoeres i WinPE/OSDCloud foer corporate identifier-eksport.
param(
    [string]$LogPath = 'C:\OSDCloud\Logs\Set-EpcOsdCloudComputerName.log'
)
$ErrorActionPreference = 'Stop'

function Write-Log {
    param([Parameter(Mandatory)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO')
    $parent = Split-Path -Parent $LogPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -LiteralPath $LogPath -Value $line -Encoding utf8
    Write-Output $line
}

try {
    $raw = [string](Get-CimInstance -ClassName Win32_BIOS).SerialNumber
    $serial = $raw.ToUpperInvariant() -replace '[^A-Z0-9]', ''
    if (-not $serial) { throw "Fant ikke brukbart serienummer (rapportert: '$raw')." }
    if ($serial.Length -gt 11) { $serial = $serial.Substring($serial.Length - 11) }
    $target = "EPC-$serial"
    $current = [string]$env:COMPUTERNAME
    if ($current -ieq $target) {
        Write-Log ("Navnet er allerede {0} - ingen endring. Exit 0." -f $target)
        exit 0
    }

    Rename-Computer -NewName $target -Force -ErrorAction Stop
    Write-Log ("OSDCloud-navn: {0} -> {1}." -f $current, $target)
    exit 0
}
catch {
    Write-Log ("FEILET: Kunne ikke sette OSDCloud-navnet: {0} Exit 1." -f $_.Exception.Message) 'ERROR'
    exit 1
}