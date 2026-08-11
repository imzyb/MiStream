@echo off
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"

rem 产物直接落到 quickjs_bindings.dart 的加载路径候选之一（lib/src/engine/），
rem 该目录下的 *.dll 全部被 .gitignore 排除，不入库。
set WRAPPER_SRC=%~dp0quickjs_wrapper.c
set WRAPPER_DLL=%~dp0..\lib\src\engine\quickjs_wrapper.dll

cl /LD /O2 /Fe:"%WRAPPER_DLL%" "%WRAPPER_SRC%" kernel32.lib user32.lib
