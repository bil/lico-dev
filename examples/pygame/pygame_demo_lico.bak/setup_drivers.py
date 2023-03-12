# python setup.py install
from distutils.core import setup

from Cython.Build import cythonize

setup(ext_modules=cythonize(
    [
        "pygame_demo_vis_pygame.pyx",
    ],
    language_level=3,
))