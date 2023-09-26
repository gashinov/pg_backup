REM @ECHO OFF

SETLOCAL EnableDelayedExpansion

SET SCRIPT_NAME=%~n0
SET SCRIPT_PATH=%~dp0

SET PG_BIN="%programfiles%\PostgreSQL\14.4-1.1C\bin"
SET DB_CONNECT=--host localhost --port 5432 --username "postgres"
SET DB_DUMP_OPTIONS=--format directory --jobs=8 --blobs --exclude-table-data=config --verbose --file
SET PGPASSWORD=<postgres user password>

SET SCRIPT_INI_FILE=%SCRIPT_PATH%%SCRIPT_NAME%.ini
SET SCRIPT_LOG_FILE=%SCRIPT_PATH%%SCRIPT_NAME%.log

SET BACKUP_PATH=%SCRIPT_PATH%data
SET BACKUP_PATH_BINARY=%BACKUP_PATH:\=\\%

REM Explictly specify working drive
C:
CD "%PG_BIN%"

IF NOT EXIST %SCRIPT_INI_FILE% (

    ECHO. >> %SCRIPT_LOG_FILE%
    ECHO %DATE% >> %SCRIPT_LOG_FILE%
    ECHO No .ini file found >> %SCRIPT_LOG_FILE%
    ECHO. >> %SCRIPT_LOG_FILE%

    GOTO EOF
) 

IF NOT EXIST %BACKUP_PATH% (
    MKDIR %BACKUP_PATH%
) 

	ECHO. >> %SCRIPT_LOG_FILE%
	ECHO %DATE% >> %SCRIPT_LOG_FILE%
	ECHO. >> %SCRIPT_LOG_FILE%
	ECHO ----- Started at !TIME! ----- >> %SCRIPT_LOG_FILE%
	ECHO. >> %SCRIPT_LOG_FILE%

FOR /f "tokens=1-4 delims=/. " %%a in ('date /t') do (set ISO-DATE=%%c%%b%%a)

FOR /f "usebackq delims=" %%y IN ("%SCRIPT_INI_FILE%") DO (

	IF NOT EXIST %BACKUP_PATH%\%ISO-DATE%\%%y (
	    MKDIR %BACKUP_PATH%\%ISO-DATE%\%%y
	)

	ECHO %%y >> %SCRIPT_LOG_FILE%
	ECHO ------------- >> %SCRIPT_LOG_FILE%

	ECHO Dump database >> %SCRIPT_LOG_FILE%
	ECHO --- !TIME! >> %SCRIPT_LOG_FILE%
	PG_DUMP.EXE %DB_CONNECT% %DB_DUMP_OPTIONS% "%BACKUP_PATH%\%ISO-DATE%\%%y" "%%y"
	ECHO     !TIME! --- >> %SCRIPT_LOG_FILE%

	ECHO Config table >> %SCRIPT_LOG_FILE%
	ECHO --- !TIME! >> %SCRIPT_LOG_FILE%
	PSQL.EXE %DB_CONNECT% --command "COPY public.config TO '%BACKUP_PATH_BINARY%\\%ISO-DATE%\\%%y\\config.table' WITH BINARY;" --dbname="%%y"
	ECHO     !TIME! --- >> %SCRIPT_LOG_FILE%
 
)

ECHO. >> %SCRIPT_LOG_FILE%
ECHO ----- Completed at !TIME! ----- >> %SCRIPT_LOG_FILE%
ECHO. >> %SCRIPT_LOG_FILE%

:EOF
