@echo off
set PORT=7000
if not "%~1"=="" set PORT=%~1
HolidayAdventure.exe -- --server --port=%PORT%
