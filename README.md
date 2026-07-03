# evidi-osdcloud

Evidi sin egen OSDCloud "live" bootstrap for WinPE.

Erstatter de ustabile community-snarveiene `deploy.osdcloud.live` (dodt DNS) og
`deploy.osdcloud.ch` (utlopt SSL). GitHub (raw.githubusercontent.com) har alltid
gyldig SSL og er alltid oppe.

## Bruk (fra WinPE-meny)

```powershell
Invoke-RestMethod 'https://raw.githubusercontent.com/Jkarntzen/evidi-osdcloud/main/live.ps1' | Invoke-Expression
```

`live.ps1`:
- Setter TLS 1.2
- Installerer OSDCloud-modulen fra PSGallery (egen modul, ikke OSD som ligger pa ISO-en)
- Forhandsvelger norsk (nb-no) + Windows 11 25H2 i GUI-en
- Kjorer `Deploy-OSDCloud`