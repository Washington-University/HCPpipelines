FastICA
=======

Site: http://research.ics.aalto.fi/ica/fastica/

The FastICA package is a free (GPL) MATLAB program that implements the fast fixed-point algorithm for independent component analysis and projection pursuit. It features an easy-to-use graphical user interface, and a computationally powerful algorithm.

## Setup ##

To use the functions in this package, add:

    addpath('~/path-to-FastICA-folder')

to the start of your m-file. Otherwise, add it to your startup.m file to make the functions callable any time. If you don't have a startup.m file, or don't know what it is, follow these instructions:

Open Matlab and type:

    myPath = userpath   # default startup folder
    cd(myPath(1:end-1)  # (1:end-1) removes the trailing colon
    edit startup        # this will probably ask you if you want to create startup.m; click 'yes'

In the `startup.m` file, insert `addpath('~/path-to-FastICA-folder')` and save. 

Restart Matlab.
