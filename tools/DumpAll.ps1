param([Parameter(Mandatory=$true)][int]$ProcId,[Parameter(Mandatory=$true)][string]$Out)
$ErrorActionPreference='Stop'
$cs=@'
using System; using System.IO; using System.Runtime.InteropServices; using System.Text;
public class AllDump {
 [StructLayout(LayoutKind.Sequential)] public struct MBI { public IntPtr BaseAddress; public IntPtr AllocationBase; public uint AllocationProtect; public IntPtr RegionSize; public uint State; public uint Protect; public uint Type; }
 [DllImport("kernel32.dll",SetLastError=true)] static extern IntPtr OpenProcess(uint a,bool i,int pid);
 [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool ReadProcessMemory(IntPtr h,IntPtr a,byte[] b,IntPtr s,out IntPtr r);
 [DllImport("kernel32.dll",SetLastError=true)] static extern IntPtr VirtualQueryEx(IntPtr h,IntPtr a,out MBI m,IntPtr l);
 public static string Run(int pid,string outPath){
  IntPtr h=OpenProcess(0x0410,false,pid);
  if(h==IntPtr.Zero) return "OPEN_FAIL err="+Marshal.GetLastWin32Error();
  var sb=new StringBuilder(); sb.Append("{\"pid\":"+pid+",\"regions\":[");
  var fs=new FileStream(outPath,FileMode.Create,FileAccess.Write);
  long total=0; int n=0; bool first=true;
  long addr=0;
  var buf=new byte[1<<20];
  try{
   while(true){
    MBI mbi;
    if(VirtualQueryEx(h,(IntPtr)addr,out mbi,(IntPtr)Marshal.SizeOf(typeof(MBI)))==IntPtr.Zero) break;
    long rbase=(long)mbi.BaseAddress; long rsize=(long)mbi.RegionSize;
    if(rsize<=0) break;
    bool readable = (mbi.State==0x1000) && ((mbi.Protect & 0x01)==0) && ((mbi.Protect & 0x100)==0);
    if(readable){
      long off=fs.Position;
      long dumped=0;
      long cur=rbase;
      while(cur<rbase+rsize){
        int want=(int)Math.Min((long)buf.Length, rbase+rsize-cur);
        IntPtr got;
        if(ReadProcessMemory(h,(IntPtr)cur,buf,(IntPtr)want,out got) && (long)got>0){ fs.Write(buf,0,(int)got); dumped+=(long)got; cur+=(long)got; }
        else { fs.Write(new byte[want],0,want); cur+=want; }
      }
      if(!first) sb.Append(",");
      first=false;
      sb.Append("{\"base\":"+rbase+",\"size\":"+rsize+",\"protect\":"+mbi.Protect+",\"file_off\":"+off+"}");
      n++; total+=dumped;
    }
    addr=rbase+rsize;
    if(addr<0) break;
   }
  } finally { fs.Dispose(); CloseHandle(h); }
  sb.Append("],\"regions_count\":"+n+",\"bytes\":"+total+"}");
  File.WriteAllText(outPath+".manifest.json",sb.ToString());
  return "OK regions="+n+" bytes="+total;
 }
}
'@
Add-Type -TypeDefinition $cs -Language CSharp
Write-Output ([AllDump]::Run($ProcId,$Out))
