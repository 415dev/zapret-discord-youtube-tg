@echo off
set "LOCAL_VERSION=2.0.1b"

:: External commands
if "%~1"=="status_zapret" (
    call :test_service zapret soft
    call :tcp_enable
    exit /b
)

if "%~1"=="check_updates" (
    if defined NO_UPDATE_CHECK exit /b

    if exist "%~dp0utils\check_updates.enabled" (
        if not "%~2"=="soft" (
            start /b service check_updates soft
        ) else (
            call :service_check_updates soft
        )
    )

    exit /b
)

if "%~1"=="load_game_filter" (
    call :game_switch_status
    exit /b
)

if "%~1"=="load_user_lists" (
    call :load_user_lists
    exit /b
)

if "%~1"=="load_lists_filter" (
    call :load_lists_filter
    exit /b
)

if "%~1"=="tgproxy_quickstart" (
    call :tgproxy_quickstart
    exit /b
)

if "%1"=="admin" (
    call :check_command chcp
    call :check_command find
    call :check_command findstr
    call :check_command netsh
    
    call :load_user_lists

    echo Started with admin rights
) else (
    call :check_extracted
    call :check_command powershell

    echo Requesting admin rights...
    powershell -NoProfile -Command "Start-Process 'cmd.exe' -ArgumentList '/c \"\"%~f0\" admin\"' -Verb RunAs"
    exit
)


:: MENU ================================
setlocal EnableDelayedExpansion
:menu
cls
call :ipset_switch_status
call :game_switch_status
call :check_updates_switch_status
call :lists_filter_status
call :get_strategy_name
call :tgproxy_load_config

set "menu_choice=null"

echo.
echo   ZAPRET SERVICE AND TGWSPROXY MANAGER v!LOCAL_VERSION! ^ 
echo.  !CurrentStrategy!
echo   ----------------------------------------
echo.
echo   :: SERVICES
echo      1. Install Service [ZAPRET]              4. Install Service [TGWSPROXY]
echo      2. Remove Services [ZAPRET]              5. Remove Services [TGWSPROXY]
echo      3. Check Status [ZAPRET]                 6. Check Status [TGWSPROXY]
echo.
echo   :: SETTINGS[ZAPRET]                         :: SETTINGS[TGWSPROXY]

set "SP=                                                  "
set "LINE=     7. Game Filter       [!GameFilterStatus!]!SP!"
echo !LINE:~0,44!11. Set Port      [!TGP_PORT!]
set "LINE=     8. IPSet Filter      [!IPsetStatus!]!SP!"
echo !LINE:~0,44!12. Set IP / Host [!TGP_HOST!]
set "LINE=     9. Auto-Update Check [!CheckUpdatesStatus!]!SP!"
echo !LINE:~0,44!13. Set DC IPs    [!TGP_DCIP!]
set "LINE=     10. Lists Filter     [!LISTS_FILTER_STATUS!]!SP!"
echo !LINE:~0,44!14. Show / Copy Link
echo.
echo   :: UPDATES
echo      15. Update IPSet List
echo      16. Update Hosts File
echo      17. Check for Updates
echo.
echo   :: TOOLS
echo      18. Run Diagnostics
echo      19. Run Tests
echo.
echo   ----------------------------------------
echo      0. Exit
echo.

set /p menu_choice=   Select option (0-19):

if "%menu_choice%"=="1" goto service_install
if "%menu_choice%"=="2" goto service_remove
if "%menu_choice%"=="3" goto service_status
if "%menu_choice%"=="4" goto tgproxy_service_install
if "%menu_choice%"=="5" goto tgproxy_service_remove
if "%menu_choice%"=="6" goto tgproxy_status_menu
if "%menu_choice%"=="7" goto game_switch
if "%menu_choice%"=="8" goto ipset_switch
if "%menu_choice%"=="9" goto check_updates_switch
if "%menu_choice%"=="10" goto lists_filter
if "%menu_choice%"=="11" goto tgproxy_set_port
if "%menu_choice%"=="12" goto tgproxy_set_host
if "%menu_choice%"=="13" goto tgproxy_set_dcip
if "%menu_choice%"=="14" goto tgproxy_link
if "%menu_choice%"=="15" goto ipset_update
if "%menu_choice%"=="16" goto hosts_update
if "%menu_choice%"=="17" goto service_check_updates
if "%menu_choice%"=="18" goto service_diagnostics
if "%menu_choice%"=="19" goto run_tests
if "%menu_choice%"=="0" exit /b
goto menu


:: LOAD USER LISTS =====================
:load_user_lists
set "LISTS_PATH=%~dp0lists\"

if not exist "%LISTS_PATH%ipset-exclude-user.txt" (
    echo 203.0.113.113/32>"%LISTS_PATH%ipset-exclude-user.txt"
)
if not exist "%LISTS_PATH%list-general-user.txt" (
    echo domain.example.abc>"%LISTS_PATH%list-general-user.txt"
)
if not exist "%LISTS_PATH%list-exclude-user.txt" (
    echo domain.example.abc>"%LISTS_PATH%list-exclude-user.txt"
)

exit /b


:: LOAD LISTS FILTER ====================
:load_lists_filter
setlocal EnableDelayedExpansion
set "LISTS_PATH=%~dp0lists\"
set "listsConf=%~dp0utils\lists.conf"
set "activeList=%LISTS_PATH%list-active.txt"

break > "%activeList%"
if exist "%listsConf%" (
    for /f "usebackq eol=# delims=" %%N in ("%listsConf%") do (
        set "ln=%%N"
        if not "!ln!"=="" if exist "%LISTS_PATH%list-!ln!.txt" (
            type "%LISTS_PATH%list-!ln!.txt" >> "%activeList%"
        )
    )
)
for %%S in ("%activeList%") do if %%~zS EQU 0 echo domain.example.abc> "%activeList%"
endlocal
exit /b


:: TCP ENABLE ==========================
:tcp_enable
chcp 437 > nul
netsh interface tcp show global | findstr /i "timestamps" | findstr /i "enabled" > nul || netsh interface tcp set global timestamps=enabled > nul 2>&1
exit /b


:: STATUS ==============================
:service_status
cls
chcp 437 > nul

sc query "zapret" >nul 2>&1
if !errorlevel!==0 (
    for /f "tokens=2*" %%A in ('reg query "HKLM\System\CurrentControlSet\Services\zapret" /v zapret-discord-youtube 2^>nul') do echo Service strategy installed from "%%B"
)

call :test_service zapret
call :test_service WinDivert

set "BIN_PATH=%~dp0bin\"
if not exist "%BIN_PATH%\*.sys" (
    call :PrintRed "WinDivert64.sys file NOT found."
)
echo:

