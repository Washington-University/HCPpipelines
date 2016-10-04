#!/usr/bin/env python
#
# average_bvecs.py - Average pairs of bvals/bvecs together.
#
# Author: Paul McCarthy <pauldmccarthy@gmail.com>
#


from __future__ import print_function

import sys

import numpy        as np
import numpy.linalg as la


# Change this function to enable/disable verbose output
def log(msg):
    print(msg)  #Comment/Uncomment to remove log messages
    pass


def main(bvals1file,
         bvecs1file,
         bvals2file,
         bvecs2file,
         bvalsoutfile,
         bvecsoutfile,
         indicesoutfile,
         overlap1file,
         overlap2file):
    """Averages the bvals/bvecs pairs in the given files, and writes
    the averages out to new files.
    """
    
    bvals1 = loadFile(bvals1file, 1, [-1])
    bvals2 = loadFile(bvals2file, 1, [-1]) 
    bvecs1 = loadFile(bvecs1file, 2, [3, len(bvals1)])
    bvecs2 = loadFile(bvecs2file, 2, [3, len(bvals2)])

    # We have been given overlap files
    if overlap1file is not None and \
       overlap2file is not None:
        overlap1 = loadFile(overlap1file, 2, [-1, 2])
        overlap2 = loadFile(overlap2file, 2, [-1, 2])

    # No overlap files - assume
    # that all data is present
    else:
        numOverlaps = min(len(bvals1), len(bvals2))
        overlap1    = np.array([[numOverlaps, len(bvals1)]])
        overlap2    = np.array([[numOverlaps, len(bvals2)]])

    # Make sure the overlap files 
    # agree on the number of sessions
    if overlap1.shape[0] != overlap2.shape[0]:
        raise ValueError('Different number of sessions in overlap files')

    # Make sure that the two overlap
    # files agree on the number of
    # overlaps in each session
    if np.any(overlap1[:, 0] != overlap2[:, 0]):
        raise ValueError('Number of overlaps do not match')

    # Make sure that the overlap files
    # agree with the bval/vec files
    # on the total number of volumes
    if len(bvals1) != overlap1.sum(axis=0)[1] or \
       len(bvals2) != overlap2.sum(axis=0)[1]:
        raise ValueError('Number of volumes do not match')

    log('Number of sessions per data set:      {0}'.format(overlap1.shape[0]))
    log('Number of volumes in first data set:  {0}'.format(len(bvals1)))
    log('Number of volumes in second data set: {0}'.format(len(bvals2)))

    # Extract the directions which overlap
    # between the two sets of bvals/vecs
    bvals1, bvecs1, bvals2, bvecs2, indices1, indices2 = extract_overlaps(
        bvals1, bvecs1, bvals2, bvecs2, overlap1, overlap2)

    # Average the bvals/vecs
    bvals, bvecs = average_bvecs(bvals1, bvecs1, bvals2, bvecs2)

    # Make bvals a row vector, otherwise
    # it will be output as a column
    bvals = bvals.reshape((1, -1))

    # Make the indices two row vectors
    indices = np.array((indices1, indices2))
    
    # Write out the result
    np.savetxt(bvalsoutfile,   bvals,   fmt='%d')
    np.savetxt(bvecsoutfile,   bvecs,   fmt='%0.16f')
    np.savetxt(indicesoutfile, indices, fmt='%3.0d')


def loadFile(filename, ndims, dimlens):
    """Convenience function which loads data from a file, and checks
    that it has the correct number of dimensions/dimension sizes.
    """

    data = np.loadtxt(filename, dtype=np.float64)

    if len(data.shape) != ndims:
        raise ValueError('Wrong number of dimensions: {0}'.format(filename))

    for dim, dimlen in enumerate(dimlens):

        # Pass in a dimlen < 0 to skip
        # the size check for a dimension
        if dimlen < 0:
            continue

        if data.shape[dim] != dimlen:
            raise ValueError('Wrong shape: {0}'.format(filename))

    return data


