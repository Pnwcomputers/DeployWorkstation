@echo off
REM Compatibility launcher for users/docs that still invoke DeployWorkstation.cmd
REM Delegates to DeployWorkstation.bat in the same folder.
setlocal
set "script_dir=%~dp0"
call "%script_dir%DeployWorkstation.bat" %*
exit /b %errorlevel%
