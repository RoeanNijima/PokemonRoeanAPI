@echo off
setlocal ENABLEDELAYEDEXPANSION

:: =========================
:: Configurable Variables
:: =========================
set "GIT_REPO_URL=https://github.com/RoeanNijima/PokemonRoean.git"
set "GAME_DIR=%cd%\GAME"
set "BRANCH=main"

:: =========================
:: Check for Git
:: =========================
where git >nul 2>&1
if %errorlevel% neq 0 (
    echo Git not found! Installing Git via Winget...
    winget install --id Git.Git -e --source winget >nul 2>&1
    set "PATH=%PATH%;C:\Program Files\Git\cmd"
) else (
    echo Git detected.
)

:: =========================
:: Install or Update Repo
:: =========================
if exist "%GAME_DIR%\.git" (
    echo Game installation detected! Checking for updates...
    pushd "%GAME_DIR%" >nul

    :: Fetch remote changes
    git fetch --progress 2>&1 | powershell -NoProfile -ExecutionPolicy Bypass -Command ^
      "$activity='Checking for updates...';" ^
      "$input | ForEach-Object { if ($_ -match '(\d+)%%') { $p=[int]([regex]::Match($_,'(\d+)%%').Groups[1].Value); Write-Progress -Activity $activity -Status $_ -PercentComplete $p } }; Write-Progress -Activity $activity -Completed"

    :: Detect if behind
    for /f "tokens=*" %%i in ('git status -uno ^| findstr /C:"Your branch is behind"') do set "BEHIND=%%i"

    if defined BEHIND (
        echo New Patch found on network! Downloading patch...
        powershell -NoProfile -ExecutionPolicy Bypass -Command ^
          "$activity='Applying patch...';" ^
          "git fetch --all 2>&1 | Out-Null;" ^
          "git checkout %BRANCH% 2>&1 | Out-Null;" ^
          "git reset --hard origin/%BRANCH% 2>&1 | Out-Null;" ^
          "git clean -fdx 2>&1 | Out-Null;" ^
          "Write-Progress -Activity $activity -Completed"
        echo Update complete!
    ) else (
        :: Detect tampering excluding Game.rxproj and PBS/
        set "TAMPERED="

        :: Check for modified tracked files
        for /f "tokens=*" %%a in ('git diff --name-only') do (
            if /I not "%%a"=="Game.rxproj" if /I not "%%a"=="PBS/" (
                set "TAMPERED=1"
            )
        )

        :: Check for untracked files
        for /f "tokens=*" %%a in ('git ls-files --others --exclude-standard') do (
            if /I not "%%a"=="Game.rxproj" if /I not "%%a"=="PBS/" (
                set "TAMPERED=1"
            )
        )

        :: Check for deleted tracked files (excluding Game.rxproj and PBS/)
        for /f "tokens=*" %%a in ('git ls-files --deleted') do (
            if /I not "%%a"=="Game.rxproj" if /I not "%%a"=="PBS/" (
                set "TAMPERED=1"
            )
        )

        if defined TAMPERED (
            echo.
            echo WARNING: Game file verification failed!
            echo One or more game files appear modified, missing, or corrupted.
            set /p "CHOICE=Would you like to verify and restore game files? (y/n): "
            if /I "!CHOICE!"=="Y" (
                echo Verifying and restoring game files...
                powershell -NoProfile -ExecutionPolicy Bypass -Command ^
                  "$activity='Verifying game files...';" ^
                  "git fetch --all 2>&1 | Out-Null;" ^
                  "git checkout %BRANCH% 2>&1 | Out-Null;" ^
                  "git reset --hard origin/%BRANCH% 2>&1 | Out-Null;" ^
                  "git clean -fdx 2>&1 | Out-Null;" ^
                  "Write-Progress -Activity $activity -Completed"
                echo Verification complete! All files restored.
            ) else (
                echo Skipping verification. Proceed with caution.
            )
        ) else (
            echo Your game is up to date and unmodified.
        )
    )
    popd >nul
) else (
    echo No game installation detected! Installing Pokemon Roean...
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
      "$activity='Installing Pokemon Roean...';" ^
      "git clone --progress '%GIT_REPO_URL%' '%GAME_DIR%' 2>&1 | ForEach-Object { if ($_ -match '(\d+)%%') { $p=[int]([regex]::Match($_,'(\d+)%%').Groups[1].Value); Write-Progress -Activity $activity -Status $_ -PercentComplete $p } }; Write-Progress -Activity $activity -Completed"
    echo Installation complete!
)

:: =========================
:: Silent cleanup
:: =========================
del /f /q "%GAME_DIR%\Game.rxproj" >nul 2>&1

echo Done!
pause