tasklist /FI "IMAGENAME eq winws.exe" | find /I "winws.exe" > nul
if !errorlevel!==0 (
    call :PrintGreen "Bypass (winws.exe) is RUNNING."
) else (
    call :PrintRed "Bypass (winws.exe) is NOT running."
)

pause
goto menu

:test_service
set "ServiceName=%~1"
set "ServiceStatus="

for /f "tokens=3 delims=: " %%A in ('sc query "%ServiceName%" ^| findstr /i "STATE"') do set "ServiceStatus=%%A"
set "ServiceStatus=%ServiceStatus: =%"

if "%ServiceStatus%"=="RUNNING" (
    if "%~2"=="soft" (
        echo "%ServiceName%" is ALREADY RUNNING as service, use "service.bat" and choose "Remove Services" first if you want to run standalone bat.
        pause
        exit /b
    ) else (
        echo "%ServiceName%" service is RUNNING.
    )
) else if "%ServiceStatus%"=="STOP_PENDING" (
    call :PrintYellow "!ServiceName! is STOP_PENDING, that may be caused by a conflict with another bypass. Run Diagnostics to try to fix conflicts"
) else if not "%~2"=="soft" (
    echo "%ServiceName%" service is NOT running.
)

exit /b


:: REMOVE ==============================
:service_remove
cls
chcp 65001 > nul

set SRVCNAME=zapret
sc query "!SRVCNAME!" >nul 2>&1
if !errorlevel!==0 (
    net stop %SRVCNAME%
    sc delete %SRVCNAME%
) else (
    echo Service "%SRVCNAME%" is not installed.
)

tasklist /FI "IMAGENAME eq winws.exe" | find /I "winws.exe" > nul
if !errorlevel!==0 (
    taskkill /IM winws.exe /F > nul
)

sc query "WinDivert" >nul 2>&1
if !errorlevel!==0 (
    net stop "WinDivert"

    sc query "WinDivert" >nul 2>&1
    if !errorlevel!==0 (
        sc delete "WinDivert"
    )
)
net stop "WinDivert14" >nul 2>&1
sc delete "WinDivert14" >nul 2>&1

pause
goto menu


:: INSTALL =============================
:service_install
cls
chcp 437 > nul

:: Main
cd /d "%~dp0"
set "BIN_PATH=%~dp0bin\"
set "LISTS_PATH=%~dp0lists\"

:: Searching for .bat files in current folder, except files that start with "service"
echo Pick one of the options:
set "count=0"
for /f "delims=" %%F in ('powershell -NoProfile -Command "Get-ChildItem -LiteralPath '.' -Filter '*.bat' | Where-Object { $_.Name -notlike 'service*' -and $_.Name -ne 'tgwsproxy.bat' } | Sort-Object { [Regex]::Replace($_.Name, '(\d+)', { $args[0].Value.PadLeft(8, '0') }) } | ForEach-Object { $_.Name }"') do (
    set /a count+=1
    echo !count!. %%F
    set "file!count!=%%F"
)

:: Choosing file
set "choice="
set /p "choice=Input file index (number): "
if "!choice!"=="" (
    echo The choice is empty, exiting...
    pause
    goto menu
)

set "selectedFile=!file%choice%!"
if not defined selectedFile (
    echo Invalid choice, exiting...
    pause
    goto menu
)

:: Args that should be followed by value
set "args_with_value=sni host altorder"

:: Parsing args (mergeargs: 2=start param|3=arg with value|1=params args|0=default)
set "args="
set "capture=0"
set "mergeargs=0"
set QUOTE="

for /f "tokens=*" %%a in ('type "!selectedFile!"') do (
    set "line=%%a"
    call set "line=%%line:^!=EXCL_MARK%%"

    echo !line! | findstr /i "%BIN%winws.exe" >nul
    if not errorlevel 1 (
        set "capture=1"
    )

    if !capture!==1 (
        if not defined args (
            set "line=!line:*%BIN%winws.exe"=!"
        )

        set "temp_args="
        for %%i in (!line!) do (
            set "arg=%%i"

            if not "!arg!"=="^" (
                if "!arg:~0,2!" EQU "--" if not !mergeargs!==0 (
                    set "mergeargs=0"
                )

                if "!arg:~0,1!" EQU "!QUOTE!" (
                    set "arg=!arg:~1,-1!"

                    echo !arg! | findstr ":" >nul
                    if !errorlevel!==0 (
                        set "arg=\!QUOTE!!arg!\!QUOTE!"
                    ) else if "!arg:~0,1!"=="@" (
                        set "arg=\!QUOTE!@%~dp0!arg:~1!\!QUOTE!"
                    ) else if "!arg:~0,5!"=="%%BIN%%" (
                        set "arg=\!QUOTE!!BIN_PATH!!arg:~5!\!QUOTE!"
                    ) else if "!arg:~0,7!"=="%%LISTS%%" (
                        set "arg=\!QUOTE!!LISTS_PATH!!arg:~7!\!QUOTE!"
                    ) else (
                        set "arg=\!QUOTE!%~dp0!arg!\!QUOTE!"
                    )
                ) else if "!arg:~0,12!" EQU "%%GameFilter%%" (
                    set "arg=%GameFilter%"
                ) else if "!arg:~0,15!" EQU "%%GameFilterTCP%%" (
                    set "arg=%GameFilterTCP%"
                ) else if "!arg:~0,15!" EQU "%%GameFilterUDP%%" (
                    set "arg=%GameFilterUDP%"
                )

                if !mergeargs!==1 (
                    set "temp_args=!temp_args!,!arg!"
                ) else if !mergeargs!==3 (
                    set "temp_args=!temp_args!=!arg!"
                    set "mergeargs=1"
                ) else (
                    set "temp_args=!temp_args! !arg!"
                )

                if "!arg:~0,2!" EQU "--" (
                    set "mergeargs=2"
                ) else if !mergeargs! GEQ 1 (
                    if !mergeargs!==2 set "mergeargs=1"

                    for %%x in (!args_with_value!) do (
                        if /i "%%x"=="!arg!" (
                            set "mergeargs=3"
                        )
                    )
                )
            )
        )

        if not "!temp_args!"=="" (
            set "args=!args! !temp_args!"
        )
    )
)

:: Creating service with parsed args
call :tcp_enable

set ARGS=%args%
call set "ARGS=%%ARGS:EXCL_MARK=^!%%"
echo Final args: !ARGS!
set SRVCNAME=zapret

