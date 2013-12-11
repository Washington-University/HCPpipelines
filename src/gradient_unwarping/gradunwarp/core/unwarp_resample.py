### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ##
#
#   See COPYING file distributed along with the gradunwarp package for the
#   copyright and license terms.
#
### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ##
import numpy as np
import sys
import pdb
import gc
import math
import logging
from scipy import ndimage
import utils
from utils import CoordsVector as CV
from utils import factorial
import globals
from globals import siemens_max_det
import nibabel as nib
import subprocess

#np.seterr(all='raise')

log = logging.getLogger('gradunwarp')


class Unwarper(object):
    '''
    '''
    def __init__(self, vol, m_rcs2ras, vendor, coeffs, fileName):
        '''
        '''
        self.vol = vol
        self.m_rcs2ras = m_rcs2ras
        self.vendor = vendor
        self.coeffs = coeffs
        self.name=fileName
        self.warp = False
        self.nojac = False
        self.m_rcs2lai = None

        # grid is uninit by default
        self.fovmin = None
        self.fovmax = None
        self.numpoints = None

        # interpolation order ( 1 = linear)
        self.order = 1

    def eval_spharm_grid(self, vendor, coeffs):
        ''' 
        We evaluate the spherical harmonics on a less sampled grid.
        This is a spacetime vs accuracy tradeoff.
        '''
        # init the grid first
        if not self.fovmin:
            fovmin = globals.siemens_fovmin
        else:
            fovmin = self.fovmin
        if not self.fovmax:
            fovmax = globals.siemens_fovmax
        else:
            fovmax = self.fovmax
        if not self.numpoints:
            numpoints = globals.siemens_numpoints
        else:
            numpoints = self.numpoints

        # convert to mm
        fovmin = fovmin * 1000.
        fovmax = fovmax * 1000.
        # the grid in meters. this is needed for spherical harmonics
        vec = np.linspace(fovmin, fovmax, numpoints)
        gvx, gvy, gvz = utils.meshgrid(vec, vec, vec)
        # mm
        cf = (fovmax - fovmin) / numpoints
        
        # deduce the transformation from rcs to grid
        g_rcs2xyz = np.array( [[0, cf, 0, fovmin],
                               [cf, 0, 0, fovmin],
                               [0, 0, cf, fovmin],
                               [0, 0, 0, 1]], dtype=np.float32 )

        # get the grid to rcs transformation also
        g_xyz2rcs = np.linalg.inv(g_rcs2xyz)

        # indices into the gradient displacement vol
        gr, gc, gs = utils.meshgrid(np.arange(numpoints), np.arange(numpoints),
                                 np.arange(numpoints), dtype=np.float32)

        log.info('Evaluating spherical harmonics')
        log.info('on a ' + str(numpoints) + '^3 grid')
        log.info('with extents ' + str(fovmin) + 'mm to ' + str(fovmax) + 'mm')
        gvxyz = CV(gvx, gvy, gvz)
        _dv, _dxyz = eval_spherical_harmonics(coeffs, vendor, gvxyz)
            
        return CV(_dv.x, _dv.y, _dv.z), g_xyz2rcs


    def run(self):
        '''
        '''
        #pdb.set_trace()
        # define polarity based on the warp requested
        self.polarity = 1.
        if self.warp:
            self.polarity = -1.

        # Evaluate spherical harmonics on a smaller grid 
        dv, g_xyz2rcs = self.eval_spharm_grid(self.vendor, self.coeffs)

        # transform RAS-coordinates into LAI-coordinates
        m_ras2lai = np.array([[-1.0, 0.0, 0.0, 0.0],
                             [0.0, 1.0, 0.0, 0.0],
                             [0.0, 0.0, -1.0, 0.0],
                             [0.0, 0.0, 0.0, 1.0]], dtype=np.float)
        m_rcs2lai = np.dot(m_ras2lai, self.m_rcs2ras)
        m_rcs2lai_nohalf = m_rcs2lai[:, :]

        # indices of image volume
        '''
        nr, nc, ns = self.vol.shape[:3]
        vc3, vr3, vs3 = utils.meshgrid(np.arange(nr), np.arange(nc), np.arange(ns), dtype=np.float32)
        vrcs = CV(x=vr3, y=vc3, z=vs3)
        vxyz = utils.transform_coordinates(vrcs, m_rcs2lai)
        '''

        # account for half-voxel shift in R and C directions
        halfvox = np.zeros((4, 4))
        halfvox[0, 3] = m_rcs2lai[0, 0] / 2.0
        halfvox[1, 3] = m_rcs2lai[1, 1] / 2.0
        #m_rcs2lai = m_rcs2lai + halfvox

        # extract rotational and scaling parts of the transformation matrix
        # ignore the translation part
        r_rcs2lai = np.eye(4, 4)
        r_rcs2lai[:3, :3] = m_rcs2lai[:3, :3]

        # Jon Polimeni:
        # Since partial derivatives in Jacobian Matrix are differences
        # that depend on the ordering of the elements of the 3D array, the
        # coordinates may increase in the opposite direction from the array
        # indices, in which case the differential element should be negative.
        # The differentials can be determined by mapping a vector of 1s
        # through rotation and scaling, where any mirror
        # will impose a negation
        ones = CV(1., 1., 1.)
        dxyz = utils.transform_coordinates_old(ones, r_rcs2lai)

        # do the nonlinear unwarp
        if self.vendor == 'siemens':
            self.out, self.vjacout = self.non_linear_unwarp_siemens(self.vol.shape, dv, dxyz,
                                                                 m_rcs2lai, m_rcs2lai_nohalf, g_xyz2rcs)

    def non_linear_unwarp_siemens(self, volshape, dv, dxyz, m_rcs2lai, m_rcs2lai_nohalf, g_xyz2rcs):
        ''' Performs the crux of the unwarping.
        It's agnostic to Siemens or GE and uses more functions to
        do the processing separately.

        Needs self.vendor, self.coeffs, self.warp, self.nojac to be set

        Parameters
        ----------
        vxyz : CoordsVector (namedtuple) contains np.array
            has 3 elements x,y and z each representing the grid coordinates
        dxyz : CoordsVector (namedtuple)
           differential coords vector

        Returns
        -------
        TODO still vague what to return
        vwxyz : CoordsVector (namedtuple) contains np.array
            x,y and z coordinates of the unwarped coordinates
        vjacmult_lps : np.array
            the jacobian multiplier (determinant)
        '''
        log.info('Evaluating the jacobian multiplier')
        nr, nc, ns = self.vol.shape[:3]
        if not self.nojac:
            jim2 = np.zeros((nr, nc), dtype=np.float32)
            vjacdet_lpsw = np.zeros((nr, nc), dtype=np.float32)
            if dxyz == 0:
                vjacdet_lps = 1
            else:
                vjacdet_lps = eval_siemens_jacobian_mult(dv, dxyz)

        # essentially pre-allocating everything 
        out = np.zeros((nr, nc, ns), dtype=np.float32)
        fullWarp = np.zeros((nr, nc, ns, 3), dtype=np.float32)

        vjacout = np.zeros((nr, nc, ns), dtype=np.float32)
        im2 = np.zeros((nr, nc), dtype=np.float32)
        dvx = np.zeros((nr, nc), dtype=np.float32)
        dvy = np.zeros((nr, nc), dtype=np.float32)
        dvz = np.zeros((nr, nc), dtype=np.float32)
        im_ = np.zeros((nr, nc), dtype=np.float32)
        # init jacobian temp image
        vc, vr = utils.meshgrid(np.arange(nc), np.arange(nr))

        log.info('Unwarping slice by slice')
        # for every slice
        for s in xrange(ns):
            # pretty print
            sys.stdout.flush()
            if (s+1) % 10 == 0:
                print s+1,
            else:
                print '.',
                
            # hopefully, free memory
            gc.collect()
            # init to 0
            dvx.fill(0.)
            dvy.fill(0.)
            dvz.fill(0.)
            im_.fill(0.)
            
            vs = np.ones(vr.shape) * s
            vrcs = CV(vr, vc, vs)
            vxyz = utils.transform_coordinates(vrcs, m_rcs2lai_nohalf)
            vrcsg = utils.transform_coordinates(vxyz, g_xyz2rcs)
            ndimage.interpolation.map_coordinates(dv.x,
                                                  vrcsg,
                                                  output=dvx,
                                                  order=self.order)
            ndimage.interpolation.map_coordinates(dv.y,
                                                  vrcsg,
                                                  output=dvy,
                                                  order=self.order)
            ndimage.interpolation.map_coordinates(dv.z,
                                                  vrcsg,
                                                  output=dvz,
                                                  order=self.order)
            # new locations of the image voxels in XYZ ( LAI ) coords

            #dvx.fill(0.)
            #dvy.fill(0.)
            #dvz.fill(0.)
            
            vxyzw = CV(x=vxyz.x + self.polarity * dvx,
                       y=vxyz.y + self.polarity * dvy,
                       z=vxyz.z + self.polarity * dvz)

            # convert the locations got into RCS indices
            vrcsw = utils.transform_coordinates(vxyzw,
                                                np.linalg.inv(m_rcs2lai))
            # map the internal voxel coordinates to FSL scaled mm coordinates
            pixdim1=float((subprocess.Popen(['fslval', self.name,'pixdim1'], stdout=subprocess.PIPE).communicate()[0]).strip())
            pixdim2=float((subprocess.Popen(['fslval', self.name,'pixdim2'], stdout=subprocess.PIPE).communicate()[0]).strip())
            pixdim3=float((subprocess.Popen(['fslval', self.name,'pixdim3'], stdout=subprocess.PIPE).communicate()[0]).strip())
            dim1=float((subprocess.Popen(['fslval', self.name,'dim1'], stdout=subprocess.PIPE).communicate()[0]).strip())
            outputOrient=subprocess.Popen(['fslorient', self.name], stdout=subprocess.PIPE).communicate()[0]
            if outputOrient.strip() == 'NEUROLOGICAL':
                # if neurological then flip x coordinate (both here in premat and later in postmat)
                m_vox2fsl = np.array([[-1.0*pixdim1, 0.0, 0.0, pixdim1*(dim1-1)],
                                  [0.0, pixdim2, 0.0, 0.0],
                                  [0.0, 0.0, pixdim3, 0.0],
                                  [0.0, 0.0, 0.0, 1.0]], dtype=np.float)
            else:
                m_vox2fsl = np.array([[pixdim1, 0.0, 0.0, 0.0],
                                  [0.0, pixdim2, 0.0, 0.0],
                                  [0.0, 0.0, pixdim3, 0.0],
                                  [0.0, 0.0, 0.0, 1.0]], dtype=np.float)
                
            vfsl = utils.transform_coordinates(vrcsw, m_vox2fsl)


            #im_ = utils.interp3(self.vol, vrcsw.x, vrcsw.y, vrcsw.z)
            ndimage.interpolation.map_coordinates(self.vol,
                                                  vrcsw,
                                                  output=im_,
                                                  order=self.order)
            # find NaN voxels, and set them to 0
            im_[np.where(np.isnan(im_))] = 0.
            im_[np.where(np.isinf(im_))] = 0.
            im2[vr, vc] = im_

            #img = nib.Nifti1Image(dvx,np.eye(4))
            #nib.save(img,"x"+str(s).zfill(3)+".nii.gz")
            #img = nib.Nifti1Image(dvy,np.eye(4))
            #nib.save(img,"y"+str(s).zfill(3)+".nii.gz")
            #img = nib.Nifti1Image(dvz,np.eye(4))
            #nib.save(img,"z"+str(s).zfill(3)+".nii.gz")

            # Multiply the intensity with the Jacobian det, if needed
            if not self.nojac:
                vjacdet_lpsw.fill(0.)
                jim2.fill(0.)
                # if polarity is negative, the jacobian is also inversed
                if self.polarity == -1:
                    vjacdet_lps = 1. / vjacdet_lps

                ndimage.interpolation.map_coordinates(vjacdet_lps,
                                                      vrcsg,
                                                      output=vjacdet_lpsw,
                                                      order=self.order)
                vjacdet_lpsw[np.where(np.isnan(vjacdet_lpsw))] = 0.
                vjacdet_lpsw[np.where(np.isinf(vjacdet_lpsw))] = 0.
                jim2[vr, vc] = vjacdet_lpsw
                im2 = im2 * jim2
                vjacout[..., s] = jim2

            fullWarp[...,s,0]=vfsl.x
            fullWarp[...,s,1]=vfsl.y
            fullWarp[...,s,2]=vfsl.z
            out[..., s] = im2

        print
       
        img=nib.Nifti1Image(fullWarp,self.m_rcs2ras)
        nib.save(img,"fullWarp_abs.nii.gz")
        # return image and the jacobian
        return out, vjacout

    def write(self, outfile):
        log.info('Writing output to ' + outfile)
        # if out datatype is float64 make it float32
        if self.out.dtype == np.float64:
            self.out = self.out.astype(np.float32)
        if outfile.endswith('.nii') or outfile.endswith('.nii.gz'):
            img = nib.Nifti1Image(self.out, self.m_rcs2ras)
        if outfile.endswith('.mgh') or outfile.endswith('.mgz'):
            #self.out = self.out.astype(self.vol.dtype)
            img = nib.MGHImage(self.out, self.m_rcs2ras)
        nib.save(img, outfile)


