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

/* compile command
 gcc -shared -pthread -fPIC -fwrapv -O2 -Wall -fno-strict-aliasing -I/usr/include/python2.7 -o transform_coordinates_ext.so transform_coordinates_ext.c
 */
static PyObject *transform_coordinates(PyObject *self, PyObject *args);


// what function are exported
static PyMethodDef transform_coordinatesmethods[] = {
	{"_transform_coordinates", transform_coordinates, METH_VARARGS},
	{NULL, NULL}
};


// This function is essential for an extension for Numpy created in C
void inittransform_coordinates_ext() {
	(void) Py_InitModule("transform_coordinates_ext", transform_coordinatesmethods);
	import_array();
}


// the data should be FLOAT32 and should be ensured in the wrapper 
static PyObject *transform_coordinates(PyObject *self, PyObject *args)
{
    float *m;
    float *x, *y, *z, *xm, *ym, *zm;
    PyArrayObject *X, *Y, *Z, *mat;
    PyArrayObject *Xm, *Ym, *Zm;
	// We expect 4 arguments of the PyArray_Type
	if(!PyArg_ParseTuple(args, "O!O!O!O!", 
                &PyArray_Type, &X,
                &PyArray_Type, &Y,
                &PyArray_Type, &Z,
                &PyArray_Type, &mat)) return NULL;

    if ( NULL == X ) return NULL;
    if ( NULL == Y ) return NULL;
    if ( NULL == Z ) return NULL;
    if ( NULL == mat ) return NULL;

    // result matrices are the same size and float
	Xm = (PyArrayObject*) PyArray_ZEROS(PyArray_NDIM(X), X->dimensions, NPY_FLOAT, 0); 
	Ym = (PyArrayObject*) PyArray_ZEROS(PyArray_NDIM(X), X->dimensions, NPY_FLOAT, 0); 
	Zm = (PyArrayObject*) PyArray_ZEROS(PyArray_NDIM(X), X->dimensions, NPY_FLOAT, 0); 
  
	// This is for reference counting ( I think )
	PyArray_FLAGS(Xm) |= NPY_OWNDATA; 
	PyArray_FLAGS(Ym) |= NPY_OWNDATA; 
	PyArray_FLAGS(Zm) |= NPY_OWNDATA; 

	// massive use of iterators to progress through the data
	PyArrayIterObject *itr_x, *itr_y, *itr_z;
	PyArrayIterObject *itr_xm, *itr_ym, *itr_zm;
    itr_x = (PyArrayIterObject *) PyArray_IterNew(X);
    itr_y = (PyArrayIterObject *) PyArray_IterNew(Y);
    itr_z = (PyArrayIterObject *) PyArray_IterNew(Z);
    itr_xm = (PyArrayIterObject *) PyArray_IterNew(Xm);
    itr_ym = (PyArrayIterObject *) PyArray_IterNew(Ym);
    itr_zm = (PyArrayIterObject *) PyArray_IterNew(Zm);
    /*m = (float *)PyArray_DATA(mat);
    printf("%f %f %f %f\n", m[0], m[1], m[2], m[3]);
    printf("%f %f %f %f\n", m[4], m[5], m[6], m[7]);
    printf("%f %f %f %f\n", m[8], m[9], m[10], m[11]);
    */
    float *m00, *m01, *m02, *m03;
    float *m10, *m11, *m12, *m13;
    float *m20, *m21, *m22, *m23;
    m00 = (float *)PyArray_GETPTR2(mat, 0, 0);
    m01 = (float *)PyArray_GETPTR2(mat, 0, 1);
    m02 = (float *)PyArray_GETPTR2(mat, 0, 2);
    m03 = (float *)PyArray_GETPTR2(mat, 0, 3);
    m10 = (float *)PyArray_GETPTR2(mat, 1, 0);
    m11 = (float *)PyArray_GETPTR2(mat, 1, 1);
    m12 = (float *)PyArray_GETPTR2(mat, 1, 2);
    m13 = (float *)PyArray_GETPTR2(mat, 1, 3);
    m20 = (float *)PyArray_GETPTR2(mat, 2, 0);
    m21 = (float *)PyArray_GETPTR2(mat, 2, 1);
    m22 = (float *)PyArray_GETPTR2(mat, 2, 2);
    m23 = (float *)PyArray_GETPTR2(mat, 2, 3);

    // start the iteration
    while(PyArray_ITER_NOTDONE(itr_x))
    {
        x = (float *) PyArray_ITER_DATA(itr_x);
        y = (float *) PyArray_ITER_DATA(itr_y);
        z = (float *) PyArray_ITER_DATA(itr_z);
        xm = (float *) PyArray_ITER_DATA(itr_xm);
        ym = (float *) PyArray_ITER_DATA(itr_ym);
        zm = (float *) PyArray_ITER_DATA(itr_zm);

        // transform coordinates
        *xm = *x * *m00 + *y * *m01 + *z * *m02 + *m03;
        *ym = *x * *m10 + *y * *m11 + *z * *m12 + *m13;
        *zm = *x * *m20 + *y * *m21 + *z * *m22 + *m23;

		PyArray_ITER_NEXT(itr_x);
		PyArray_ITER_NEXT(itr_y);
		PyArray_ITER_NEXT(itr_z);
		PyArray_ITER_NEXT(itr_xm);
		PyArray_ITER_NEXT(itr_ym);
		PyArray_ITER_NEXT(itr_zm);
    }

 return Py_BuildValue("OOO", Xm, Ym, Zm);
}
