# Invoke-OsdCloudEpcPrep.ps1 - Evidi AutopilotV2
# Kjoeres i WinPE/OSDCloud foer foerste oppstart. Skriptet endrer den
# utlagte Windows-partisjonen, ikke WinPE-miljoets eget register.
param(
    [string]$WindowsPartitionPath,
    [string]$LogPath = 'C:\OSDCloud\Logs\Invoke-OsdCloudEpcPrep.log'
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

function Resolve-WindowsPartition {
    param([string]$RequestedPath)
    if ($RequestedPath) {
        if (-not (Test-Path -LiteralPath (Join-Path $RequestedPath 'Windows'))) { throw "Fant ikke Windows-mappen under $RequestedPath." }
        return $RequestedPath.TrimEnd('\')
    }
    $candidates = Get-PSDrive -PSProvider FileSystem | ForEach-Object { $_.Root.TrimEnd('\') } |
        Where-Object { Test-Path -LiteralPath (Join-Path $_ 'Windows') }
    if ($candidates -contains 'C:') { return 'C:' }
    $candidates = @($candidates | Where-Object { $_ -notmatch '^X:$' })
    if (@($candidates).Count -ne 1) {
        throw ('Kunne ikke finne entydig Windows-partisjon. Angi -WindowsPartitionPath. Kandidater: {0}' -f ($candidates -join ', '))
    }
    $candidates[0]
}

function Get-EpcComputerName {
    $raw = [string](Get-CimInstance -ClassName Win32_BIOS).SerialNumber
    $serial = $raw.ToUpperInvariant() -replace '[^A-Z0-9]', ''
    if (-not $serial) { throw "Fant ikke brukbart serienummer (rapportert: '$raw')." }
    if ($serial.Length -gt 11) { $serial = $serial.Substring($serial.Length - 11) }
    "EPC-$serial"
}

function New-EpcUnattendXml {
    param([Parameter(Mandatory)][string]$ComputerName)
    $namespace = 'urn:schemas-microsoft-com:unattend'
    $settings = New-Object System.Xml.XmlDocument
    $declaration = $settings.CreateXmlDeclaration('1.0', 'utf-8', $null)
    [void]$settings.AppendChild($declaration)
    $unattend = $settings.CreateElement('unattend', $namespace)
    [void]$settings.AppendChild($unattend)

    $specialize = $settings.CreateElement('settings', $namespace)
    $specialize.SetAttribute('pass', 'specialize')
    $shell = $settings.CreateElement('component', $namespace)
    $shell.SetAttribute('name', 'Microsoft-Windows-Shell-Setup')
    $shell.SetAttribute('processorArchitecture', 'amd64')
    $shell.SetAttribute('publicKeyToken', '31bf3856ad364e35')
    $shell.SetAttribute('language', 'neutral')
    $shell.SetAttribute('versionScope', 'nonSxS')
    $computer = $settings.CreateElement('ComputerName', $namespace)
    $computer.InnerText = $ComputerName
    [void]$shell.AppendChild($computer)
    [void]$specialize.AppendChild($shell)
    [void]$unattend.AppendChild($specialize)

    $oobeSystem = $settings.CreateElement('settings', $namespace)
    $oobeSystem.SetAttribute('pass', 'oobeSystem')
    $oobe = $settings.CreateElement('component', $namespace)
    $oobe.SetAttribute('name', 'Microsoft-Windows-Shell-Setup')
    $oobe.SetAttribute('processorArchitecture', 'amd64')
    $oobe.SetAttribute('publicKeyToken', '31bf3856ad364e35')
    $oobe.SetAttribute('language', 'neutral')
    $oobe.SetAttribute('versionScope', 'nonSxS')
    $oobeSettings = $settings.CreateElement('OOBE', $namespace)
    foreach ($pair in @(@{ Name = 'HideEULAPage'; Value = 'true' }, @{ Name = 'ProtectYourPC'; Value = '3' })) {
        $element = $settings.CreateElement($pair.Name, $namespace)
        $element.InnerText = $pair.Value
        [void]$oobeSettings.AppendChild($element)
    }
    [void]$oobe.AppendChild($oobeSettings)
    [void]$oobeSystem.AppendChild($oobe)
    [void]$unattend.AppendChild($oobeSystem)
    $settings
}

try {
    Write-Log 'Start: Invoke-OsdCloudEpcPrep'
    $windowsRoot = Resolve-WindowsPartition -RequestedPath $WindowsPartitionPath
    $computerName = Get-EpcComputerName
    $pantherDir = Join-Path $windowsRoot 'Windows\Panther'
    if (-not (Test-Path -LiteralPath $pantherDir)) { New-Item -ItemType Directory -Path $pantherDir -Force | Out-Null }
    $unattendPath = Join-Path $pantherDir 'unattend.xml'
    $xml = New-EpcUnattendXml -ComputerName $computerName
    $xml.Save($unattendPath)
    Write-Log ("Skrev {0} med ComputerName={1}; OOBE-innstillinger er idempotent erstattet." -f $unattendPath, $computerName)
    Write-Log 'Ferdig: Invoke-OsdCloudEpcPrep. Exit 0.'
    exit 0
}
catch {
    Write-Log ("FEILET: {0} Exit 1." -f $_.Exception.Message) 'ERROR'
    exit 1
}