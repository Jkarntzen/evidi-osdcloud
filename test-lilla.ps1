# Evidi - lilla fargevifte for WinPE-konsollen.
# Kjor i WinPE:  irm 'https://raw.githubusercontent.com/Jkarntzen/evidi-osdcloud/main/test-lilla.ps1' | iex
# Viser 7 lilla-nyanser (moerk -> lys). Velg nummeret du liker, saa setter vi den i menyen.

$def = @'
[StructLayout(LayoutKind.Sequential)] public struct COORD { public short X; public short Y; }
[StructLayout(LayoutKind.Sequential)] public struct SMALL_RECT { public short Left; public short Top; public short Right; public short Bottom; }
[StructLayout(LayoutKind.Sequential)] public struct CONSOLE_SCREEN_BUFFER_INFO_EX {
    public int cbSize; public COORD dwSize; public COORD dwCursorPosition; public ushort wAttributes;
    public SMALL_RECT srWindow; public COORD dwMaximumWindowSize; public ushort wPopupAttributes; public bool bFullscreenSupported;
    [MarshalAs(UnmanagedType.ByValArray, SizeConst=16)] public int[] ColorTable;
}
[DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr GetStdHandle(int n);
[DllImport("kernel32.dll", SetLastError=true)] public static extern bool GetConsoleScreenBufferInfoEx(IntPtr h, ref CONSOLE_SCREEN_BUFFER_INFO_EX i);
[DllImport("kernel32.dll", SetLastError=true)] public static extern bool SetConsoleScreenBufferInfoEx(IntPtr h, ref CONSOLE_SCREEN_BUFFER_INFO_EX i);
'@

try { Add-Type -Namespace T -Name Pal -MemberDefinition $def -ErrorAction Stop }
catch { Write-Host "Add-Type FEILET: $($_.Exception.Message)" -ForegroundColor Red; return }

# Kandidat-nyanser (moerk -> lys). Hver mappes til en ledig konsoll-slot vi ikke bruker ellers.
$Kandidater = @(
    @{ Nr=1; Slot=1; Navn='DarkBlue';    R=64;  G=30;  B=96;  Hex='#401E60' },   # dagens - for moerk
    @{ Nr=2; Slot=2; Navn='DarkGreen';   R=84;  G=42;  B=122; Hex='#542A7A' },
    @{ Nr=3; Slot=3; Navn='DarkCyan';    R=106; G=53;  B=150; Hex='#6A3596' },
    @{ Nr=4; Slot=4; Navn='DarkRed';     R=142; G=63;  B=176; Hex='#8E3FB0' },
    @{ Nr=5; Slot=5; Navn='DarkMagenta'; R=160; G=82;  B=200; Hex='#A052C8' },
    @{ Nr=6; Slot=6; Navn='DarkYellow';  R=181; G=106; B=216; Hex='#B56AD8' },
    @{ Nr=7; Slot=9; Navn='Blue';        R=200; G=130; B=230; Hex='#C882E6' }
)

$h = [T.Pal]::GetStdHandle(-11)
$i = New-Object T.Pal+CONSOLE_SCREEN_BUFFER_INFO_EX
$i.ColorTable = New-Object int[] 16
$i.cbSize = [System.Runtime.InteropServices.Marshal]::SizeOf([type][T.Pal+CONSOLE_SCREEN_BUFFER_INFO_EX])
$okGet = [T.Pal]::GetConsoleScreenBufferInfoEx($h, [ref]$i)

foreach ($k in $Kandidater) { $i.ColorTable[$k.Slot] = ($k.R -bor ($k.G -shl 8) -bor ($k.B -shl 16)) }
$okSet = [T.Pal]::SetConsoleScreenBufferInfoEx($h, [ref]$i)

Write-Host ""
Write-Host ("  GET={0}  SET={1}   (begge skal vaere True)" -f $okGet, $okSet) -ForegroundColor Gray
Write-Host "  Lilla-vifte - velg nummeret du liker:" -ForegroundColor Gray
Write-Host ""
foreach ($k in $Kandidater) {
    Write-Host ("   {0}  {1,-8} " -f $k.Nr, $k.Hex) -ForegroundColor Gray -NoNewline
    Write-Host "   VALGT RAD - EVIDI   " -BackgroundColor $k.Navn -ForegroundColor White
}
Write-Host ""
if (-not ($okGet -and $okSet)) { Write-Host "  ADVARSEL: GET/SET=False - palett-API virker ikke her." -ForegroundColor Yellow }
