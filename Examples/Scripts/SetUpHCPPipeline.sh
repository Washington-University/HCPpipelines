#!/bin/echo This script should be sourced before calling a pipeline script, and should not be run directly:

SAVEHCPPIPE="${HCPPIPEDIR:-}"

## Environment variable for location of HCP Pipeline for the HCP Pipeline
## If you leave it blank, and $HCPPIPEDIR already exists in the environment,
## that will be used instead (via the SAVEHCPPIPE variable, defined above)
export HCPPIPEDIR=

## Set up other environment variables
export MSMBINDIR="${HOME}/pipeline_tools/MSM"
export MATLAB_COMPILER_RUNTIME=/export/matlab/MCR/R2017b/v93
export FSL_FIXDIR=/usr/local/fix
# if a suitable version of wb_command is on your $PATH, CARET7DIR can be blank
export CARET7DIR=

## Set up FSL (if not already done so in the running environment)
## Uncomment the following 2 lines (remove the leading #) and correct the FSLDIR setting for your setup
#export FSLDIR=/usr/local/fsl
#source "$FSLDIR/etc/fslconf/fsl.sh"

## Let FreeSurfer explicitly know what version of FSL to use (this shouldn't need changing)
export FSL_DIR="${FSLDIR}"

## Set up FreeSurfer (if not already done so in the running environment)
## Uncomment the following 2 lines (remove the leading #) and correct the FREESURFER_HOME setting for your setup
#export FREESURFER_HOME=/usr/local/bin/freesurfer
#source ${FREESURFER_HOME}/SetUpFreeSurfer.sh > /dev/null 2>&1

# Trick to allow certain setups to source an unmodified SetUp... and get some functionality
if [[ -z "$HCPPIPEDIR" ]]
then
    if [[ -z "$SAVEHCPPIPE" ]]
    then
        export HCPPIPEDIR="$HOME/HCPpipelines"
    else
        export HCPPIPEDIR="$SAVEHCPPIPE"
    fi
fi

# If you want to use MSM Configuration files other than those already provided, can change the following
export MSMCONFIGDIR="${HCPPIPEDIR}/MSMConfig"


# ---------------------------------------------------------
# Users probably won't need to edit anything below this line
# ---------------------------------------------------------

# Sanity check things and/or populate from $PATH

# FSL
if [[ -z "${FSLDIR:-}" ]]
then
    found_fsl=$(which fslmaths || true)
    if [[ ! -z "$found_fsl" ]]
    then
        #like our scripts, assume $FSLDIR/bin/fslmaths (neurodebian doesn't follow this, so sanity check)
        #yes, quotes nest properly inside of $()
        export FSLDIR=$(dirname "$(dirname "$found_fsl")")
        #if we didn't have FSLDIR, assume we haven't sourced fslconf
        if [[ ! -f "$FSLDIR/etc/fslconf/fsl.sh" ]]
        then
            echo "FSLDIR was unset, and guessed FSLDIR ($FSLDIR) does not contain etc/fslconf/fsl.sh, please specify FSLDIR in the setup script" 1>&2
            #NOTE: do not "exit", as this will terminate an interactive shell - the pipeline should sanity check a few things, and will hopefully catch it quickly
        else
            source "$FSLDIR/etc/fslconf/fsl.sh"
        fi
    else
        echo "fslmaths not found in \$PATH, please install FSL and ensure it is on \$PATH, or edit the setup script to specify its location" 1>&2
    fi
fi
if [[ ! -x "$FSLDIR/bin/fslmaths" ]]
then
    echo "FSLDIR ($FSLDIR) does not contain bin/fslmaths, please fix the settings in the setup script" 1>&2
fi

# Workbench
if [[ -z "$CARET7DIR" ]]
then
    found_wb=$(which wb_command || true)
    if [[ ! -z "$found_wb" ]]
    then
        CARET7DIR=$(dirname "$found_wb")
    else
        echo "wb_command not found in \$PATH, please install connectome workbench and ensure it is on \$PATH, or edit the setup script to specify its location" 1>&2
    fi
fi
if [[ ! -x "$CARET7DIR/wb_command" ]]
then
    echo "CARET7DIR ($CARET7DIR) does not contain wb_command, please fix the settings in the setup script" 1>&2
fi

# Add the specified versions of some things to the front of $PATH, so we can stop using absolute paths everywhere
export PATH="$CARET7DIR:$FSLDIR/bin:$PATH"

# Source extra stuff that pipelines authors may need to edit, but users shouldn't ever need to
# by separating them this way, a user can continue to use their previous setup file even if we
# rearrange some internal things
if [[ ! -f "$HCPPIPEDIR/global/scripts/finish_hcpsetup.shlib" ]]
then
    echo "HCPPIPEDIR ($HCPPIPEDIR) appears to be set to an old version of the pipelines, please check the setting (or start from the older SetUpHCPPipeline.sh to run the older pipelines)"
fi

source "$HCPPIPEDIR/global/scripts/finish_hcpsetup.shlib"