net stop %SRVCNAME% >nul 2>&1
sc delete %SRVCNAME% >nul 2>&1
sc create %SRVCNAME% binPath= "\"%BIN_PATH%winws.exe\" !ARGS!" DisplayName= "zapret" start= auto
sc description %SRVCNAME% "Zapret DPI bypass software"
sc start %SRVCNAME%
for %%F in ("!file%choice%!") do (
    set "filename=%%~nF"
)
reg add "HKLM\System\CurrentControlSet\Services\zapret" /v zapret-discord-youtube /t REG_SZ /d "!filename!" /f

pause
goto menu


:: CHECK UPDATES =======================
:service_check_updates
chcp 437 > nul
cls

:: Set current version and URLs
set "GITHUB_VERSION_URL=https://raw.githubusercontent.com/415dev/zapret-discord-youtube-tg/main/.service/version.txt"
set "GITHUB_RELEASE_URL=https://github.com/Flowseal/zapret-discord-youtube/releases/tag/"
set "GITHUB_DOWNLOAD_URL=https://github.com/Flowseal/zapret-discord-youtube/releases/latest"

:: Get the latest version from GitHub
for /f "delims=" %%A in ('powershell -NoProfile -Command "(Invoke-WebRequest -Uri \"%GITHUB_VERSION_URL%\" -Headers @{\"Cache-Control\"=\"no-cache\"} -UseBasicParsing -TimeoutSec 5).Content.Trim()" 2^>nul') do set "GITHUB_VERSION=%%A"

:: Error handling
if not defined GITHUB_VERSION (
    echo Warning: failed to fetch the latest version. This warning does not affect the operation of zapret
    timeout /T 9
    if "%1"=="soft" exit 
    goto menu
)

:: Version comparison
if "%LOCAL_VERSION%"=="%GITHUB_VERSION%" (
    echo Latest version installed: %LOCAL_VERSION%
    
    if "%1"=="soft" exit 
    pause
    goto menu
) 

echo New version available: %GITHUB_VERSION%
echo Release page: %GITHUB_RELEASE_URL%%GITHUB_VERSION%

echo Opening the download page...
start "" "%GITHUB_DOWNLOAD_URL%"


if "%1"=="soft" exit 
pause
goto menu



:: DIAGNOSTICS =========================
:service_diagnostics
chcp 437 > nul
cls

:: Base Filtering Engine
sc query BFE | findstr /I "RUNNING" > nul
if !errorlevel!==0 (
    call :PrintGreen "Base Filtering Engine check passed"
) else (
    call :PrintRed "[X] Base Filtering Engine is not running. This service is required for zapret to work"
)
echo:

:: Proxy check
set "proxyEnabled=0"
set "proxyServer="

for /f "tokens=2*" %%A in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable 2^>nul ^| findstr /i "ProxyEnable"') do (
    if "%%B"=="0x1" set "proxyEnabled=1"
)

if !proxyEnabled!==1 (
    for /f "tokens=2*" %%A in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer 2^>nul ^| findstr /i "ProxyServer"') do (
        set "proxyServer=%%B"
    )
    
    call :PrintYellow "[?] System proxy is enabled: !proxyServer!"
    call :PrintYellow "Make sure it's valid or disable it if you don't use a proxy"
) else (
    call :PrintGreen "Proxy check passed"
)
echo:

:: TCP timestamps check
netsh interface tcp show global | findstr /i "timestamps" | findstr /i "enabled" > nul
if !errorlevel!==0 (
    call :PrintGreen "TCP timestamps check passed"
) else (
    call :PrintYellow "[?] TCP timestamps are disabled. Enabling timestamps..."
    netsh interface tcp set global timestamps=enabled > nul 2>&1
    if !errorlevel!==0 (
        call :PrintGreen "TCP timestamps successfully enabled"
    ) else (
        call :PrintRed "[X] Failed to enable TCP timestamps"
    )
)
echo:

:: AdguardSvc.exe
tasklist /FI "IMAGENAME eq AdguardSvc.exe" | find /I "AdguardSvc.exe" > nul
if !errorlevel!==0 (
    call :PrintRed "[X] Adguard process found. Adguard may cause problems with Discord"
    call :PrintRed "https://github.com/Flowseal/zapret-discord-youtube/issues/417"
) else (
    call :PrintGreen "Adguard check passed"
)
echo:

:: Killer
sc query | findstr /I "Killer" > nul
if !errorlevel!==0 (
    call :PrintRed "[X] Killer services found. Killer conflicts with zapret"
    call :PrintRed "https://github.com/Flowseal/zapret-discord-youtube/issues/2512#issuecomment-2821119513"
) else (
    call :PrintGreen "Killer check passed"
)
echo:

:: Intel Connectivity Network Service
sc query | findstr /I "Intel" | findstr /I "Connectivity" | findstr /I "Network" > nul
if !errorlevel!==0 (
    call :PrintRed "[X] Intel Connectivity Network Service found. It conflicts with zapret"
    call :PrintRed "https://github.com/ValdikSS/GoodbyeDPI/issues/541#issuecomment-2661670982"
) else (
    call :PrintGreen "Intel Connectivity check passed"
)
echo:

:: Check Point
set "checkpointFound=0"
sc query | findstr /I "TracSrvWrapper" > nul
if !errorlevel!==0 (
    set "checkpointFound=1"
)

sc query | findstr /I "EPWD" > nul
if !errorlevel!==0 (
    set "checkpointFound=1"
)

if !checkpointFound!==1 (
    call :PrintRed "[X] Check Point services found. Check Point conflicts with zapret"
    call :PrintRed "Try to uninstall Check Point"
) else (
    call :PrintGreen "Check Point check passed"
)
echo:

:: SmartByte
sc query | findstr /I "SmartByte" > nul
if !errorlevel!==0 (
    call :PrintRed "[X] SmartByte services found. SmartByte conflicts with zapret"
    call :PrintRed "Try to uninstall or disable SmartByte through services.msc"
) else (
    call :PrintGreen "SmartByte check passed"
)
echo:

:: WinDivert64.sys file
set "BIN_PATH=%~dp0bin\"
if not exist "%BIN_PATH%\*.sys" (
    call :PrintRed "WinDivert64.sys file NOT found."
    echo:
)

:: VPN
set "VPN_SERVICES="
sc query | findstr /I "VPN" > nul
if !errorlevel!==0 (
    for /f "tokens=2 delims=:" %%A in ('sc query ^| findstr /I "VPN"') do (
        if not defined VPN_SERVICES (
            set "VPN_SERVICES=!VPN_SERVICES!%%A"
        ) else (
            set "VPN_SERVICES=!VPN_SERVICES!,%%A"
        )
    )
    call :PrintYellow "[?] VPN services found:!VPN_SERVICES!. Some VPNs can conflict with zapret"
    call :PrintYellow "Make sure that all VPNs are disabled"
) else (
    call :PrintGreen "VPN check passed"
)
echo:

