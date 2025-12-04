@echo off
REM ============================================================================
REM Network Automation Dashboard Launcher
REM Double-click this file to launch the Dashboard GUI
REM ============================================================================

REM Launch Dashboard with PowerShell
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\GUI\Dashboard.ps1"
