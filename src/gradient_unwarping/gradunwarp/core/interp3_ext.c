/*
### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ##
#
#   See COPYING file distributed along with the gradunwarp package for the
#   copyright and license terms.
#
### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ### ##
*/
#include "Python.h"
#include "numpy/arrayobject.h"
#include <math.h>

# define CUBE(x)   ((x) * (x) * (x))
# define SQR(x)    ((x) * (x))

/* compile command
 gcc -shared -pthread -fPIC -fwrapv -O2 -Wall -fno-strict-aliasing -I/usr/include/python2.7 -o interp3_ext.so interp3_ext.c
 */
static PyObject *interp3(PyObject *self, PyObject *args);
float TriCubic (float px, float py, float pz, float *volume, int xDim, int yDim, int zDim);

// what function are exported
static PyMethodDef tricubicmethods[] = {
	{"_interp3", interp3, METH_VARARGS},
	{NULL, NULL}
};

// This function is essential for an extension for Numpy created in C
void initinterp3_ext() {
	(void) Py_InitModule("interp3_ext", tricubicmethods);
	import_array();
}

// the data should be FLOAT32 and should be ensured in the wrapper 
static PyObject *interp3(PyObject *self, PyObject *args)
{
	PyArrayObject *volume, *result, *C, *R, *S;
	float *pr, *pc, *ps;
        float *pvol, *pvc;
        int xdim, ydim, zdim;

	// We expect 4 arguments of the PyArray_Type
	if(!PyArg_ParseTuple(args, "O!O!O!O!", 
				&PyArray_Type, &volume,
				&PyArray_Type, &R,
				&PyArray_Type, &C,
				&PyArray_Type, &S)) return NULL;

	if ( NULL == volume ) return NULL;
	if ( NULL == C ) return NULL;
	if ( NULL == R ) return NULL;
	if ( NULL == S ) return NULL;

	// result matrix is the same size as C and is float
	result = (PyArrayObject*) PyArray_ZEROS(PyArray_NDIM(C), C->dimensions, NPY_FLOAT, 0); 
	// This is for reference counting ( I think )
	PyArray_FLAGS(result) |= NPY_OWNDATA; 

	// massive use of iterators to progress through the data
	PyArrayIterObject *itr_v, *itr_r, *itr_c, *itr_s;
    itr_v = (PyArrayIterObject *) PyArray_IterNew(result);
    itr_r = (PyArrayIterObject *) PyArray_IterNew(R);
    itr_c = (PyArrayIterObject *) PyArray_IterNew(C);
    itr_s = (PyArrayIterObject *) PyArray_IterNew(S);
    pvol = (float *)PyArray_DATA(volume);
    xdim = PyArray_DIM(volume, 0);
    ydim = PyArray_DIM(volume, 1);
    zdim = PyArray_DIM(volume, 2);
    //printf("%f\n", pvol[4*20*30 + 11*30 + 15]);
    while(PyArray_ITER_NOTDONE(itr_v)) 
    {
		pvc = (float *) PyArray_ITER_DATA(itr_v);
		pr = (float *) PyArray_ITER_DATA(itr_r);
		pc = (float *) PyArray_ITER_DATA(itr_c);
		ps = (float *) PyArray_ITER_DATA(itr_s);
        // The order is weird because the tricubic code below is 
        // for Fortran ordering. Note that the xdim changes fast in
        // the code, whereas the rightmost dim should change fast
        // in C multidimensional arrays.
		*pvc = TriCubic(*ps, *pc, *pr, pvol, zdim, ydim, xdim); 
		PyArray_ITER_NEXT(itr_v);
		PyArray_ITER_NEXT(itr_r);
		PyArray_ITER_NEXT(itr_c);
		PyArray_ITER_NEXT(itr_s);
    }

	return result;
}
		
/*
 * TriCubic - tri-cubic interpolation at point, p.
 *   inputs:
 *     px, py, pz - the interpolation point.
 *     volume - a pointer to the float volume data, stored in x,
 *              y, then z order (x index increasing fastest).
 *     xDim, yDim, zDim - dimensions of the array of volume data.
 *   returns:
 *     the interpolated value at p.
 *   note:
 *     rudimentary range checking is done in this function.
 */

float TriCubic (float px, float py, float pz, float *volume, int xDim, int yDim, int zDim)
{
  int             x, y, z;
  int    i, j, k;
  float           dx, dy, dz;
  float *pv;
  float           u[4], v[4], w[4];
  float           r[4], q[4];
  float           vox = 0;
  int             xyDim;

  xyDim = xDim * yDim;

  x = (int) px, y = (int) py, z = (int) pz;
  // necessary evil truncating at dim-2 because tricubic needs 2 more values
  // which is criminal near edges
  // future work includes doing trilinear for edge cases
  // range checking is extremely important here
  if (x < 2 || x > xDim-3 || y < 2 || y > yDim-3 || z < 2 || z > zDim-3) 
    return (0);

  dx = px - (float) x, dy = py - (float) y, dz = pz - (float) z;
  pv = volume + (x - 1) + (y - 1) * xDim + (z - 1) * xyDim;

  /* factors for Catmull-Rom interpolation */

  u[0] = -0.5 * CUBE (dx) + SQR (dx) - 0.5 * dx;
  u[1] = 1.5 * CUBE (dx) - 2.5 * SQR (dx) + 1;
  u[2] = -1.5 * CUBE (dx) + 2 * SQR (dx) + 0.5 * dx;
  u[3] = 0.5 * CUBE (dx) - 0.5 * SQR (dx);

  v[0] = -0.5 * CUBE (dy) + SQR (dy) - 0.5 * dy;
  v[1] = 1.5 * CUBE (dy) - 2.5 * SQR (dy) + 1;
  v[2] = -1.5 * CUBE (dy) + 2 * SQR (dy) + 0.5 * dy;
  v[3] = 0.5 * CUBE (dy) - 0.5 * SQR (dy);

  w[0] = -0.5 * CUBE (dz) + SQR (dz) - 0.5 * dz;
  w[1] = 1.5 * CUBE (dz) - 2.5 * SQR (dz) + 1;
  w[2] = -1.5 * CUBE (dz) + 2 * SQR (dz) + 0.5 * dz;
  w[3] = 0.5 * CUBE (dz) - 0.5 * SQR (dz);

  for (k = 0; k < 4; k++)
  {
    q[k] = 0;
    for (j = 0; j < 4; j++)
    {
      r[j] = 0;
      for (i = 0; i < 4; i++)
      {
        r[j] += u[i] * *pv;
        pv++;
      }
      q[k] += v[j] * r[j];
      pv += xDim - 4;
    }
    vox += w[k] * q[k];
    pv += xyDim - 4 * xDim;
  }
  return vox;
}
