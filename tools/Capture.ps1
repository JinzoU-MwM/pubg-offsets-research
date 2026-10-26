param(
  [string]$Name = "TslGame",
  [string]$OutDir = "C:\Users\User\pubgcap",
  [int]$TimeoutSec = 180
)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$enc = [byte[]](0x4f,0x7e,0x82,0xf2,0x1d,0x79,0xb4,0xba,0x8d,0x65,0xa4,0xaf,0x05,0xfd,0x17,0xd0)
$cs = @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
public class Q {
  [DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr OpenProcess(uint a, bool ih, int pid);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, IntPtr size, out IntPtr read);
  [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
}
'@
Add-Type -TypeDefinition $cs -Language CSharp
$deadline = (Get-Date).AddSeconds($TimeoutSec)
$p = $null
while ((Get-Date) -lt $deadline -and -not $p) {
  $p = Get-Process -Name $Name -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $p) { Start-Sleep -Milliseconds 100 }
}
if (-not $p) { Write-Output "PROCESS_NOT_FOUND"; exit 2 }
Write-Output ("FOUND pid=" + $p.Id + " at " + (Get-Date -Format o))
$h = [Q]::OpenProcess(0x0410, $false, $p.Id)
if ($h -eq [IntPtr]::Zero) { Write-Output ("OPEN_FAIL " + [Runtime.InteropServices.Marshal]::GetLastWin32Error()); exit 3 }
try {
  $base = [Int64]$p.MainModule.BaseAddress
  Write-Output ("BASE=0x" + $base.ToString("x") + " module=" + $p.MainModule.ModuleName)
  $state = "unknown"; $n = 0
  $watch = [Diagnostics.Stopwatch]::StartNew()
  while ($watch.Elapsed.TotalSeconds -lt $TimeoutSec -and -not $p.HasExited) {
    $buf = New-Object byte[] 16
    $rd = [IntPtr]::Zero
    if ([Q]::ReadProcessMemory($h, [IntPtr]($base + 0x1000), $buf, [IntPtr]16, [ref]$rd) -and $rd -eq 16) {
      $same = $true
      for ($i=0; $i -lt 16; $i++) { if ($buf[$i] -ne $enc[$i]) { $same = $false; break } }
      $hex = ($buf | ForEach-Object { $_.ToString('x2') }) -join ''
      if (-not $same) {
        Write-Output ("DECRYPTED at t=" + [int]$watch.Elapsed.TotalSeconds + "s first16=" + $hex)
        $state = "decrypted"; break
      } elseif ($n -eq 0 -or ($n % 20) -eq 0) {
        Write-Output ("t=" + [int]$watch.Elapsed.TotalSeconds + "s still-encrypted first16=" + $hex)
      }
    } else {
      Write-Output ("RPM_FAIL at t=" + [int]$watch.Elapsed.TotalSeconds + " err=" + [Runtime.InteropServices.Marshal]::GetLastWin32Error())
    }
    $n++
    Start-Sleep -Milliseconds 250
    $p.Refresh()
  }
  Write-Output ("STATE=" + $state)
  if ($state -eq "decrypted") {
    & powershell -NoProfile -ExecutionPolicy Bypass -File C:\Users\User\ModDump.ps1 -Name $Name -Out (Join-Path $OutDir "TslGame_map.bin") -WaitSec 5
    # raw snapshot of first 64MB too (covers .text start)
  }
} finally { [Q]::CloseHandle($h) | Out-Null }
Write-Output "=== FILES"
Get-ChildItem $OutDir | Select-Object Name,Length,LastWriteTime | Format-Table -AutoSize
