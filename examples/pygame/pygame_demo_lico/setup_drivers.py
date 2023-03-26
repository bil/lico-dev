from distutils.core import Extension, setup

from Cython.Build import cythonize

sink_extensions = [
    Extension("sink_drivers.sink_driver", ["sink_drivers/sink_driver.pyx"]),
    Extension(
        "sink_drivers.vis_pygame.vis_pygame",
        ["sink_drivers/vis_pygame/vis_pygame.pyx"],
    ),
]

setup(
    name="sink_drivers",
    ext_modules=cythonize(sink_extensions, language_level=3),
)


source_extensions = [
    Extension("source_drivers.source_driver", ["source_drivers/source_driver.pyx"]),
    Extension(
        "source_drivers.vis_pygame}.vis_pygame}",
        ["source_drivers/vis_pygame}/vis_pygame}.pyx"],
    ),
]

setup(
    name="source_drivers",
    ext_modules=cythonize(sink_extensions, language_level=3),
)