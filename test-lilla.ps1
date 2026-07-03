# Evidi - test av lilla konsollfarge (palett-remap) i WinPE.
# Kjor i WinPE-konsollen:  irm 'https://raw.githubusercontent.com/Jkarntzen/evidi-osdcloud/main/test-lilla.ps1' | iex
# Viser om SetConsoleScreenBufferInfoEx virker + fargen FOER/ETTER. Er ETTER dyp lilla = fiksen virker.

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
catch { Write-Host "Add-Type FEILET (ingen C#-kompilator i WinPE?): $($_.Exception.Message)" -ForegroundColor Red; return }

$h = [T.Pal]::GetStdHandle(-11)
$i = New-Object T.Pal+CONSOLE_SCREEN_BUFFER_INFO_EX
$i.ColorTable = New-Object int[] 16
$i.cbSize = [System.Runtime.InteropServices.Marshal]::SizeOf([type][T.Pal+CONSOLE_SCREEN_BUFFER_INFO_EX])

$okGet = [T.Pal]::GetConsoleScreenBufferInfoEx($h, [ref]$i)
Write-Host ("GET-kall: {0}   (Magenta-slot foer: 0x{1:X6})" -f $okGet, $i.ColorTable[13])
Write-Host "FOER : " -NoNewline; Write-Host "   LILLA-TEST   " -BackgroundColor Magenta -ForegroundColor White

$i.ColorTable[13] = (64 -bor (30 -shl 8) -bor (96 -shl 16))   # #401E60
$okSet = [T.Pal]::SetConsoleScreenBufferInfoEx($h, [ref]$i)
Write-Host ("SET-kall: {0}" -f $okSet)
Write-Host "ETTER: " -NoNewline; Write-Host "   LILLA-TEST   " -BackgroundColor Magenta -ForegroundColor White
Write-Host ""
if ($okGet -and $okSet) { Write-Host "OK - hvis 'ETTER'-baren ble dyp lilla, virker fiksen i din WinPE." -ForegroundColor Green }
else { Write-Host "API-et virker IKKE her (GET/SET=False) - da maa vi bruke en annen metode." -ForegroundColor Yellow }