def extract_overlaps(bvals1, bvecs1, bvals2, bvecs2, overlap1, overlap2):
    """Figures out the intersection of the bval/bvec pairs, given their
    session overlaps.

    Returns a tuple containing:

      - An array of bvals from the first set
      - Corresponding bvecs from the first set
      - Corresponding bvals from the second set
      - Corresponding bvecs from the second set
      - Indices of the bvals/bvecs included from the first set (starting from
        1)
      - Indices of the bvals/bvecs included from the second set (starting
        from 1)
    """

    session_bvals1 = [] 
    session_bvecs1 = []
    session_bvals2 = []
    session_bvecs2 = []

    session_bv1_indices = []
    session_bv2_indices = []

    nsessions = overlap1.shape[0]

    offset1 = 0
    offset2 = 0

    for session in range(nsessions):
        
        overlaps = overlap1[session, 0]

        log('Session {0} overlaps:          {1}'.format(session + 1, overlaps))
        log('Data set 1 session {0} offset: {1}'.format(session + 1, offset1))
        log('Data set 2 session {0} offset: {1}'.format(session + 1, offset2))

        bv1_indices = np.arange(offset1, offset1 + overlaps, dtype=np.int)
        bv2_indices = np.arange(offset2, offset2 + overlaps, dtype=np.int)

        session_bvals1     .append(bvals1[   bv1_indices])
        session_bvals2     .append(bvals2[   bv2_indices])

        session_bvecs1     .append(bvecs1[:, bv1_indices])
        session_bvecs2     .append(bvecs2[:, bv2_indices])

        # Indices start from 1
        session_bv1_indices.append(          bv1_indices + 1)
        session_bv2_indices.append(          bv2_indices + 1)

        offset1 += overlap1[session, 1]
        offset2 += overlap2[session, 1]

    bvals1   = np.concatenate(session_bvals1)
    bvals2   = np.concatenate(session_bvals2)
    bvecs1   = np.concatenate(session_bvecs1, axis=1)
    bvecs2   = np.concatenate(session_bvecs2, axis=1)
    indices1 = np.concatenate(session_bv1_indices)
    indices2 = np.concatenate(session_bv2_indices)

    return bvals1, bvecs1, bvals2, bvecs2, indices1, indices2

    
def average_bvecs(bvals1, bvecs1, bvals2, bvecs2):
    """Calculates the average of two sets of bvals and bvecs.

    For each pair of values/vectors:
    
      1. The vectors are scaled by their values
    
      2. The vectors are converted into tensor matrices
    
      3. The tensor matrices are averaged (element-wise)
    
      4. The 'average' vector and value are taken as the
         principal eigenvector, and the square root of the
         principal eigenvalue, of the summed tensor matrix.

    A pair of numpy arrays are returned, the first a 1D array
    containing the averaged bvals, and the second a numpy array
    of shape (3, N), containing the averaged bvecs.
    """

    ndirs = bvecs1.shape[1]
    
    avg_bvecs = np.zeros((3, ndirs))
    avg_bvals = np.zeros(    ndirs, dtype='i4')  # dtype='float32'

    for i in range(ndirs):

        bval1 = bvals1[i]
        bval2 = bvals2[i] 
        bvec1 = bvecs1[:, i]
        bvec2 = bvecs2[:, i]

        log('\nDirection {0}\n'.format(i))
        log('  bval1:    {0}'.format(bval1))
        log('  bval2:    {0}'.format(bval2))
        log('  bvec1:    {0}'.format(bvec1))
        log('  bvec2:    {0}'.format(bvec2))

        # Scale bvecs by their bvals, and
        # make sure they are 2D, so the
        # dot product below will work.
        bvec1 = bval1 * bvec1.reshape((3, 1))
        bvec2 = bval2 * bvec2.reshape((3, 1))

        # The average bvec/bval is the
        # principal eigenvector/eigenvalue
        # of the tensor matrix average
        bvecsum          = (np.dot(bvec1, bvec1.T) + np.dot(bvec2, bvec2.T)) / 2
        eigvals, eigvecs = la.eig(bvecsum)

        eigvalmax = np.argmax(eigvals)

        avg_bvecs[:, i] = eigvecs[:, eigvalmax]
        avg_bvals[i]    = np.rint(eigvals[   eigvalmax] ** 0.5)

        log('  avg_bval: {0}'.format(avg_bvals[   i]))
        log('  avg_bvec: {0}'.format(avg_bvecs[:, i]))

    return avg_bvals, avg_bvecs

    
if __name__ == '__main__':

    if len(sys.argv) not in (6, 8):
        print('usage: average_bvecs bvals1 bvecs1 '
              'bvals2 bvecs2 '
              'output_basename '
              '[overlap1 overlap2]')
        sys.exit(1)

    bvals1          = sys.argv[1]
    bvecs1          = sys.argv[2]
    bvals2          = sys.argv[3]
    bvecs2          = sys.argv[4]
    output_basename = sys.argv[5]
    bvals_out       = '{0}.bval'.format(output_basename)
    bvecs_out       = '{0}.bvec'.format(output_basename)
    indices_out     = '{0}.idxs'.format(output_basename)

    if len(sys.argv) == 6:
        overlap1 = None
        overlap2 = None
        
    else:
        overlap1 = sys.argv[6]
        overlap2 = sys.argv[7]

    main(bvals1,      bvecs1,
         bvals2,      bvecs2,
         bvals_out,   bvecs_out,
         indices_out, overlap1,
         overlap2)
