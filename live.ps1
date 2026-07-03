<#
    Evidi OSDCloud "live" bootstrap
    -------------------------------
    Vaar egen erstatning for deploy.osdcloud.live / .ch (som var hhv. dodt DNS og hadde
    utloept SSL-sertifikat). Hostes raatt paa GitHub - raw.githubusercontent.com har alltid
    gyldig SSL og er alltid oppe, saa denne kan vi stole paa.

    VIKTIG: OSDCloud er en EGEN modul (aktivt vedlikeholdt; ARM64 + GUI) - IKKE OSD-modulen
    som ligger paa WinPE-ISO-en og driver valg 1-4. OSDCloud-modulen ligger ikke paa ISO-en
    og maa hentes fra PSGallery. Se https://www.osdeploy.com/powershell-modules/osdcloud

    Kalles fra WinPE-menyen:
        Invoke-RestMethod 'https://raw.githubusercontent.com/<ORG>/<REPO>/main/live.ps1' | Invoke-Expression
#>

# WinPE (PS 5.1) defaulter til TLS 1.0 -> PSGallery/GitHub avviser. Tving TLS 1.2.
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

Write-Host 'Evidi OSDCloud - installerer OSDCloud-modulen og starter GUI ...' -ForegroundColor Cyan

# NuGet-provider kreves for Install-Module i WinPE.
try {
    if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
        Install-PackageProvider -Name NuGet -Force -ErrorAction Stop | Out-Null
    }
} catch { }

# Hent + last inn OSDCloud-modulen fra PSGallery.
Install-Module -Name OSDCloud -Force -SkipPublisherCheck -ErrorAction Stop
Import-Module -Name OSDCloud -Force

# Forhaandsvelg norsk (nb-no) + Windows 11 25H2 som standard i GUI-en. OSDCloud leser
# default-verdiene fra 'default'-workflowens os-amd64/os-arm64.json. Vi patcher dem etter
# installasjon (WinPE er ferskt hver boot). Defensivt - feiler ikke tankingen om schema endres.
try {
    $mb = (Get-Module OSDCloud).ModuleBase
    foreach ($arch in 'amd64', 'arm64') {
        $f = Join-Path $mb "workflow\default\os-$arch.json"
        if (Test-Path $f) {
            $j = Get-Content $f -Raw | ConvertFrom-Json
            if ($j.OSLanguageCode)  { $j.OSLanguageCode.default  = 'nb-no' }
            if ($j.OperatingSystem) { $j.OperatingSystem.default = 'Windows 11 25H2' }
            ($j | ConvertTo-Json -Depth 20) | Set-Content -Path $f -Encoding UTF8
        }
    }
} catch {
    Write-Host 'Kunne ikke forhaandsvelge sprak/OS - fortsetter med modulens standard.' -ForegroundColor Yellow
}

# Start OSDCloud-deployment (GUI/UX, stoetter ARM64).
Deploy-OSDCloud
