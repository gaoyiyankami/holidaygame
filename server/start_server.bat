@echo off
set PORT=7000
if not "%~1"=="" set PORT=%~1
HolidayAdventure-v0.8.0.exe -- --server --port=%PORT%
