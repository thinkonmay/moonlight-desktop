@echo off
setlocal enableDelayedExpansion

rem Run from Qt command prompt with working directory set to root of repo

set BUILD_CONFIG=%1

rem Convert to lower case for windeployqt
if /I "%BUILD_CONFIG%"=="debug" (
    set BUILD_CONFIG=debug
    set WIX_MUMS=10
) else (
    if /I "%BUILD_CONFIG%"=="release" (
        set BUILD_CONFIG=release
        set WIX_MUMS=10
    ) else (
        if /I "%BUILD_CONFIG%"=="signed-release" (
            set BUILD_CONFIG=release
            set SIGN=1
            set MUST_DEPLOY_SYMBOLS=1

            rem Fail if there are unstaged changes
            git diff-index --quiet HEAD --
            if !ERRORLEVEL! NEQ 0 (
                echo Signed release builds must not have unstaged changes!
                exit /b 1
            )
        ) else (
            echo Invalid build configuration - expected 'debug' or 'release'
            echo Usage: scripts\build-arch.bat ^(release^|debug^)
            exit /b 1
        )
    )
)

rem Locate qmake and determine if we're using qmake.exe or qmake.bat
rem qmake.bat is an ARM64 forwarder to the x64 version of qmake.exe
where qmake.bat
if !ERRORLEVEL! EQU 0 (
    set QMAKE_CMD=call qmake.bat
) else (
    where qmake.exe
    if !ERRORLEVEL! EQU 0 (
        set QMAKE_CMD=qmake.exe
    ) else (
        echo Unable to find QMake. Did you add Qt bins to your PATH?
        goto Error
    )
)

rem Find Qt path to determine our architecture
for /F %%i in ('where qmake') do set QT_PATH=%%i

rem Strip the qmake filename off the end to get the Qt bin directory itself
set QT_PATH=%QT_PATH:\qmake.exe=%
set QT_PATH=%QT_PATH:\qmake.bat=%
set QT_PATH=%QT_PATH:\qmake.cmd=%

echo QT_PATH=%QT_PATH%
if not x%QT_PATH:_arm64=%==x%QT_PATH% (
    set ARCH=arm64

    rem Replace the _arm64 suffix with _64 to get the x64 bin path
    set HOSTBIN_PATH=%QT_PATH:_arm64=_64%
    echo HOSTBIN_PATH=!HOSTBIN_PATH!

    if exist %QT_PATH%\windeployqt.exe (
        echo Using windeployqt.exe from QT_PATH
        set WINDEPLOYQT_CMD=windeployqt.exe
    ) else (
        echo Using windeployqt.exe from HOSTBIN_PATH
        set WINDEPLOYQT_CMD=!HOSTBIN_PATH!\windeployqt.exe --qtpaths %QT_PATH%\qtpaths.bat
    )
) else (
    if not x%QT_PATH:_64=%==x%QT_PATH% (
        set ARCH=x64
        set WINDEPLOYQT_CMD=windeployqt.exe
    ) else (
        if not x%QT_PATH:msvc=%==x%QT_PATH% (
            set ARCH=x86
            set WINDEPLOYQT_CMD=windeployqt.exe
        ) else (
            echo Unable to determine Qt architecture
            goto Error
        )
    )
)

echo Detected target architecture: %ARCH%

set SIGNTOOL_PARAMS=sign /tr http://timestamp.digicert.com /td sha256 /fd sha256 /sha1 b28642b756ebec4884d1063dfa4de803a6dcecdc /v

set BUILD_ROOT=%cd%\build
set SOURCE_ROOT=%cd%
set BUILD_FOLDER=%BUILD_ROOT%\build-%ARCH%-%BUILD_CONFIG%
set DEPLOY_FOLDER=%BUILD_ROOT%\..\..\..\binary\moonlight
set /p VERSION=<%SOURCE_ROOT%\app\version.txt

rem Use the correct VC tools for the specified architecture
if /I "%ARCH%" EQU "x64" (
    rem x64 is a special case that doesn't match %PROCESSOR_ARCHITECTURE%
    set VC_ARCH=AMD64
) else (
    set VC_ARCH=%ARCH%
)

rem If we're not building for the current platform, use the cross compiling toolchain
if /I "%VC_ARCH%" NEQ "%PROCESSOR_ARCHITECTURE%" (
    set VC_ARCH=%PROCESSOR_ARCHITECTURE%_%VC_ARCH%
)

rem Find Visual Studio and run vcvarsall.bat
set VSWHERE="%SOURCE_ROOT%\scripts\vswhere.exe"
for /f "usebackq delims=" %%i in (`%VSWHERE% -latest -property installationPath`) do (
    call "%%i\VC\Auxiliary\Build\vcvarsall.bat" %VC_ARCH%
)
if !ERRORLEVEL! NEQ 0 goto Error

rem Find VC redistributable DLLs
for /f "usebackq delims=" %%i in (`%VSWHERE% -latest -find VC\Redist\MSVC\*\%ARCH%\Microsoft.VC*.CRT`) do set VC_REDIST_DLL_PATH=%%i

echo Cleaning output directories
rmdir /s /q %BUILD_FOLDER%
mkdir %BUILD_ROOT%
mkdir %BUILD_FOLDER%

echo Configuring the project
pushd %BUILD_FOLDER%
%QMAKE_CMD% %SOURCE_ROOT%\moonlight-qt.pro
if !ERRORLEVEL! NEQ 0 goto Error
popd

echo Compiling Moonlight in %BUILD_CONFIG% configuration
pushd %BUILD_FOLDER%
%SOURCE_ROOT%\scripts\jom.exe %BUILD_CONFIG%
if !ERRORLEVEL! NEQ 0 goto Error
popd

echo Copying application binary to deployment directory
copy %BUILD_FOLDER%\app\%BUILD_CONFIG%\Moonlight.exe %DEPLOY_FOLDER%
if !ERRORLEVEL! NEQ 0 goto Error

echo Build successful for Moonlight v%VERSION% %ARCH% binaries!
exit /b 0

:Error
echo Build failed!
exit /b !ERRORLEVEL!