:: DNS
set "dohfound=0"
for /f "delims=" %%a in ('powershell -NoProfile -Command "Get-ChildItem -Recurse -Path 'HKLM:System\CurrentControlSet\Services\Dnscache\InterfaceSpecificParameters\' | Get-ItemProperty | Where-Object { $_.DohFlags -gt 0 } | Measure-Object | Select-Object -ExpandProperty Count"') do (
    if %%a gtr 0 (
        set "dohfound=1"
    )
)
if !dohfound!==0 (
    call :PrintYellow "[?] Make sure you have configured secure DNS in a browser with some non-default DNS service provider,"
    call :PrintYellow "If you use Windows 11 you can configure encrypted DNS in the Settings to hide this warning"
) else (
    call :PrintGreen "Secure DNS check passed"
)
echo:

:: Hosts file check
set "hostsFile=%SystemRoot%\System32\drivers\etc\hosts"
if exist "%hostsFile%" (
    set "yt_found=0"
    >nul 2>&1 findstr /I "youtube.com" "%hostsFile%" && set "yt_found=1"
    >nul 2>&1 findstr /I "youtu.be" "%hostsFile%" && set "yt_found=1"
    if !yt_found!==1 (
        call :PrintYellow "[?] Your hosts file contains entries for youtube.com or youtu.be. This may cause problems with YouTube access"
    )
)

:: WinDivert conflict
tasklist /FI "IMAGENAME eq winws.exe" | find /I "winws.exe" > nul
set "winws_running=!errorlevel!"

sc query "WinDivert" | findstr /I "RUNNING STOP_PENDING" > nul
set "windivert_running=!errorlevel!"

if !winws_running! neq 0 if !windivert_running!==0 (
    call :PrintYellow "[?] winws.exe is not running but WinDivert service is active. Attempting to delete WinDivert..."
    
    net stop "WinDivert" >nul 2>&1
    sc delete "WinDivert" >nul 2>&1
    sc query "WinDivert" >nul 2>&1
    if !errorlevel!==0 (
        call :PrintRed "[X] Failed to delete WinDivert. Checking for conflicting services..."
        
        set "conflicting_services=GoodbyeDPI"
        set "found_conflict=0"
        
        for %%s in (!conflicting_services!) do (
            sc query "%%s" >nul 2>&1
            if !errorlevel!==0 (
                call :PrintYellow "[?] Found conflicting service: %%s. Stopping and removing..."
                net stop "%%s" >nul 2>&1
                sc delete "%%s" >nul 2>&1
                if !errorlevel!==0 (
                    call :PrintGreen "Successfully removed service: %%s"
                ) else (
                    call :PrintRed "[X] Failed to remove service: %%s"
                )
                set "found_conflict=1"
            )
        )
        
        if !found_conflict!==0 (
            call :PrintRed "[X] No conflicting services found. Check manually if any other bypass is using WinDivert."
        ) else (
            call :PrintYellow "[?] Attempting to delete WinDivert again..."

            net stop "WinDivert" >nul 2>&1
            sc delete "WinDivert" >nul 2>&1
            sc query "WinDivert" >nul 2>&1
            if !errorlevel! neq 0 (
                call :PrintGreen "WinDivert successfully deleted after removing conflicting services"
            ) else (
                call :PrintRed "[X] WinDivert still cannot be deleted. Check manually if any other bypass is using WinDivert."
            )
        )
    ) else (
        call :PrintGreen "WinDivert successfully removed"
    )
    
    echo:
)

:: Conflicting bypasses
set "conflicting_services=GoodbyeDPI discordfix_zapret winws1 winws2"
set "found_any_conflict=0"
set "found_conflicts="

for %%s in (!conflicting_services!) do (
    sc query "%%s" >nul 2>&1
    if !errorlevel!==0 (
        if "!found_conflicts!"=="" (
            set "found_conflicts=%%s"
        ) else (
            set "found_conflicts=!found_conflicts! %%s"
        )
        set "found_any_conflict=1"
    )
)

if !found_any_conflict!==1 (
    call :PrintRed "[X] Conflicting bypass services found: !found_conflicts!"
    
    set "CHOICE="
    set /p "CHOICE=Do you want to remove these conflicting services? (Y/N) (default: N) "
    if "!CHOICE!"=="" set "CHOICE=N"
    if "!CHOICE!"=="y" set "CHOICE=Y"
    
    if /i "!CHOICE!"=="Y" (
        for %%s in (!found_conflicts!) do (
            call :PrintYellow "Stopping and removing service: %%s"
            net stop "%%s" >nul 2>&1
            sc delete "%%s" >nul 2>&1
            if !errorlevel!==0 (
                call :PrintGreen "Successfully removed service: %%s"
            ) else (
                call :PrintRed "[X] Failed to remove service: %%s"
            )
        )

        net stop "WinDivert" >nul 2>&1
        sc delete "WinDivert" >nul 2>&1
        net stop "WinDivert14" >nul 2>&1
        sc delete "WinDivert14" >nul 2>&1
    )
    
    echo:
)

:: Discord cache clearing
set "CHOICE="
set /p "CHOICE=Do you want to clear the Discord cache? (Y/N) (default: Y)  "
if "!CHOICE!"=="" set "CHOICE=Y"
if "!CHOICE!"=="y" set "CHOICE=Y"

if /i "!CHOICE!"=="Y" (
    tasklist /FI "IMAGENAME eq Discord.exe" | findstr /I "Discord.exe" > nul
    if !errorlevel!==0 (
        echo Discord is running, closing...
        taskkill /IM Discord.exe /F > nul
        if !errorlevel! == 0 (
            call :PrintGreen "Discord was successfully closed"
        ) else (
            call :PrintRed "Unable to close Discord"
        )
    )

    set "discordCacheDir=%appdata%\discord"

    for %%d in ("Cache" "Code Cache" "GPUCache") do (
        set "dirPath=!discordCacheDir!\%%~d"
        if exist "!dirPath!" (
            rd /s /q "!dirPath!"
            if !errorlevel!==0 (
                call :PrintGreen "Successfully deleted !dirPath!"
            ) else (
                call :PrintRed "Failed to delete !dirPath!"
            )
        ) else (
            call :PrintRed "!dirPath! does not exist"
        )
    )
)
echo:

pause
goto menu


:: GAME SWITCH ========================
:game_switch_status
chcp 437 > nul

