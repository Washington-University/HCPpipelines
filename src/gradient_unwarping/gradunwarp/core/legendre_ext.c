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
 gcc -shared -pthread -fPIC -fwrapv -O2 -Wall -fno-strict-aliasing -I/usr/include/python2.7 -o legendre_ext.so legendre_ext.c
 */
static PyObject *legendre(PyObject *self, PyObject *args);
long odd_factorial(int k);

// what function are exported
static PyMethodDef legendremethods[] = {
	{"_legendre", legendre, METH_VARARGS},
	{NULL, NULL}
};

// This function is essential for an extension for Numpy created in C
void initlegendre_ext() {
	(void) Py_InitModule("legendre_ext", legendremethods);
	import_array();
}

// the data should be FLOAT32 and should be ensured in the wrapper 
static PyObject *legendre(PyObject *self, PyObject *args)
{
	PyArrayObject *x, *result;
    long nu, mu;

	// We expect 1 argument of the PyArray_Type
    // and 2 of Python float32
	if(!PyArg_ParseTuple(args, "llO!", 
                &nu, &mu,
				&PyArray_Type, &x)) return NULL;

	if ( NULL == x ) return NULL;

    // Error check
    if ( mu < 0.0 || mu > nu )
    {
        printf("Error!: require legendre computation to have 0 <= mu <=nu,\n");
        printf("but mu=%d and nu=%d\n", mu, nu);
        return NULL; 
    }

	//result matrix is the same size as x and is float
	result = (PyArrayObject*) PyArray_ZEROS(PyArray_NDIM(x), x->dimensions, NPY_FLOAT, 0); 
	// This is for reference counting ( I think )
	PyArray_FLAGS(result) |= NPY_OWNDATA; 

    PyArrayIterObject *itr_x, *itr_r;
    int s, n;
    float *px, *pr, p_nu, p_nu_prev;

    itr_x = (PyArrayIterObject *) PyArray_IterNew(x);
    itr_r = (PyArrayIterObject *) PyArray_IterNew(result);
    while(PyArray_ITER_NOTDONE(itr_x)) 
    {
		px = (float *) PyArray_ITER_DATA(itr_x);
        // unfortunate error check in the main loop
        if ( abs(*px) > 1.0 )
        {
            printf("Error! require -1 <= x <= 1 in the legendre computation.\n");
            printf("but got x=%f\n", x);
            return NULL; 
        }
		pr = (float *) PyArray_ITER_DATA(itr_r);

        // Compute the initial term in the recursion
        if ( mu )
        {
           s = 1;
           if ( mu & 1)
              s = -1;
              p_nu = s * odd_factorial(2 * mu - 1) * pow(sqrt( 1.0 - *px * *px), mu);
        }
        else 
           p_nu = 1.0;

        // special case.. clear up and return
        if ( mu == nu )
        {
            *pr = p_nu;
		    PyArray_ITER_NEXT(itr_x);
		    PyArray_ITER_NEXT(itr_r);
            continue;
        }

        // compute the next term in recursion
        p_nu_prev = p_nu;
        p_nu = *px * (2 * mu + 1) * p_nu;

        // special case.. clear up and return
        if ( nu == mu + 1)
        {
            *pr = p_nu;
		    PyArray_ITER_NEXT(itr_x);
		    PyArray_ITER_NEXT(itr_r);
            continue;
        }

        for(n=mu+2; n<nu+1; n++)
        {
            *pr = (*px * (2 * n - 1) * p_nu - (n + mu - 1) * p_nu_prev) / (n - mu);
            p_nu_prev = p_nu;
            p_nu = *pr;
        }

		PyArray_ITER_NEXT(itr_x);
		PyArray_ITER_NEXT(itr_r);
    }

    return result;
}

long odd_factorial(int k)
{
    long f = (long)k;
    while ( k >= 3)
    {
        k -= 2;
        f *= k;
    }
    return f;
}
