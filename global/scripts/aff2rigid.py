#!/usr/bin/env python

import sys
from sys import argv
from commands import getoutput
from numpy import *

def usage():
    print "Usage: " + argv[0] + " <input2standard mat> <output mat>"
    print " "
    print "       First argument is the FLIRT transform (12 DOF) from the input image to standard"
    print "       Second argument is the output matrix which will go from the input image to standard space (6 DOF)"
    print "          aligning the AC, the AC-PC line and the mid-sagittal plane (in order of decreasing accuracy)"
    sys.exit(1)

if len(argv) < 2:
    usage()

# Load in the necessary info
a=loadtxt(argv[1])
# set specific AC and PC coordinates in FLIRT convention (x1=AC, x2=PC, x3=point above x1 in the mid-sag plane)
x1=matrix([[91],[129],[67],[1]])
x2=matrix([[91],[100],[70],[1]])
x3=matrix([[91],[129],[117],[1]])

ainv=linalg.inv(a)

# vectors v are in MNI space, vectors w are in native space
v21=(x2-x1)
v31=(x3-x1)
# normalise and force orthogonality
v21=v21/linalg.norm(v21)
v31=v31-multiply(v31.T * v21,v21)
v31=v31/linalg.norm(v31)
tmp=cross(v21[0:3,0].T,v31[0:3,0].T).T
v41=mat(zeros((4,1)))
v41[0:3,0]=tmp
# Map vectors to native space
w21=ainv*(v21)
w31=ainv*(v31)
# normalise and force orthogonality
w21=w21/linalg.norm(w21)
w31=w31-multiply(w31.T * w21,w21)
w31=w31/linalg.norm(w31)
tmp=cross(w21[0:3,0].T,w31[0:3,0].T).T
w41=mat(zeros((4,1)))
w41[0:3,0]=tmp

# setup matrix: native to MNI space
r1=matrix(eye(4))
r1[0:4,0]=w21
r1[0:4,1]=w31
r1[0:4,2]=w41
r2=matrix(eye(4))
r2[0,0:4]=v21.T
r2[1,0:4]=v31.T
r2[2,0:4]=v41.T
r=r2.T*r1.T

# Fix the translation (keep AC=x1 in the same place)
ACmni=x1
ACnat=ainv*x1
trans=ACmni-r*ACnat
r[0:3,3]=trans[0:3]

# Save out the result
savetxt(argv[2],r,fmt='%14.10f')


