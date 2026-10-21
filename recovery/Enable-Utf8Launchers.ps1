[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$ApplicationRoot)
$ErrorActionPreference = 'Stop'
$ApplicationRoot = (Resolve-Path -LiteralPath $ApplicationRoot).Path
if (-not ('RaoX.NativeManifest' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;
namespace RaoX {
 public static class NativeManifest {
  [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern IntPtr LoadLibraryEx(string path, IntPtr file, uint flags);
  [DllImport("kernel32.dll", SetLastError=true)] static extern bool FreeLibrary(IntPtr module);
  [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern IntPtr FindResource(IntPtr module, IntPtr name, IntPtr type);
  [DllImport("kernel32.dll", SetLastError=true)] static extern IntPtr LoadResource(IntPtr module, IntPtr resource);
  [DllImport("kernel32.dll", SetLastError=true)] static extern IntPtr LockResource(IntPtr resource);
  [DllImport("kernel32.dll", SetLastError=true)] static extern uint SizeofResource(IntPtr module, IntPtr resource);
  delegate bool LanguageCallback(IntPtr module, IntPtr type, IntPtr name, ushort language, IntPtr parameter);
  [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern bool EnumResourceLanguages(IntPtr module, IntPtr type, IntPtr name, LanguageCallback callback, IntPtr parameter);
  [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern IntPtr BeginUpdateResource(string path, bool deleteExisting);
  [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern bool UpdateResource(IntPtr update, IntPtr type, IntPtr name, ushort language, byte[] data, uint size);
  [DllImport("kernel32.dll", SetLastError=true)] static extern bool EndUpdateResource(IntPtr update, bool discard);
  static void Check(bool ok) { if (!ok) throw new Win32Exception(Marshal.GetLastWin32Error()); }
  public static string Read(string path) {
   IntPtr module = LoadLibraryEx(path, IntPtr.Zero, 2);
   if (module == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
   try {
    IntPtr resource = FindResource(module, (IntPtr)1, (IntPtr)24);
    if (resource == IntPtr.Zero) return "<assembly xmlns='urn:schemas-microsoft-com:asm.v1' manifestVersion='1.0'/>";
    byte[] data = new byte[SizeofResource(module, resource)];
    Marshal.Copy(LockResource(LoadResource(module, resource)), data, 0, data.Length);
    using (var reader = new System.IO.StreamReader(new System.IO.MemoryStream(data), Encoding.UTF8, true))
     return reader.ReadToEnd().TrimEnd('\0');
   } finally { FreeLibrary(module); }
  }
  public static void Write(string path, string xml) {
   var languages = new List<ushort>();
   IntPtr module = LoadLibraryEx(path, IntPtr.Zero, 2);
   if (module == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
   try { EnumResourceLanguages(module, (IntPtr)24, (IntPtr)1,
    (m,t,n,l,p) => { languages.Add(l); return true; }, IntPtr.Zero); }
   finally { FreeLibrary(module); }
   IntPtr update = BeginUpdateResource(path, false);
   if (update == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
   bool success = false;
   try {
    foreach (ushort language in languages) Check(UpdateResource(update, (IntPtr)24, (IntPtr)1, language, null, 0));
    byte[] data = Encoding.UTF8.GetBytes(xml);
    Check(UpdateResource(update, (IntPtr)24, (IntPtr)1, 0, data, (uint)data.Length));
    success = true;
   } finally { Check(EndUpdateResource(update, !success)); }
  }
 }
}
'@
}
$files = @(Get-Item -LiteralPath (Join-Path $ApplicationRoot 'eclipse.exe'),(Join-Path $ApplicationRoot 'eclipsec.exe')) +
    @(Get-ChildItem -LiteralPath (Join-Path $ApplicationRoot 'jre/bin') -Filter '*.exe' -File)
$changes = foreach ($file in $files) {
    $before = (Get-FileHash -LiteralPath $file.FullName).Hash.ToLowerInvariant()
    [xml]$manifest = [RaoX.NativeManifest]::Read($file.FullName)
    $v3 = 'urn:schemas-microsoft-com:asm.v3'
    $settingsNs = 'http://schemas.microsoft.com/SMI/2019/WindowsSettings'
    $application = $manifest.DocumentElement.SelectSingleNode("*[local-name()='application' and namespace-uri()='$v3']")
    if (-not $application) { $application = $manifest.CreateElement('application',$v3); $null = $manifest.DocumentElement.AppendChild($application) }
    $settings = $application.SelectSingleNode("*[local-name()='windowsSettings']")
    if (-not $settings) { $settings = $manifest.CreateElement('windowsSettings',$v3); $null = $application.AppendChild($settings) }
    $codePage = $settings.SelectSingleNode("*[local-name()='activeCodePage']")
    if (-not $codePage) { $codePage = $manifest.CreateElement('activeCodePage',$settingsNs); $null = $settings.AppendChild($codePage) }
    $codePage.InnerText = 'UTF-8'
    # Preserve all other resource entries, requested privileges and compatibility IDs.
    [RaoX.NativeManifest]::Write($file.FullName, $manifest.OuterXml)
    [ordered]@{ path=$file.FullName.Substring($ApplicationRoot.Length+1).Replace('\','/');
        upstream_sha256=$before; packaged_sha256=(Get-FileHash -LiteralPath $file.FullName).Hash.ToLowerInvariant() }
}
[ordered]@{ reason='Per-process UTF-8 activeCodePage for Windows 10 1903+; no system locale changes'; files=@($changes) } |
    ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $ApplicationRoot 'native-launchers.json') -Encoding utf8
Write-Output "Enabled per-process UTF-8 in $($files.Count) packaged launchers."
