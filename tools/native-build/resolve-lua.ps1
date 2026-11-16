param([Parameter(Mandatory=$true)][string]$RuntimeDirectory)
Add-Type -TypeDefinition @'
using System;using System.Runtime.InteropServices;
public static class LuaSymbols {
 [DllImport("dbghelp.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool SymInitializeW(IntPtr h,string path,bool invade);
 [DllImport("dbghelp.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern ulong SymLoadModuleExW(IntPtr h,IntPtr file,string image,string module,ulong address,uint size,IntPtr data,uint flags);
 [DllImport("dbghelp.dll",CharSet=CharSet.Ansi,SetLastError=true)] static extern bool SymFromName(IntPtr h,string name,IntPtr symbol);
 [DllImport("dbghelp.dll")]static extern bool SymCleanup(IntPtr h);
 public static string Resolve(string dir){var handle=System.Diagnostics.Process.GetCurrentProcess().Handle;const ulong address=0x180000000;
  if(!SymInitializeW(handle,dir,false))throw new Exception("SymInitialize "+Marshal.GetLastWin32Error());
  try {if(SymLoadModuleExW(handle,IntPtr.Zero,dir+"\\UE4SS.dll","UE4SS",address,0,IntPtr.Zero,0)==0)throw new Exception("SymLoad "+Marshal.GetLastWin32Error());
   var result=new System.Text.StringBuilder();
   foreach(var name in new[]{"lua_gettop","lua_tointegerx","lua_tonumberx","lua_pushboolean","lua_pushinteger","lua_pushnumber","lua_pushstring","lua_pushcclosure","lua_createtable","lua_setfield","luaL_error"}){
    var buffer=Marshal.AllocHGlobal(1112);try{
     for(int i=0;i<1112;i++)Marshal.WriteByte(buffer,i,0);Marshal.WriteInt32(buffer,0,88);Marshal.WriteInt32(buffer,80,1024);
     if(!SymFromName(handle,"UE4SS!"+name,buffer))throw new Exception("Missing symbol "+name+" "+Marshal.GetLastWin32Error());
     ulong value=(ulong)Marshal.ReadInt64(buffer,56);result.AppendLine("#define RVA_"+name+" 0x"+(value-address).ToString("X")+"ULL");
    }finally{Marshal.FreeHGlobal(buffer);}
   }return result.ToString();
  }finally{SymCleanup(handle);}
 }
}
'@
[LuaSymbols]::Resolve($RuntimeDirectory) | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'lua-rvas.h')
Get-Content -LiteralPath (Join-Path $PSScriptRoot 'lua-rvas.h')