set "gameFlagFile=%~dp0utils\game_filter.enabled"

if not exist "%gameFlagFile%" (
    set "GameFilterStatus=disabled"
    set "GameFilter=12"
    set "GameFilterTCP=12"
    set "GameFilterUDP=12"
    exit /b
)

set "GameFilterMode="
for /f "usebackq delims=" %%A in ("%gameFlagFile%") do (
    if not defined GameFilterMode set "GameFilterMode=%%A"
)

if /i "%GameFilterMode%"=="all" (
    set "GameFilterStatus=enabled (TCP and UDP)"
    set "GameFilter=1024-65535"
    set "GameFilterTCP=1024-65535"
    set "GameFilterUDP=1024-65535"
) else if /i "%GameFilterMode%"=="tcp" (
    set "GameFilterStatus=enabled (TCP)"
    set "GameFilter=1024-65535"
    set "GameFilterTCP=1024-65535"
    set "GameFilterUDP=12"
) else (
    set "GameFilterStatus=enabled (UDP)"
    set "GameFilter=1024-65535"
    set "GameFilterTCP=12"
    set "GameFilterUDP=1024-65535"
)
exit /b


:game_switch
chcp 437 > nul
cls

echo Select game filter mode:
echo   0. Disable
echo   1. TCP and UDP
echo   2. TCP only
echo   3. UDP only
echo.
set "GameFilterChoice=0"
set /p "GameFilterChoice=Select option (0-3, default: 0): "
if "%GameFilterChoice%"=="" set "GameFilterChoice=0"

if "%GameFilterChoice%"=="0" (
    if exist "%gameFlagFile%" (
        del /f /q "%gameFlagFile%"
    ) else (
        goto menu
    )
) else if "%GameFilterChoice%"=="1" (
    echo all>"%gameFlagFile%"
) else if "%GameFilterChoice%"=="2" (
    echo tcp>"%gameFlagFile%"
) else if "%GameFilterChoice%"=="3" (
    echo udp>"%gameFlagFile%"
) else (
    echo Invalid choice, exiting...
    pause
    goto menu
)

call :PrintYellow "Restart the zapret to apply the changes"
pause
goto menu


:: CHECK UPDATES SWITCH =================
:check_updates_switch_status
chcp 437 > nul

set "checkUpdatesFlag=%~dp0utils\check_updates.enabled"

if exist "%checkUpdatesFlag%" (
    set "CheckUpdatesStatus=enabled"
) else (
    set "CheckUpdatesStatus=disabled"
)
exit /b


:check_updates_switch
chcp 437 > nul
cls

if not exist "%checkUpdatesFlag%" (
    echo Enabling check updates...
    echo ENABLED > "%checkUpdatesFlag%"
) else (
    echo Disabling check updates...
    del /f /q "%checkUpdatesFlag%"
)

pause
goto menu


:: LISTS FILTER =======================
:: A list is "optional" if it is a lists\list-*.txt that is not part of the core
:: bypass machinery. These names are always skipped in the toggle menu.
:lists_filter_is_core
:: Sets LF_CORE=1 if %~1 is a reserved/core list base-name, else LF_CORE=0.
set "LF_CORE=0"
for %%C in (general general-user google google-all exclude exclude-user other active) do (
    if /i "%%C"=="%~1" set "LF_CORE=1"
)
exit /b


:lists_filter_status
:: Counts enabled optional lists from utils\lists.conf -> LISTS_FILTER_STATUS.
set "listsConf=%~dp0utils\lists.conf"
set "LF_COUNT=0"
if exist "%listsConf%" (
    for /f "usebackq eol=# delims=" %%N in ("%listsConf%") do (
        set "lfln=%%N"
        if not "!lfln!"=="" set /a LF_COUNT+=1
    )
)
if !LF_COUNT! EQU 0 (set "LISTS_FILTER_STATUS=none") else (set "LISTS_FILTER_STATUS=!LF_COUNT! on")
exit /b


:lists_filter
chcp 437 > nul
set "LISTS_PATH=%~dp0lists\"
set "listsConf=%~dp0utils\lists.conf"

:lists_filter_render
cls
echo.
echo   LISTS FILTER
echo   Enable extra domain lists to bypass (core general + google are always on).
echo   ----------------------------------------
echo.

set "lfCount=0"
for /f "delims=" %%F in ('dir /b /a-d /on "%LISTS_PATH%list-*.txt" 2^>nul') do (
    set "lfBase=%%~nF"
    set "lfName=!lfBase:list-=!"
    call :lists_filter_is_core "!lfName!"
    if "!LF_CORE!"=="0" (
        set /a lfCount+=1
        set "lfitem!lfCount!=!lfName!"
        set "lfMark= "
        if exist "%listsConf%" (
            findstr /x /i /c:"!lfName!" "%listsConf%" >nul 2>&1 && set "lfMark=x"
        )
        echo      [!lfMark!] !lfCount!. !lfName!
    )
)

echo.
echo   ----------------------------------------
echo      0. Back
echo.
set "lf_choice=null"
set /p "lf_choice=   Toggle list number (0 to go back): "

if "!lf_choice!"=="0" goto menu
if "!lf_choice!"=="null" goto lists_filter_render

:: Resolve the chosen index to a list name.
set "lfPick=!lfitem%lf_choice%!"
if not defined lfPick goto lists_filter_render

:: Toggle membership in utils\lists.conf.
set "lfFound=0"
if exist "%listsConf%" (
    findstr /x /i /c:"!lfPick!" "%listsConf%" >nul 2>&1 && set "lfFound=1"
)

if "!lfFound!"=="1" (
    rem disable - rewrite the file without this exact line
    set "lfTmp=%~dp0utils\lists.conf.tmp"
    findstr /v /x /i /c:"!lfPick!" "%listsConf%" > "!lfTmp!" 2>nul
    move /y "!lfTmp!" "%listsConf%" >nul
) else (
    rem enable - append the name
    >> "%listsConf%" echo !lfPick!
)

call :load_lists_filter
goto lists_filter_render


:: IPSET SWITCH =======================
:ipset_switch_status
chcp 437 > nul

set "listFile=%~dp0lists\ipset-all.txt"
for /f %%i in ('type "%listFile%" 2^>nul ^| find /c /v ""') do set "lineCount=%%i"

if !lineCount!==0 (
    set "IPsetStatus=any"
) else (
    findstr /R "^203\.0\.113\.113/32$" "%listFile%" >nul
    if !errorlevel!==0 (
        set "IPsetStatus=none"
    ) else (
        set "IPsetStatus=loaded"
    )
)
exit /b


