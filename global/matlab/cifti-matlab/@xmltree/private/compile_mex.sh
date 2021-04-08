#!/bin/bash
set -eu

scriptdir=$(dirname "$0")

target=matlab

if (($# > 0))
then
    case "$1" in
        (--octave)
            target=octave
        ;;
        (--matlab)
            target=matlab
        ;;
        (*)
            echo "recognized options are --octave or --matlab, default is matlab" 1>&2
            exit 1
        ;;
    esac
fi

pushd "$scriptdir" &> /dev/null

case "$target" in
    (octave)
        mkoctfile --mex xml_findstr.c
    ;;
    (matlab)
        matlab -nodisplay -nosplash -nojvm <<<"mex xml_findstr.c"
        echo
    ;;
    (*)
        echo "internal error" 1>&2
        exit 2
    ;;
esac

popd &> /dev/null

