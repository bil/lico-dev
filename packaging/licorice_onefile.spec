# -*- mode: python ; coding: utf-8 -*-

from distutils.sysconfig import get_python_lib
from sysconfig import get_path

import numpy as np

block_cipher = None

py_incl_src = get_path("include")
py_incl_dst = "/".join(py_incl_src.split("/")[-2:])

py_lib_src = get_python_lib()
py_lib_dst = "/".join(py_lib_src.split("/")[-3:])

a = Analysis(  # noqa: F821
    ["../licorice/cli.py"],
    pathex=[],
    binaries=[],
    datas=[
        ("../licorice/templates", "templates"),
        (np.get_include(), "numpy/core/include"),
        (py_incl_src, py_incl_dst),
        (py_lib_src, py_lib_dst),
    ],
    hiddenimports=[],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)
pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)  # noqa: F821

exe = EXE(  # noqa: F821
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name="licorice",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,
    disable_windowed_traceback=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
