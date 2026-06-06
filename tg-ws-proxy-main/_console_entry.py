"""
Standalone console entry point for the Telegram WS proxy.

Used by PyInstaller (packaging/console.spec) to build a single-file
`tgwsproxy.exe` for the zapret-discord-youtube bundle. Keeping a top-level
module (rather than running `proxy.tg_ws_proxy` as `__main__`) avoids the
relative-import bootstrap dance and gives PyInstaller a clean entry point.
"""
from proxy.tg_ws_proxy import main


if __name__ == '__main__':
    main()
