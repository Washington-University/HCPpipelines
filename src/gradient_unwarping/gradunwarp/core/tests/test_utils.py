### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ##
#
#   See COPYING file distributed along with the NiBabel package for the
#   copyright and license terms.
#
### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ##
'''Test multiple utils'''
import os
import numpy as np
from numpy.testing import assert_equal, assert_array_equal, \
    assert_array_almost_equal, assert_almost_equal
from gradunwarp.core.utils import interp3
from gradunwarp.core.utils import legendre


def test_interp3():
    arr = np.linspace(-4, 4, 6000)
    arr = np.sin(arr)
    arr = arr.reshape(10, 20, 30).astype('float32')

    # sanity check
    ex1 = arr[4, 11, 15]
    ac1 = interp3(arr, np.array([4.]), np.array([11.]), np.array([15.]))
    assert_almost_equal(ex1, ac1[0], 5)

    ex2 = arr[5, 12, 16]
    ac2 = interp3(arr, np.array([5.]), np.array([12.]), np.array([16.]))
    assert_almost_equal(ex2, ac2[0], 5)

    ex3 = np.array([-0.33291185, -0.24946867, -0.1595035,
                    -0.06506295,  0.03180848, 0.12906794,
                    0.22467692,  0.31659847,  0.40280011,
                    0.48125309])
    gridn = 10
    R1 = np.linspace(4., 5., gridn).astype('float32')
    C1 = np.linspace(11., 12., gridn).astype('float32')
    S1 = np.linspace(15., 16., gridn).astype('float32')
    ac3 = interp3(arr, R1, C1, S1)
    assert_array_almost_equal(ex3, ac3)


def test_legendre():
    arr = np.array([0.1, 0.2, 0.3])
    ex1 = np.array([44.83644, 75.85031, 82.44417])
    ac1 = legendre(6, 3, arr)
    assert_array_almost_equal(ex1, ac1, 5)