def eval_siemens_jacobian_mult(F, dxyz):
    '''
    '''
    d0, d1, d2 = dxyz.x, dxyz.y, dxyz.z
    #print F.x.shape, d0, d1, d2

    if d0 == 0 or d1 == 0 or d2 == 0:
        raise ValueError('weirdness found in Jacobian calculation')

    dFxdx, dFxdy, dFxdz = np.gradient(F.x, d0, d1, d2)
    dFydx, dFydy, dFydz = np.gradient(F.y, d0, d1, d2)
    dFzdx, dFzdy, dFzdz = np.gradient(F.z, d0, d1, d2)

    jacdet = (1. + dFxdx) * (1. + dFydy) * (1. + dFzdz) \
           - (1. + dFxdx) * dFydz * dFzdy \
           - dFxdy * dFydx * (1. + dFzdz) \
           + dFxdy * dFydz * dFzdx \
           + dFxdz * dFydx * dFzdy \
           - dFxdz * (1. + dFydy) * dFzdx
    jacdet = np.abs(jacdet)
    jacdet[np.where(jacdet > siemens_max_det)] = siemens_max_det

    return jacdet


def eval_spherical_harmonics(coeffs, vendor, vxyz):
    ''' Evaluate spherical harmonics

    Parameters
    ----------
    coeffs : Coeffs (namedtuple)
        the sph. harmonics coefficients got by parsing
    vxyz : CoordsVector (namedtuple). Could be a scalar or a 6-element list
        the x, y, z coordinates
        in case of scalar or 3-element list, the coordinates are eval
        in the function
    resolution : float
        (optional) useful in case vxyz is scalar
    '''
    # convert radius into mm
    R0 = coeffs.R0_m  * 1000

    x, y, z = vxyz

    #pdb.set_trace()
    # log.info('calculating displacements (mm) '
    #        'using spherical harmonics coeffcients...')
    if vendor == 'siemens':
        log.info('along x...')
        bx = siemens_B(coeffs.alpha_x, coeffs.beta_x, x, y, z, R0)
        log.info('along y...')
        by = siemens_B(coeffs.alpha_y, coeffs.beta_y, x, y, z, R0)
        log.info('along z...')
        bz = siemens_B(coeffs.alpha_z, coeffs.beta_z, x, y, z, R0)
    else:
        # GE
        log.info('along x...')
        bx = ge_D(coeffs.alpha_x, coeffs.beta_x, x, y, z)
        log.info('along y...')
        by = ge_D(coeffs.alpha_y, coeffs.beta_y, x, y, z)
        log.info('along z...')
        bz = siemens_B(coeffs.alpha_z, coeffs.beta_z, x, y, z, R0)
        bz = ge_D(coeffs.alpha_z, coeffs.beta_z, x, y, z)

    return CV(bx * R0, by * R0, bz * R0), CV(x, y, z)