:ipset_switch
chcp 437 > nul
cls

set "listFile=%~dp0lists\ipset-all.txt"
set "backupFile=%listFile%.backup"

if "%IPsetStatus%"=="loaded" (
    echo Switching to none mode...
    
    if not exist "%backupFile%" (
        ren "%listFile%" "ipset-all.txt.backup"
    ) else (
        del /f /q "%backupFile%"
        ren "%listFile%" "ipset-all.txt.backup"
    )
    
    >"%listFile%" (
        echo 203.0.113.113/32
    )
    
) else if "%IPsetStatus%"=="none" (
    echo Switching to any mode...
    
    >"%listFile%" (
        rem Creating empty file
    )
    
) else if "%IPsetStatus%"=="any" (
    echo Switching to loaded mode...
    
    if exist "%backupFile%" (
        del /f /q "%listFile%"
        ren "%backupFile%" "ipset-all.txt"
    ) else (
        echo Error: no backup to restore. Update list from service menu first
        pause
        goto menu
    )
    
)

pause
goto menu


:: IPSET UPDATE =======================
:ipset_update
chcp 437 > nul
cls

set "listFile=%~dp0lists\ipset-all.txt"
set "url=https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/refs/heads/main/.service/ipset-service.txt"

echo Updating ipset-all...

if exist "%SystemRoot%\System32\curl.exe" (
    curl --version | find "libcurl/7"
    if !errorlevel!==0 (
        curl --ssl-no-revoke -L -o "%listFile%" "%url%"
    ) else (
        curl --ssl-revoke-best-effort -L -o "%listFile%" "%url%"
    )
) else (
    powershell -NoProfile -Command ^
        "$url = '%url%';" ^
        "$out = '%listFile%';" ^
        "$dir = Split-Path -Parent $out;" ^
        "if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null };" ^
        "$res = Invoke-WebRequest -Uri $url -TimeoutSec 10 -UseBasicParsing;" ^
        "if ($res.StatusCode -eq 200) { $res.Content | Out-File -FilePath $out -Encoding UTF8 } else { exit 1 }"
)

echo Finished

pause
goto menu


:: HOSTS UPDATE =======================
:hosts_update
chcp 437 > nul
cls

set "hostsFile=%SystemRoot%\System32\drivers\etc\hosts"
set "hostsUrl=https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/refs/heads/main/.service/hosts"
set "tempFile=%TEMP%\zapret_hosts.txt"
set "needsUpdate=0"

echo Checking hosts file...

if exist "%SystemRoot%\System32\curl.exe" (
    curl -L -s -o "%tempFile%" "%hostsUrl%"
) else (
    powershell -NoProfile -Command ^
        "$url = '%hostsUrl%';" ^
        "$out = '%tempFile%';" ^
        "$res = Invoke-WebRequest -Uri $url -TimeoutSec 10 -UseBasicParsing;" ^
        "if ($res.StatusCode -eq 200) { $res.Content | Out-File -FilePath $out -Encoding UTF8 } else { exit 1 }"
)

if not exist "%tempFile%" (
    call :PrintRed "Failed to download hosts file from repository"
    call :PrintYellow "Copy hosts file manually from %hostsUrl%"
    pause
    goto menu
)

set "firstLine="
set "lastLine="
for /f "usebackq delims=" %%a in ("%tempFile%") do (
    if not defined firstLine (
        set "firstLine=%%a"
    )
    set "lastLine=%%a"
)

findstr /C:"!firstLine!" "%hostsFile%" >nul 2>&1
if !errorlevel! neq 0 (
    echo First line from repository not found in hosts file
    set "needsUpdate=1"
)

findstr /C:"!lastLine!" "%hostsFile%" >nul 2>&1
if !errorlevel! neq 0 (
    echo Last line from repository not found in hosts file
    set "needsUpdate=1"
)

if "%needsUpdate%"=="1" (
    echo:
    call :PrintYellow "Hosts file needs to be updated"
    call :PrintYellow "Please manually copy the content from the downloaded file to your hosts file"
    
    start notepad "%tempFile%"
    explorer /select,"%hostsFile%"
) else (
    call :PrintGreen "Hosts file is up to date"
    if exist "%tempFile%" del /f /q "%tempFile%"
)

echo:
pause
goto menu


:: RUN TESTS =============================
:run_tests
chcp 437 >nul
cls

:: Require PowerShell 3.0+
powershell -NoProfile -Command "if ($PSVersionTable -and $PSVersionTable.PSVersion -and $PSVersionTable.PSVersion.Major -ge 3) { exit 0 } else { exit 1 }" >nul 2>&1
if %errorLevel% neq 0 (
    echo PowerShell 3.0 or newer is required.
    echo Please upgrade PowerShell and rerun this script.
    echo.
    pause
    goto menu
)

echo Starting configuration tests in PowerShell window...
echo.
start "" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0utils\test zapret.ps1"
pause
goto menu


:: Get strategy name
:get_strategy_name
set "CurrentStrategy="
for /f "tokens=2*" %%A in ('reg query "HKLM\System\CurrentControlSet\Services\zapret" /v zapret-discord-youtube 2^>nul') do set "CurrentStrategy=Strategy: %%B"
exit /b

:: TELEGRAM PROXY (tg-ws-proxy)

:tgproxy_load_config
set "TGP_PORT=1443"
set "TGP_HOST=127.0.0.1"
set "TGP_SECRET="
set "TGP_DCIP=2:149.154.167.220 4:149.154.167.220"
set "TGP_CONF=%~dp0utils\tgproxy.conf"
if exist "!TGP_CONF!" (
    for /f "usebackq tokens=1,* delims==" %%A in ("!TGP_CONF!") do (
        if /i "%%A"=="PORT"   set "TGP_PORT=%%B"
        if /i "%%A"=="HOST"   set "TGP_HOST=%%B"
        if /i "%%A"=="SECRET" set "TGP_SECRET=%%B"
        if /i "%%A"=="DCIP"   set "TGP_DCIP=%%B"
    )
)
exit /b


:tgproxy_save_config
set "TGP_CONF=%~dp0utils\tgproxy.conf"
(
    echo PORT=!TGP_PORT!
    echo HOST=!TGP_HOST!
    echo SECRET=!TGP_SECRET!
    echo DCIP=!TGP_DCIP!
)>"!TGP_CONF!"
exit /b


:tgproxy_ensure_secret
if not "!TGP_SECRET!"=="" exit /b
for /f "usebackq delims=" %%S in (`powershell -NoProfile -Command "$b=New-Object byte[] 16;[Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b);[BitConverter]::ToString($b).Replace('-','').ToLower()"`) do set "TGP_SECRET=%%S"
call :tgproxy_save_config
exit /b


