
sed -Enf win_build_env.sed <build_env_setup.bat >build_env_setup.sh
echo #!/bin/bash >build-win.sh
echo cd $(cygpath '%CD%') >>build-win.sh
echo export MSYSTEM=MINGW64 >>build-win.sh
echo . /etc/msystem >>build-win.sh
echo . build_env_setup.sh >>build-win.sh
REM This is such a hack, but installing in $BUILD_PREFIX/Library/bin is incorrect
REM for MSYS-based shells, as MSYS-2.0.dll will treat it as non-existent when referenced as /bin,
REM and cygpath will translate the explicit full path to /bin
REM Since make appears to trim the path when executing recipes, this is an expedient work-around
echo #mkdir -p ${BUILD_PREFIX}/Library/mingw64/bin >>build-win.sh
echo #cp -f "${BUILD_PREFIX}/Library/bin"/* "${BUILD_PREFIX}/Library/mingw64/bin/" >>build-win.sh
echo #mkdir -p "$PREFIX/Library/mingw64/bin" >>build-win.sh
echo #cp -f "${PREFIX}/Library/bin"/* "${PREFIX}/Library/mingw64/bin/" >>build-win.sh
echo exec ./build.sh >>build-win.sh
REM echo exec bash -i >>build-win.sh

echo set MSYSTEM=MINGW64 >build-win.bat
echo "%BUILD_PREFIX%\Library\usr\bin\bash.exe" -lec "$(cygpath '%CD%\build-win.sh')"  >>build-win.bat

REM set "bash=%BUILD_PREFIX%\Library\usr\bin\bash.exe"
REM Have to ensure only one cygwin/MSYS DLL is in use at a time
REM Use this line for debugging the bash shell invocation
rem start /W /I cmd.exe /K set MSYSTEM=MINGW64 & %bash%  -lc "cd $(cygpath '%CD%'); . /etc/msystem ; . build_env_setup.sh ; exec bash -i"
start /B /W /I cmd /c build-win.bat
