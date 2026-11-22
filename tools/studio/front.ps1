Add-Type @"
using System;using System.Runtime.InteropServices;
public class WF{[DllImport("user32.dll")]public static extern bool SetForegroundWindow(IntPtr h);[DllImport("user32.dll")]public static extern bool ShowWindow(IntPtr h,int c);[DllImport("user32.dll")]public static extern void keybd_event(byte a,byte b,int c,int d);}
"@
$p=Get-Process RobloxStudioBeta | ? MainWindowHandle -ne 0 | select -First 1
[WF]::keybd_event(0x12,0,0,0);[WF]::keybd_event(0x12,0,2,0)
[WF]::ShowWindow($p.MainWindowHandle,3)|Out-Null;[WF]::SetForegroundWindow($p.MainWindowHandle)