:tgproxy_build_dcargs
set "TGP_DCARGS="
for %%D in (!TGP_DCIP!) do set "TGP_DCARGS=!TGP_DCARGS! --dc-ip %%D"
exit /b


:tgproxy_status
set "TGP_RUN=0"
:: "running" means the configured port is actually in LISTENING state, not just
:: that a process named tgwsproxy.exe exists. The PyInstaller onefile bootloader
:: is named tgwsproxy.exe before it binds the socket, so a process-name check
:: gives false positives when the bind later fails (e.g. port already in use).
netstat -ano -p tcp 2>nul | findstr /r /c:":!TGP_PORT! .*LISTENING" >nul 2>&1 && set "TGP_RUN=1"
set "TGP_SVC=0"
sc query "TgWsProxy" >nul 2>&1 && set "TGP_SVC=1"
exit /b


:tgproxy_wait_service_gone
:: Poll for the TgWsProxy entry to leave the service database after a remove.
:: "sc query" still succeeds for a moment while the SCM finishes deletion (or
:: while it is DELETE_PENDING with an open handle), so a single check right after
:: "nssm remove" looked like a failure even though the service does disappear.
:: Sets TGP_SVC_GONE=1 once "sc query" can no longer find it.
set "TGP_SVC_GONE=0"
for /l %%N in (1,1,10) do (
    if "!TGP_SVC_GONE!"=="0" (
        sc query TgWsProxy >nul 2>&1 || set "TGP_SVC_GONE=1"
        if "!TGP_SVC_GONE!"=="0" ping -n 2 127.0.0.1 >nul
    )
)
exit /b


