Set shell = CreateObject("WScript.Shell")
shell.Run "powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & Replace(WScript.ScriptFullName, "Start DeepSeek Harness.vbs", "Start-DeepSeek-Harness.ps1") & """ -ShowErrorDialog", 0, False
