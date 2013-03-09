#!/usr/bin/env python
### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ##
#
#   See COPYING file distributed along with the gradunwarp package for the
#   copyright and license terms.
#
### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ##
import argparse as arg
import os
import logging
from gradunwarp.core import (globals, coeffs, utils)
from gradunwarp.core.unwarp_resample import Unwarper

log = globals.get_logger()


def argument_parse_gradunwarp():
    '''Arguments parser from the command line
    '''
    # initiate
    p = arg.ArgumentParser(version=globals.VERSION, usage=globals.usage)

    # required arguments
    p.add_argument('infile', action='store',
                  help='The input warped file (nifti or mgh)')
    p.add_argument('outfile', action='store',
                  help='The output unwarped file (extension should be .nii/.nii.gz/.mgh/.mgz)')
    p.add_argument('vendor', action='store', choices=['siemens', 'ge'], 
                  help='vendor (either "ge" or "siemens" for now)')

    coef_grp = p.add_mutually_exclusive_group(required=True)
    coef_grp.add_argument('-g', '--gradfile', dest='gradfile',
                         help='The .grad coefficient file')
    coef_grp.add_argument('-c', '--coeffile', dest='coeffile',
                         help='The .coef coefficient file')

    # optional arguments
    p.add_argument('-w', '--warp', action='store_true', default=False,
                  help='warp a volume (as opposed to unwarping)')
    p.add_argument('-n', '--nojacobian', dest='nojac', action='store_true',
                  default=False, help='Do not perform Jacobian intensity correction')
    p.add_argument('--fovmin', dest='fovmin',
                  help='the minimum extent of harmonics evaluation grid in meters')
    p.add_argument('--fovmax', dest='fovmax',
                  help='the maximum extent of harmonics evaluation grid in meters')
    p.add_argument('--numpoints', dest='numpoints',
                   help='number of grid points in each direction')
    p.add_argument('--interp_order', dest='order',
                   help='the order of interpolation(1..4) where 1 is linear - default')

    p.add_argument('--verbose', action='store_true', default=False)

    args = p.parse_args()

    # do some validation
    if not os.path.exists(args.infile):
        raise IOError(args.infile + ' not found')
    if args.gradfile:
        if not os.path.exists(args.gradfile):
            raise IOError(args.gradfile + ' not found')
    if args.coeffile:
        if not os.path.exists(args.coeffile):
            raise IOError(args.coeffile + ' not found')

    return args


class GradientUnwarpRunner(object):
    ''' Takes the option datastructure after parsing the commandline.
    run() method performs the actual unwarping
    write() method performs the writing of the unwarped volume
    '''
    def __init__(self, args):
        ''' constructor takes the option datastructure which is the
        result of (options, args) = parser.parse_args()
        '''
        self.args = args
        self.unwarper = None

        log.setLevel(logging.INFO)
        if hasattr(self.args, 'verbose'):
            log.setLevel(logging.DEBUG)

    def run(self):
        ''' run the unwarp resample
        '''
        # get the spherical harmonics coefficients from parsing
        # the given .coeff file xor .grad file
        if hasattr(self.args, 'gradfile') and self.args.gradfile:
            self.coeffs = coeffs.get_coefficients(self.args.vendor,
                                                 self.args.gradfile)
        else:
            self.coeffs = coeffs.get_coefficients(self.args.vendor,
                                                 self.args.coeffile)

        self.vol, self.m_rcs2ras = utils.get_vol_affine(self.args.infile)

        self.unwarper = Unwarper(self.vol, self.m_rcs2ras, self.args.vendor, self.coeffs, self.args.infile )
        if hasattr(self.args, 'fovmin') and self.args.fovmin:
            self.unwarper.fovmin = float(self.args.fovmin)
        if hasattr(self.args, 'fovmax') and self.args.fovmax:
            self.unwarper.fovmax = float(self.args.fovmax)
        if hasattr(self.args, 'numpoints') and self.args.numpoints:
            self.unwarper.numpoints = int(self.args.numpoints)
        if hasattr(self.args, 'warp') and self.args.warp:
            self.unwarper.warp = True
        if hasattr(self.args, 'nojac') and self.args.nojac:
            self.unwarper.nojac = True
        if hasattr(self.args, 'order') and self.args.order:
            self.unwarper.order = int(self.args.order)
        self.unwarper.run()

    def write(self):
        self.unwarper.write(self.args.outfile)


if __name__ == '__main__':
    args = argument_parse_gradunwarp()

    grad_unwarp = GradientUnwarpRunner(args)

    grad_unwarp.run()

    grad_unwarp.write()
