@echo off
rem Builds the MSVC ABI shim (quickjs_wrapper.dll) that Dart FFI binds to.
rem Rationale, layout constraints and the JSValue boundary rule: see README.md.
rem
rem ASCII only on purpose. cmd reads .bat in the OEM codepage (936 on zh-CN),
rem so UTF-8 comments get mis-decoded, split mid-line and then executed as
rem commands -- which is how this script used to die with a bogus
rem "'xxx' is not recognized as an internal or external command".

setlocal

set "VCVARS="
for %%P in (
  "%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
  "%ProgramFiles%\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
  "%ProgramFiles%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
  "%ProgramFiles%\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvars64.bat"
  "%ProgramFiles%\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvars64.bat"
) do if not defined VCVARS if exist %%P set "VCVARS=%%~P"

if not defined VCVARS (
  echo [build] vcvars64.bat not found. Install VS 2022 Build Tools ^(C++ workload^).
  exit /b 1
)

call "%VCVARS%" >nul || (echo [build] vcvars64 failed & exit /b 1)

set "SRC=%~dp0quickjs_wrapper.c"
set "OUT=%~dp0..\lib\src\engine\quickjs_wrapper.dll"

rem Intermediates land in a scratch dir: cl drops .obj/.lib/.exp next to the
rem working directory otherwise, and neither the repo root nor lib/src/engine
rem should collect build litter.
set "OBJDIR=%TEMP%\mistream_qjs_wrapper"
if not exist "%OBJDIR%" mkdir "%OBJDIR%"

cl /nologo /LD /O2 /W3 ^
   /Fo"%OBJDIR%\\" /Fd"%OBJDIR%\\" ^
   /Fe:"%OUT%" "%SRC%" kernel32.lib user32.lib ^
   /link /IMPLIB:"%OBJDIR%\quickjs_wrapper.lib"
if errorlevel 1 (
  echo [build] compilation failed
  exit /b 1
)

echo [build] ok: %OUT%
endlocal
