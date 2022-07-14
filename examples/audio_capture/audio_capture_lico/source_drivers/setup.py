# python setup.py install
from distutils.core import setup
from Cython.Build import cythonize

# setup(
#     name='test',
#     ext_modules=cythonize("test.pyx"),
# )
setup(ext_modules=cythonize(
    [
        "audio_in_line.pyx", 
        "source_driver.pyx"
    ],
    language_level=3,
))
