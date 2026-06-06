@echo off
:: Telegram Proxy (tg-ws-proxy)
chcp 65001 > nul

cd /d "%~dp0"
call "%~dp0service.bat" tgproxy_quickstart
