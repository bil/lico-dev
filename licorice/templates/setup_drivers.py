from distutils.core import Extension, setup

from Cython.Build import cythonize

extensions = [
    Extension("sink_drivers.sink_driver", ["sink_drivers/sink_driver.pyx"]),
    Extension(
        "sink_drivers.vis_pygame.vis_pygame",
        ["sink_drivers/vis_pygame/vis_pygame.pyx"],
    ),
]

setup(
    name="sink_drivers",
    ext_modules=cythonize(extensions, language_level=3),
)
