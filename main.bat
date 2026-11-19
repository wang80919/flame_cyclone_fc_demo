@echo off

set IN_FILE_NAME=main.asm
set NESASM3=nesasm_Gui_3_2_x86.exe

set OUT_FILE_NAME=%~dp0
set OUT_FILE_NAME=%OUT_FILE_NAME:~0,-1%

for %%I in (%OUT_FILE_NAME%) do (
    set OUT_FILE_NAME=%%~nI.nes
)

cd /d %~dp0

rem call "%NESASM3%" %IN_FILE_NAME% -out "%OUT_FILE_NAME%"
call "%NESASM3%" %IN_FILE_NAME% -out "main.nes"
set result=%errorlevel%

IF 0 NEQ %result% (
    pause
) else (
    rem TODO
)

goto:eof