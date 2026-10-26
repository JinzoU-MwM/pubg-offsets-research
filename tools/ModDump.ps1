param(
  [Parameter(Mandatory=$true)][string]$Name,
  [Parameter(Mandatory=$true)][string]$Out,
  [int]$WaitSec = 60,
  [switch]$Once
)
$ErrorActionPreference='Stop'
$cs = @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

public class ModDumper {
    [StructLayout(LayoutKind.Sequential)]
    public struct MEMORY_BASIC_INFORMATION {
        public IntPtr BaseAddress; public IntPtr AllocationBase; public uint AllocationProtect;
        public IntPtr RegionSize; public uint State; public uint Protect; public uint Type;
    }
    [DllImport("kernel32.dll", SetLastError=true)] static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, IntPtr size, out IntPtr read);
    [DllImport("kernel32.dll", SetLastError=true)] static extern IntPtr VirtualQueryEx(IntPtr h, IntPtr addr, out MEMORY_BASIC_INFORMATION mbi, IntPtr len);
    [DllImport("psapi.dll", SetLastError=true)] static extern bool EnumProcessModulesEx(IntPtr h, IntPtr[] mods, uint cb, out uint needed, uint filter);
    [DllImport("psapi.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern uint GetModuleBaseNameW(IntPtr h, IntPtr mod, StringBuilder name, uint size);
    [DllImport("psapi.dll", SetLastError=true)] static extern bool GetModuleInformation(IntPtr h, IntPtr mod, out MODULEINFO info, uint size);
    [StructLayout(LayoutKind.Sequential)] public struct MODULEINFO { public IntPtr lpBaseOfDll; public uint SizeOfImage; public IntPtr EntryPoint; }

    static bool IsReadable(uint p) {
        if ((p & 0x01) != 0) return false;          // PAGE_NOACCESS
        if ((p & 0x100) != 0) return false;         // PAGE_GUARD
        return true;
    }

    public static string Dump(int pid, string outPath, int waitSec) {
        var sw = Stopwatch.StartNew();
        IntPtr h = IntPtr.Zero;
        while (sw.Elapsed.TotalSeconds < waitSec) {
            h = OpenProcess(0x0010 | 0x0400 | 0x0008, false, pid); // VM_READ|QUERY_INFO|VM_OPERATION
            if (h != IntPtr.Zero) break;
            System.Threading.Thread.Sleep(50);
        }
        if (h == IntPtr.Zero) return "OPENPROCESS_FAIL err=" + Marshal.GetLastWin32Error();
        try {
            IntPtr[] mods = new IntPtr[1024];
            uint needed = 0;
            if (!EnumProcessModulesEx(h, mods, (uint)(mods.Length * IntPtr.Size), out needed, 0x03))
                return "ENUMMODULES_FAIL err=" + Marshal.GetLastWin32Error();
            int count = (int)(needed / (uint)IntPtr.Size);
            var sb = new StringBuilder();
            sb.AppendLine("{\"pid\":" + pid + ",\"modules\":[");
            IntPtr baseAddr = IntPtr.Zero; uint size = 0; string moduleName = "";
            for (int i = 0; i < count; i++) {
                var nm = new StringBuilder(512);
                GetModuleBaseNameW(h, mods[i], nm, 512);
                MODULEINFO mi; GetModuleInformation(h, mods[i], out mi, (uint)Marshal.SizeOf(typeof(MODULEINFO)));
                if (i > 0) sb.Append(",");
                sb.Append("{\"name\":\"" + nm.ToString().Replace("\\","\\\\") + "\",\"base\":" + ((long)mi.lpBaseOfDll) + ",\"size\":" + mi.SizeOfImage + "}");
                if (nm.ToString().Equals("TslGame.exe", StringComparison.OrdinalIgnoreCase) ||
                    nm.ToString().Equals("TslGame_ZK.exe", StringComparison.OrdinalIgnoreCase) ||
                    nm.ToString().Equals("zksvc.exe", StringComparison.OrdinalIgnoreCase) ||
                    moduleName == "") {
                    if (moduleName == "" || nm.ToString().StartsWith("TslGame")) {
                        if (moduleName == "" || nm.ToString().StartsWith("TslGame")) {
                            moduleName = nm.ToString(); baseAddr = mi.lpBaseOfDll; size = mi.SizeOfImage;
                        }
                    }
                }
            }
            sb.AppendLine("],\"dumped_module\":\"" + moduleName + "\",\"base\":" + ((long)baseAddr) + ",\"size\":" + size + ",\"regions\":[");
            if (size == 0) { CloseHandle(h); return "MODULE_NOT_FOUND"; }

            var fs = new FileStream(outPath, FileMode.Create, FileAccess.Write, FileShare.None, 1 << 20);
            try {
                fs.SetLength((long)size);
                long dumped = 0, skipped = 0; int regions = 0; bool first = true;
                long end = (long)baseAddr + size;
                for (long addr = (long)baseAddr; addr < end; ) {
                    MEMORY_BASIC_INFORMATION mbi;
                    if (VirtualQueryEx(h, (IntPtr)addr, out mbi, (IntPtr)Marshal.SizeOf(typeof(MEMORY_BASIC_INFORMATION))) == IntPtr.Zero) break;
                    long rbase = (long)mbi.BaseAddress; long rsize = (long)mbi.RegionSize;
                    long rend = Math.Min(rbase + rsize, end);
                    if (rbase < (long)baseAddr) { addr = rend; continue; }
                    bool readable = mbi.State == 0x1000 && IsReadable(mbi.Protect);
                    if (!first) sb.Append(",");
                    first = false;
                    sb.Append("{\"rva\":" + (rbase - (long)baseAddr) + ",\"size\":" + (rend - rbase) + ",\"protect\":" + mbi.Protect + ",\"readable\":" + (readable ? "true" : "false") + "}");
                    regions++;
                    if (readable) {
                        byte[] buf = new byte[1 << 20];
                        long cur = rbase;
                        while (cur < rend) {
                            int want = (int)Math.Min((long)buf.Length, rend - cur);
                            IntPtr got;
                            if (ReadProcessMemory(h, (IntPtr)cur, buf, (IntPtr)want, out got) && (long)got > 0) {
                                fs.Position = cur - (long)baseAddr;
                                fs.Write(buf, 0, (int)got);
                                dumped += (long)got; cur += (long)got;
                            } else { skipped += want; cur += want; }
                        }
                    } else skipped += (rend - rbase);
                    addr = rend;
                }
                sb.AppendLine("],\"dumped_bytes\":" + dumped + ",\"skipped_bytes\":" + skipped + ",\"regions_count\":" + regions + "}");
                File.WriteAllText(outPath + ".manifest.json", sb.ToString());
                return "OK module=" + moduleName + " base=0x" + ((long)baseAddr).ToString("x") + " size=" + size + " dumped=" + dumped + " skipped=" + skipped + " regions=" + regions;
            } finally { fs.Dispose(); }
        } finally { CloseHandle(h); }
    }
}
'@
Add-Type -TypeDefinition $cs -Language CSharp
$p = Get-Process -Name $Name -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $p) {
  $deadline = (Get-Date).AddSeconds($WaitSec)
  while ((Get-Date) -lt $deadline -and -not $p) { Start-Sleep -Milliseconds 100; $p = Get-Process -Name $Name -ErrorAction SilentlyContinue | Select-Object -First 1 }
}
if (-not $p) { Write-Output "PROCESS_NOT_FOUND: $Name"; exit 2 }
Write-Output ("TARGET pid=" + $p.Id + " name=" + $p.Name)
Write-Output ([ModDumper]::Dump([int]$p.Id, $Out, $WaitSec))
