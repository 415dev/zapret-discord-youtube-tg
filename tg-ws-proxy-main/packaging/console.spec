# -*- mode: python ; coding: utf-8 -*-
#
# PyInstaller spec for the standalone CONSOLE proxy (tgwsproxy.exe).
# Build:  python -m PyInstaller packaging/console.spec
# Output: dist/tgwsproxy.exe  ->  copy into ../bin/tgwsproxy.exe
#
# Unlike windows.spec (the tray GUI), this build has no UI dependencies
# (no customtkinter / pystray / pyperclip). It only needs `cryptography`
# for AES-CTR, since the libcrypto fallback in proxy/_aes.py is not
# available on a bare Windows box.

import os

block_cipher = None

a = Analysis(
    [os.path.join(os.path.dirname(SPEC), os.pardir, '_console_entry.py')],
    pathex=[os.path.join(os.path.dirname(SPEC), os.pardir)],
    binaries=[],
    datas=[],
    hiddenimports=[
        'cryptography.hazmat.primitives.ciphers',
        'cryptography.hazmat.primitives.ciphers.algorithms',
        'cryptography.hazmat.primitives.ciphers.modes',
        'cryptography.hazmat.backends.openssl',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        'customtkinter',
        'pystray',
        'pyperclip',
        'PIL',
        'tkinter',
        'rumps',
    ],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='tgwsproxy',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
