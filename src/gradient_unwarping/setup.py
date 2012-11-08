from numpy.distutils.core import setup, Extension
from numpy.distutils.misc_util import get_numpy_include_dirs 
import os, sys

mods = ['gradunwarp.core.coeffs', 'gradunwarp.core.globals', 
        'gradunwarp.core.__init__', 'gradunwarp.__init__',
        'gradunwarp.core.utils',
        'gradunwarp.core.unwarp_resample',
        'gradunwarp.core.gradient_unwarp',
        'gradunwarp.core.tests.test_utils',
       ]

dats = [('gradunwarp/core/', ['gradunwarp/core/interp3_ext.c']),
        ('gradunwarp/core/', ['gradunwarp/core/legendre_ext.c']),
        ('gradunwarp/core/', ['gradunwarp/core/transform_coordinates_ext.c']),
       ]

# to build the C extension interp3_ext.c
ext1 = Extension('gradunwarp.core.interp3_ext',
                 include_dirs = get_numpy_include_dirs(),
                 sources = ['gradunwarp/core/interp3_ext.c'],
                 extra_compile_args=['-O3'])
# to build the C extension legendre_ext.c
ext2 = Extension('gradunwarp.core.legendre_ext',
                 include_dirs = get_numpy_include_dirs(),
                 sources = ['gradunwarp/core/legendre_ext.c'],
                 extra_compile_args=['-O3'])
# to build the C extension transform_coordinates_ext.c
ext3 = Extension('gradunwarp.core.transform_coordinates_ext',
                 include_dirs = get_numpy_include_dirs(),
                 sources = ['gradunwarp/core/transform_coordinates_ext.c'],
                 extra_compile_args=['-O3'])

scripts_cmd = ['gradunwarp/core/gradient_unwarp.py',]
        

def configuration(parent_package='', top_path=None):
    from numpy.distutils.misc_util import Configuration
    config = Configuration('',parent_package,top_path)
    config.add_data_files ( *dats )
    return config

setup(name='gradunwarp',
      version = '2.0_alpha-hcp-1',
      description = 'Gradient Unwarping Package for Python/Numpy',
      author = 'Krish Subramaniam',
      py_modules  = mods,
      ext_modules = [ext1, ext2, ext3],
      scripts = scripts_cmd,
      configuration=configuration,
     )