:tgproxy_lan_ip
for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "try{$s=New-Object Net.Sockets.Socket([Net.Sockets.AddressFamily]::InterNetwork,[Net.Sockets.SocketType]::Dgram,[Net.Sockets.ProtocolType]::Udp);$s.Connect('8.8.8.8',80);$ip=$s.LocalEndPoint.Address.ToString();$s.Close();$ip}catch{'127.0.0.1'}"`) do set "LINK_HOST=%%I"
exit /b


:tgproxy_status_menu
chcp 437 > nul
call :tgproxy_load_config
call :tgproxy_status
cls
if "!TGP_RUN!"=="1" (set "TGP_RUN_TXT=RUNNING") else (set "TGP_RUN_TXT=stopped")
if "!TGP_SVC!"=="1" (set "TGP_SVC_TXT=installed") else (set "TGP_SVC_TXT=not installed")
echo:
echo   TGWSPROXY STATUS
if "!TGP_RUN!"=="1" (
    call :PrintGreen "Proxy is RUNNING (listening on !TGP_HOST!:!TGP_PORT!)."
) else (
    call :PrintRed "Proxy is NOT running."
)
if "!TGP_SVC!"=="1" (
    call :PrintGreen "Service TgWsProxy is installed."
) else (
    call :PrintRed "Service TgWsProxy is NOT installed."
)
echo:
pause
goto menu


:tgproxy_service_install
chcp 437 > nul
cls
call :tgproxy_load_config
call :tgproxy_ensure_secret
call :tgproxy_build_dcargs
set "BIN=%~dp0bin\"
set "BINDIR=%~dp0bin"

if not exist "!BIN!nssm.exe" (
    call :PrintRed "bin\nssm.exe not found. Cannot install service."
    pause
    goto menu
)

echo Installing service TgWsProxy ...
"!BIN!nssm.exe" stop TgWsProxy >nul 2>&1
"!BIN!nssm.exe" remove TgWsProxy confirm >nul 2>&1
"!BIN!nssm.exe" install TgWsProxy "!BIN!tgwsproxy.exe" >nul
"!BIN!nssm.exe" set TgWsProxy AppParameters "--host !TGP_HOST! --port !TGP_PORT! --secret !TGP_SECRET!!TGP_DCARGS!" >nul
"!BIN!nssm.exe" set TgWsProxy AppDirectory "!BINDIR!" >nul
"!BIN!nssm.exe" set TgWsProxy DisplayName "TG WS Proxy" >nul
"!BIN!nssm.exe" set TgWsProxy Description "Telegram MTProto WebSocket proxy" >nul
"!BIN!nssm.exe" set TgWsProxy Start SERVICE_AUTO_START >nul
"!BIN!nssm.exe" set TgWsProxy AppStdout "!BINDIR!\tgwsproxy.log" >nul
"!BIN!nssm.exe" set TgWsProxy AppStderr "!BINDIR!\tgwsproxy.log" >nul
"!BIN!nssm.exe" set TgWsProxy AppStdoutCreationDisposition 2 >nul
"!BIN!nssm.exe" set TgWsProxy AppStderrCreationDisposition 2 >nul
"!BIN!nssm.exe" start TgWsProxy >nul 2>&1

sc query TgWsProxy >nul 2>&1
if !errorlevel!==0 (
    call :PrintGreen "Service TgWsProxy installed and started (autostart enabled)."
    call :PrintGreen "It is visible in services.msc and survives reboots."
) else (
    call :PrintRed "Failed to install service. Make sure service.bat is run as Administrator."
)
pause
goto menu


:tgproxy_service_remove
chcp 437 > nul
cls
set "BIN=%~dp0bin\"
sc query TgWsProxy >nul 2>&1
if !errorlevel! neq 0 (
    echo Service TgWsProxy is not installed.
    pause
    goto menu
)

echo Removing service TgWsProxy ...
if exist "!BIN!nssm.exe" (
    "!BIN!nssm.exe" stop TgWsProxy >nul 2>&1
    "!BIN!nssm.exe" remove TgWsProxy confirm >nul 2>&1
) else (
    net stop TgWsProxy >nul 2>&1
    sc stop TgWsProxy >nul 2>&1
    sc delete TgWsProxy >nul 2>&1
)
:: The service host and its proxy child must exit before the SCM can finish
:: deleting the entry; kill any leftover so the removal can complete, then poll
:: until the service is actually gone instead of checking once immediately.
taskkill /IM tgwsproxy.exe /F >nul 2>&1
call :tgproxy_wait_service_gone

if "!TGP_SVC_GONE!"=="1" (
    call :PrintGreen "Service removed."
) else (
    call :PrintYellow "Service is marked for removal and will disappear shortly."
    call :PrintYellow "If it lingers, close services.msc (it keeps the entry open) or reboot."
)
pause
goto menu


:tgproxy_set_port
chcp 437 > nul
cls
call :tgproxy_load_config
echo Current port: !TGP_PORT!
set "new_port="
set /p "new_port=Enter new port (1-65535, empty to cancel): "
if "!new_port!"=="" goto menu

echo !new_port!| findstr /r "^[1-9][0-9]*$" >nul
if !errorlevel! neq 0 (
    call :PrintRed "Invalid port (digits only)."
    pause
    goto menu
)
if !new_port! GTR 65535 (
    call :PrintRed "Port out of range (1-65535)."
    pause
    goto menu
)

set "TGP_PORT=!new_port!"
call :tgproxy_save_config
call :PrintGreen "Port set to !TGP_PORT!."
call :PrintYellow "Restart the proxy / reinstall the service to apply."
pause
goto menu


:tgproxy_set_host
chcp 437 > nul
cls
call :tgproxy_load_config
echo Current host: !TGP_HOST!
echo.
echo   127.0.0.1  - local only (this PC)
echo   0.0.0.0    - all interfaces (share the proxy over LAN)
echo.
set "new_host="
set /p "new_host=Enter new host/IP (empty to cancel): "
if "!new_host!"=="" goto menu

set "TGP_HOST=!new_host!"
call :tgproxy_save_config
call :PrintGreen "Host set to !TGP_HOST!."
call :PrintYellow "Restart the proxy / reinstall the service to apply."
pause
goto menu


:tgproxy_set_dcip
chcp 437 > nul
cls
call :tgproxy_load_config
echo Current DC IPs: !TGP_DCIP!
echo.
echo Format: DC:IP pairs separated by spaces.
echo Example: 2:149.154.167.220 4:149.154.167.220
echo Leave empty to reset to default.
echo.
set "new_dcip="
set /p "new_dcip=Enter DC IPs: "
if "!new_dcip!"=="" (
    set "TGP_DCIP=2:149.154.167.220 4:149.154.167.220"
) else (
    set "TGP_DCIP=!new_dcip!"
)
call :tgproxy_save_config
call :PrintGreen "DC IPs set to: !TGP_DCIP!"
call :PrintYellow "Restart the proxy / reinstall the service to apply."
pause
goto menu


:tgproxy_link
chcp 437 > nul
cls
call :tgproxy_load_config
call :tgproxy_ensure_secret
call :tgproxy_render_link
pause
goto menu


:tgproxy_render_link
:: Shared link renderer. Assumes TGP_HOST / TGP_PORT / TGP_SECRET are loaded
:: and a secret exists. Builds the tg:// link, prints it, copies it to the
:: clipboard and offers to open Telegram. Used by both the menu and the
:: standalone "tgwsproxy.bat" one-click launcher.
set "LINK_HOST=!TGP_HOST!"
if "!TGP_HOST!"=="0.0.0.0" call :tgproxy_lan_ip

set "LINK=tg://proxy?server=!LINK_HOST!&port=!TGP_PORT!&secret=dd!TGP_SECRET!"

echo.
echo     TELEGRAM PROXY CONNECTION LINK
echo.
echo     Server : !LINK_HOST!
echo     Port   : !TGP_PORT!
echo     Secret : dd!TGP_SECRET!
echo.
echo   --------------------------------------------------------
echo     !LINK!
echo   --------------------------------------------------------
echo.
set "TGLINK=!LINK!"
set "TGP_COPIED=0"
powershell -NoProfile -Command "Set-Clipboard -Value $env:TGLINK" 2>nul
if not errorlevel 1 set "TGP_COPIED=1"
if "!TGP_COPIED!"=="0" (
    > "%TEMP%\tgp_link.txt" echo !LINK!
    clip < "%TEMP%\tgp_link.txt"
    if not errorlevel 1 set "TGP_COPIED=1"
    del "%TEMP%\tgp_link.txt" >nul 2>&1
)
if "!TGP_COPIED!"=="1" (
    call :PrintGreen "Link copied to clipboard."
) else (
    call :PrintYellow "Could not copy automatically - copy the link shown above manually."
)
echo.
set "open_tg="
set /p "open_tg=Open in Telegram now? (Y/N, default: N): "
if /i "!open_tg!"=="Y" start "" "!LINK!"
echo.
exit /b


:tgproxy_quickstart
:: One-click entry point used by "Telegram Proxy.bat" (no admin required).
:: Runs the proxy in THIS console so the launcher stays a single window: the
:: link is shown / copied first, then the proxy runs in the foreground here.
:: Closing the window stops the proxy. If the proxy (or its installed service)
:: is already listening on the port, we only show the link instead of starting
:: a second instance that would fail to bind.
setlocal EnableDelayedExpansion
chcp 437 > nul
cls
if not exist "%~dp0bin\tgwsproxy.exe" (
    call :PrintRed "bin\tgwsproxy.exe not found. Telegram proxy is unavailable in this build."
    echo.
    pause
    endlocal
    exit /b
)

call :tgproxy_load_config
call :tgproxy_ensure_secret
call :tgproxy_build_dcargs
set "BIN=%~dp0bin\"

call :tgproxy_status
if "!TGP_RUN!"=="1" goto tgproxy_qs_running

:: Not running: run the proxy in the foreground of THIS window (single console).
call :tgproxy_render_link
echo.
echo Starting proxy on !TGP_HOST!:!TGP_PORT! ...
echo.
"!BIN!tgwsproxy.exe" --host !TGP_HOST! --port !TGP_PORT! --secret !TGP_SECRET!!TGP_DCARGS!
echo.
call :PrintYellow "Telegram proxy stopped."
pause
endlocal
goto :eof

:tgproxy_qs_running
echo Telegram proxy is already running on !TGP_HOST!:!TGP_PORT!.
call :tgproxy_render_link
echo Tip: full settings - port, host, autostart service - are in service.bat -^> 12.
echo.
pause
endlocal
goto :eof


:: Utility functions

:PrintGreen
powershell -NoProfile -Command "Write-Host \"%~1\" -ForegroundColor Green"
exit /b

:PrintRed
powershell -NoProfile -Command "Write-Host \"%~1\" -ForegroundColor Red"
exit /b

:PrintYellow
powershell -NoProfile -Command "Write-Host \"%~1\" -ForegroundColor Yellow"
exit /b

:check_command
where %1 >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] %1 not found in PATH
    echo Fix your PATH variable with instructions here https://github.com/Flowseal/zapret-discord-youtube/issues/7490
    pause
    exit /b 1
)
exit /b 0

:check_extracted
set "extracted=1"

if not exist "%~dp0bin\" set "extracted=0"

if "%extracted%"=="0" (
    echo Zapret must be extracted from archive first or bin folder not found for some reason
    pause
    exit
)
exit /b 0
