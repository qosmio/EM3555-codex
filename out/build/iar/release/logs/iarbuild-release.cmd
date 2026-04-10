@echo off
setlocal
set BUILD_STATUS=0
if exist "C:\Mac\Home\Documents\code\silabs\EM3555\build\iar\release\logs\iarbuild.exitcode" del /f /q "C:\Mac\Home\Documents\code\silabs\EM3555\build\iar\release\logs\iarbuild.exitcode" >nul 2>&1
if exist "C:\Mac\Home\Documents\code\silabs\EM3555\build\iar\release\logs\iarbuild.log" del /f /q "C:\Mac\Home\Documents\code\silabs\EM3555\build\iar\release\logs\iarbuild.log" >nul 2>&1
if exist "C:\Mac\Home\Documents\code\silabs\EM3555\build\iar\release\exe\em3555-rgbw.hex" del /f /q "C:\Mac\Home\Documents\code\silabs\EM3555\build\iar\release\exe\em3555-rgbw.hex" >nul 2>&1
if exist "C:\Mac\Home\Documents\code\silabs\EM3555\build\iar\release\exe\em3555-rgbw.s37" del /f /q "C:\Mac\Home\Documents\code\silabs\EM3555\build\iar\release\exe\em3555-rgbw.s37" >nul 2>&1
if "%BUILD_STATUS%"=="0" "C:\iar\ewarm-9.70.2\common\bin\iarbuild.exe" "C:\Mac\Home\Documents\code\silabs\EM3555\iar\em3555-rgbw.release.ewp" -make "Release" -parallel "4" -log "warnings" >> "C:\Mac\Home\Documents\code\silabs\EM3555\build\iar\release\logs\iarbuild.log" 2>&1
if errorlevel 1 set BUILD_STATUS=%ERRORLEVEL%
if "%BUILD_STATUS%"=="0" "C:\iar\ewarm-9.70.2\arm\bin\ielftool.exe" "C:\Mac\Home\Documents\code\silabs\EM3555\build\iar\release\exe\em3555-rgbw.out" --ihex "C:\Mac\Home\Documents\code\silabs\EM3555\build\iar\release\exe\em3555-rgbw.hex" >> "C:\Mac\Home\Documents\code\silabs\EM3555\build\iar\release\logs\iarbuild.log" 2>&1
if errorlevel 1 set BUILD_STATUS=%ERRORLEVEL%
if "%BUILD_STATUS%"=="0" "C:\iar\ewarm-9.70.2\arm\bin\ielftool.exe" "C:\Mac\Home\Documents\code\silabs\EM3555\build\iar\release\exe\em3555-rgbw.out" --srec --srec-s3only "C:\Mac\Home\Documents\code\silabs\EM3555\build\iar\release\exe\em3555-rgbw.s37" >> "C:\Mac\Home\Documents\code\silabs\EM3555\build\iar\release\logs\iarbuild.log" 2>&1
if errorlevel 1 set BUILD_STATUS=%ERRORLEVEL%
> "C:\Mac\Home\Documents\code\silabs\EM3555\build\iar\release\logs\iarbuild.exitcode" echo %BUILD_STATUS%
endlocal & exit /b %BUILD_STATUS%
