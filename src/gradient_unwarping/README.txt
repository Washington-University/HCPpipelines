.. -*- rest -*-
.. vim:syntax=rest

==========
gradunwarp
==========

gradunwarp is a Python/Numpy package used to unwarp the distorted volumes (due to the gradient field іnhomogenities). Currently, it can unwarp Siemens data (and GE support very soon). 

Installation
============

Prerequisites
-------------
gradunwarp needs 
 * Python (>2.7)
 * Numpy (preferably, the latest)
 * Scipy (preferably, the latest)
 * Numpy devel package (to compile external modules written in C)
 * nibabel (latest trunk, which has the MGH support)

The installation of these in Ubuntu is as simple as
::

  sudo apt-get install python-numpy
  sudo apt-get install python-scipy

Install
-------
For convenience both the gradunwarp and nibabel tarballs can be downloaded from

***FOR HCP PIPELINES USE VERSION IN HCP PIPELINES GIT REPO
https://github.com/downloads/ksubramz/gradunwarp/gradunwarp-2.0_alpha.tar.gz
FOR HCP PIPELINES USE VERSION IN HCP PIPELINES GIT REPO***

https://github.com/downloads/ksubramz/gradunwarp/nibabel-1.2.0.dev.tar.gz

They are extracted and the following step is the same for gradunwarp and nibabel installation. First, change to the respective directory. Then,
::

  sudo python setup.py install

Note:
It is possible that you don't have superuser permissions. In that case, you can use the ``--prefix`` switch of setup.py install.
::

  python setup.py install --prefix=/home/foo/

In that case, make sure your PATH has ``/home/foo/bin`` and make sure the PYTHONPATH has ``/home/foo/bin/lib/python-2.7/site-packages/``


Usage
=====

skeleton
::

  gradient_unwarp.py infile outfile manufacturer -g <coefficient file> [optional arguments]

typical usage
::

  gradient_unwarp.py sonata.mgh testoutson.mgh siemens -g coeff_Sonata.grad  --fovmin -.15 --fovmax .15 --numpoints 40

  gradient_unwarp.py avanto.mgh testoutava.mgh siemens -g coeff_AS05.grad -n

Positional Arguments
--------------------
The input file (in Nifti or MGH formats) followed by the output file name (which has the Nifti or MGH extensions -- .nii/.nii.gz/.mgh/.mgz) followed by the vendor name.

Required Options
----------------
::

  -c <coef_file>
  -g <grad_file>

The coefficient file (which is acquired from the vendor) is specified using a ``-g`` option, to be used with files of type ``.grad``.

Or it can be specified using a ``-c`` in the case you have the ``.coef`` file.

These two options are mutually exclusive. 

Other Options
-------------
::

  -n : If you want to suppress the jacobian intensity correction
  -w : if the volume is to be warped rather than unwarped

  --fovmin <fovmin> : a float argument which specifies the minimum extent of the grid where spherical harmonics are evaluated. (in meters). Default is -.3
  --fovmax <fovmax> : a float argument which specifies the maximum extent of the grid where spherical harmonics are evaluated. (in meters). Default is .3
  --numpoints <numpoints> : an int argument which specifies the number of points in the grid. (in each direction). Default is 60
  
  --interp_order <order of interpolation> : takes values from 1 to 4. 1 means the interpolation is going to be linear which is a faster method but not as good as higher order interpolations. 

  --help : display help


Memory Considerations
=====================

gradunwarp tends to use quite a bit of memory because of the intense spherical harmonics calculation and interpolations performed multiple times. For instance, it uses almost 85% memory of a 2GB memory 2.2GHz DualCore system to performing unwarping of a 256^3 volume with 40^3 spherical harmonics grid. (It typically takes 4 to 5 minutes for the entire unwarping)

Some thoughts:
 - Use lower resolution volumes if possible
 - Run gradunwarp in a computer with more memory
 - Use --numpoints to reduce the grid size. --fovmin and --fovmax can be used to move the grid close to your data extents.
 - Recent versions of Python, numpy and scipy


Future Work
===========

 * support for GE processing (near future)
 * better support for high res volumes (process it slice-by-slice?)
 * report statistics 
 * explore removal of Numpy-devel dependency if the speedup is not that significant


License
=======

gradunwarp is licensed under the terms of the MIT license. Please see the COPYING file in the distribution. gradunwarp also bundles Nibabel (http://nipy.org/nibabel ) which is licensed under the MIT license as well.


Credit
======
 * Jon Polimeni - gradunwarp follows his original MATLAB code
 * Karl Helmer - Project Incharge
 * Nibabel team
