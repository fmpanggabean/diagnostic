@echo off
setlocal EnableDelayedExpansion
title Post-Service Laptop Check (Windows 11)

rem Run as Administrator for full results.
net session >nul 2>&1
if errorlevel 1 echo [WARN] Not running as Administrator - some checks may be incomplete.
echo.

set "REPORT=%~dp0check_report_%COMPUTERNAME%.txt"
echo Post-service check - %DATE% %TIME% > "%REPORT%"

call :section "System info"
powershell -NoProfile -Command "Get-CimInstance Win32_ComputerSystem | Select Manufacturer,Model | Format-List; Get-CimInstance Win32_BIOS | Select SMBIOSBIOSVersion,SerialNumber | Format-List; Get-CimInstance Win32_Processor | Select Name | Format-List; '{0:N1} GB RAM' -f ((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB)" | call :tee

call :section "Disk health"
powershell -NoProfile -Command "Get-PhysicalDisk | Select FriendlyName,MediaType,HealthStatus,OperationalStatus,@{n='SizeGB';e={[int]($_.Size/1GB)}} | Format-Table -AutoSize | Out-String -Width 200" | call :tee

call :section "Battery"
powershell -NoProfile -Command "$b=Get-CimInstance Win32_Battery; if($b){$b | Select EstimatedChargeRemaining,BatteryStatus | Format-List}else{'No battery detected'}" | call :tee
powercfg /batteryreport /output "%~dp0battery_report.html" >nul 2>&1 && echo Battery report: %~dp0battery_report.html

call :section "Camera"
powershell -NoProfile -Command "$c=Get-PnpDevice -Class Camera,Image -ErrorAction SilentlyContinue; if($c){$c | Select Status,FriendlyName,InstanceId | Format-Table -AutoSize | Out-String -Width 200; if($c | ? Status -ne 'OK'){'RESULT: Camera device has a problem'}else{'RESULT: Camera device OK'}}else{'RESULT: NO CAMERA DETECTED'}" | call :tee
powershell -NoProfile -Command "$v=(Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam' -ErrorAction SilentlyContinue).Value; 'Camera privacy access: ' + $v" | call :tee
echo Opening Camera app for a visual test...
start "" microsoft.windows.camera:

call :section "Fingerprint / Windows Hello"
powershell -NoProfile -Command "$f=Get-PnpDevice -ErrorAction SilentlyContinue | ? { $_.FriendlyName -match 'fingerprint|biometric' }; if($f){$f | Select Status,FriendlyName,Class | Format-Table -AutoSize | Out-String -Width 200; if($f | ? Status -ne 'OK'){'RESULT: Fingerprint device has a problem'}else{'RESULT: Fingerprint device OK'}}else{'RESULT: NO FINGERPRINT READER DETECTED'}" | call :tee
sc query WbioSrvc | findstr /i "STATE" > "%TEMP%\wbio.txt"
type "%TEMP%\wbio.txt"
type "%TEMP%\wbio.txt" >> "%REPORT%"
del "%TEMP%\wbio.txt" >nul 2>&1
echo Opening Windows Hello fingerprint settings - enroll/test a finger there...
start "" ms-settings:signinoptions

call :section "Other devices with problems"
powershell -NoProfile -Command "$p=Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | ? { $_.Status -in 'Error','Degraded','Unknown' }; if($p){$p | Select Status,Class,FriendlyName | Format-Table -AutoSize | Out-String -Width 200}else{'None'}" | call :tee

call :section "Wi-Fi / Bluetooth"
powershell -NoProfile -Command "Get-NetAdapter | Select Name,Status,LinkSpeed | Format-Table -AutoSize | Out-String -Width 200; Get-PnpDevice -Class Bluetooth -ErrorAction SilentlyContinue | Select Status,FriendlyName | Format-Table -AutoSize | Out-String -Width 200" | call :tee

call :section "Audio"
powershell -NoProfile -Command "Get-PnpDevice -Class AudioEndpoint -PresentOnly -ErrorAction SilentlyContinue | Select Status,FriendlyName | Format-Table -AutoSize | Out-String -Width 200" | call :tee

call :section "Display / GPU"
powershell -NoProfile -Command "Get-CimInstance Win32_VideoController | Select Name,DriverVersion,CurrentHorizontalResolution,CurrentVerticalResolution | Format-List" | call :tee

call :section "Pending Windows updates / Activation"
cscript //nologo %windir%\system32\slmgr.vbs /xpr
echo.

echo ============================================================
echo Report saved to: %REPORT%
echo Manual checks: keyboard, trackpad, USB ports, speakers/mic, screen, hinges, fan noise.
echo ============================================================
pause
exit /b 0

:section
echo.
echo ===== %~1 =====
echo. >> "%REPORT%"
echo ===== %~1 ===== >> "%REPORT%"
exit /b 0

:tee
rem Reads stdin, prints it and appends to the report.
powershell -NoProfile -Command "$input | Tee-Object -FilePath '%REPORT%' -Append"
exit /b 0
