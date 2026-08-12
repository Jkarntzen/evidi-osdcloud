# Export-EpcCorporateIdentifier.ps1 - Evidi AutopilotV2
# Kjoeres i WinPE/OSDCloud. Eksporterer eksakte WMI-verdier uten normalisering.
param(
    [string]$CsvPath,
    [string]$UsbRootPath = 'D:\',
    [string]$UsbFallbackRootPath = 'C:\',
    [string]$UsbFallbackPath,
    [string]$LogPath = 'C:\OSDCloud\Logs\Export-EpcCorporateIdentifier.log'
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
    $computer = Get-CimInstance -ClassName Win32_ComputerSystem
    $bios = Get-CimInstance -ClassName Win32_BIOS
    $manufacturer = [string]$computer.Manufacturer
    $model = [string]$computer.Model
    $serial = [string]$bios.SerialNumber
    if ([string]::IsNullOrWhiteSpace($manufacturer) -or [string]::IsNullOrWhiteSpace($model) -or [string]::IsNullOrWhiteSpace($serial)) {
        throw 'Manufacturer, Model eller SerialNumber mangler i WMI.'
    }

    $serialNorm = $serial.ToUpperInvariant() -replace '[.]', ''
    $reportedComputerName = [string]$env:COMPUTERNAME
    $computerName = if ($reportedComputerName -and $reportedComputerName -notmatch '^(MININT|MINWINPC)(-|$)') {
        $reportedComputerName
    }
    else {
        $epcSerial = $serial.ToUpperInvariant() -replace '[^A-Z0-9]', ''
        if ($epcSerial.Length -gt 11) { $epcSerial = $epcSerial.Substring($epcSerial.Length - 11) }
        "EPC-$epcSerial"
    }

    if ($UsbRootPath) {
        $roots = @($UsbRootPath)
        if ($UsbFallbackRootPath -and $UsbFallbackRootPath -notin $roots) { $roots += $UsbFallbackRootPath }
        $selectedRoot = $null
        foreach ($root in $roots) {
            try {
                if (-not (Test-Path -LiteralPath $root)) { throw "Roten finnes ikke: $root" }
                $computerFolder = Join-Path $root $computerName
                if (-not (Test-Path -LiteralPath $computerFolder)) {
                    New-Item -ItemType Directory -Path $computerFolder -Force | Out-Null
                }
                $probePath = Join-Path $computerFolder '.write-test'
                Set-Content -LiteralPath $probePath -Value 'write-test' -Encoding utf8 -ErrorAction Stop
                Remove-Item -LiteralPath $probePath -Force -ErrorAction Stop
                $selectedRoot = $root
                break
            }
            catch {
                Write-Log ("Kan ikke skrive til {0}: {1}" -f $root, $_.Exception.Message) 'WARN'
            }
        }
        if (-not $selectedRoot) { throw 'Ingen skrivbar output-rot funnet. Prøv D: og fallback C:.' }
        $CsvPath = Join-Path (Join-Path $selectedRoot $computerName) 'corporate-identifier.csv'
        Write-Log ("Output valgt: {0} (PC-navn: {1})." -f $CsvPath, $computerName)
    }
    if (-not $CsvPath) {
        throw 'Angi -CsvPath, eller -UsbRootPath for å skrive <USB-root>\<PC-navn>\corporate-identifier.csv.'
    }

    $target = $CsvPath
    $parent = Split-Path -Parent $target
    if (-not (Test-Path -LiteralPath $parent)) {
        if ($UsbFallbackPath -and (Test-Path -LiteralPath (Split-Path -Parent $UsbFallbackPath))) {
            $target = $UsbFallbackPath
            Write-Log ("Sentral CSV er utilgjengelig; bruker USB-fallback {0}." -f $target) 'WARN'
        }
        else { throw "CSV-mappen finnes ikke og USB-fallback er ikke tilgjengelig: $parent" }
    }
    if (-not (Test-Path -LiteralPath $target)) {
        New-Item -ItemType File -Path $target -Force | Out-Null
    }

    $existing = @(Get-Content -LiteralPath $target -ErrorAction SilentlyContinue)
    $duplicate = @($existing | Where-Object {
        $parts = $_ -split ',', 3
        $parts.Count -eq 3 -and (($parts[2].Trim().ToUpperInvariant() -replace '[.]', '') -eq $serialNorm)
    })
    if ($duplicate.Count -gt 0) {
        Write-Log ("Serienummer {0} finnes allerede i {1}; ingen rad lagt til." -f $serial, $target)
        exit 0
    }

    Add-Content -LiteralPath $target -Value ('{0},{1},{2}' -f $manufacturer, $model, ($serial -replace '[.]', '')) -Encoding utf8
    Write-Log ("La til eksakt WMI-identifier: Manufacturer='{0}', Model='{1}', SerialNumber='{2}' i {3}. Exit 0." -f $manufacturer, $model, $serial, $target)
    exit 0
}
catch {
    Write-Log ("FEILET: {0} Exit 1." -f $_.Exception.Message) 'ERROR'
    exit 1
}