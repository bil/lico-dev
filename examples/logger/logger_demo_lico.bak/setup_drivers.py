from distutils.core import Extension, setup

from Cython.Build import cythonize

sink_extensions = [
    Extension("sink_drivers.sink_driver", ["sink_drivers/sink_driver.pyx"]),
    Extension(
        "sink_drivers.disk.disk",
        ["sink_drivers/disk/disk.pyx", "sink_drivers/disk/sqlHelpers.c", "sink_drivers/disk/sqlite3async.c"],
    ),
]

setup(
    name="sink_drivers",
    ext_modules=cythonize(sink_extensions, language_level=3),
)


source_extensions = [
    Extension("source_drivers.source_driver", ["source_drivers/source_driver.pyx"]),
    Extension(
        "source_drivers.disk}.disk}",
        ["source_drivers/disk}/disk}.pyx"],
    ),
]

setup(
    name="source_drivers",
    ext_modules=cythonize(sink_extensions, language_level=3),
)