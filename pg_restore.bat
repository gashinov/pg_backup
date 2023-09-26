@echo off

SET PG_BIN="%programfiles%\PostgreSQL\14.4-1.1C\bin"

SET PGPASSWORD=<postgres user password>
SET DB_CONNECT=--host localhost --port 5432 --username "postgres"

REM -----------------------
SET DB_NAME=database
SET BACKUP_PATH=Z:\backup\postgres
REM -----------------------

REM Explictly specify working drive
C:
CD "%PG_BIN%"

@echo.
@echo -----------------------
@echo  Check restore options
@echo -----------------------
@echo.
@echo  db name
@echo.
@echo          %DB_NAME%
@echo.
@echo  restore path
@echo.
@echo          %BACKUP_PATH%
@echo.

SET BACKUP_PATH=%BACKUP_PATH:\=\\%

pause

@pg_restore.exe --verbose %DB_CONNECT% --jobs=8 --clean --format=d --dbname=%DB_NAME% %BACKUP_PATH%
@echo.
@psql.exe %DB_CONNECT% --command "COPY public.config from '%BACKUP_PATH%\\config.table' WITH BINARY;" --dbname="%DB_NAME%"
@echo.
@pause