#@profile
def siemens_B(alpha, beta, x1, y1, z1, R0):
    ''' Calculate displacement field from Siemens coefficients
    '''
    nmax = alpha.shape[0] - 1
    x1 = x1 + 0.0001  # hack to avoid singularities at R=0

    # convert to spherical coordinates
    r = np.sqrt(x1 * x1 + y1 * y1 + z1 * z1)
    theta = np.arccos(z1 / r)
    phi = np.arctan2(y1 / r, x1 / r)

    b = np.zeros(x1.shape)
    for n in xrange(0, nmax + 1):
        f = np.power(r / R0, n)
        for m in xrange(0, n + 1):
            f2 = alpha[n, m] * np.cos(m * phi) + beta[n, m] * np.sin(m * phi)
            _ptemp = utils.legendre(n, m, np.cos(theta))
            #_ptemp = scipy.special.lpmv(m, n, np.cos(theta))
            normfact = 1
            # this is Siemens normalization
            if m > 0:
                normfact = math.pow(-1, m) * \
                math.sqrt(float((2 * n + 1) * factorial(n - m)) \
                          / float(2 * factorial(n + m)))
            _p = normfact * _ptemp
            b = b + f * _p * f2
    return b


def ge_D(alpha, beta, x1, y1, z1):
    ''' GE Gradwarp coeffs define the error rather than the total
    gradient field'''

    nmax = alpha.shape[0] - 1
    x1 = x1 + 0.0001  # hack to avoid singularities
    r = np.sqrt(x1 * x1 + y1 * y1 + z1 * z1)
    # For consistency with GE papers, use theta & phi -> phi & theta
    phi = np.arccos(z1 / r)
    theta = np.arctan2(y1 / r, x1 / r)

    r = r * 100.0  # GE wants cm, so meters -> cm
    d = np.zeros(x1.shape)

    for n in xrange(0, nmax + 1):
        # So GE uses the usual unnormalized legendre polys.
        f = np.power(r, n)
        for m in xrange(0, n + 1):
            f2 = alpha[n, m] * np.cos(m * theta) + beta[n, m] \
            * np.sin(m * theta)
            _p = utils.legendre(n, m, np.cos(phi))
            d = d + f * _p * f2
    d = d / 100.0  # cm back to meters
    return d
