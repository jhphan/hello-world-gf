#!/bin/bash

# Template for GeneFlow App wrapper scripts



###############################################################################
#### Helper Functions ####
###############################################################################

## MODIFY >>> *****************************************************************
## Usage description should match command line arguments defined below
usage () {
    echo "Usage: $(basename $0) [-h] -f file -o output [-x exec_method]"
    echo "  -f,--file         Input file"
    echo "  -o,--output       Output file"
    echo "  -x,--exec_method  Execution method (cdc-module, package)"
    echo "  -h,--help         Display this help message"
}
## ***************************************************************** <<< MODIFY

# report error code for command
safeRunCommand() {
    cmd="$@"
    eval $cmd
    ERROR_CODE=$?
    if [ ${ERROR_CODE} -ne 0 ]; then
        echo "Error when executing command '${cmd}'"
        exit ${ERROR_CODE}
    fi
}

# always report exit code
reportExit() {
    rv=$?
    echo "Exit code: ${rv}"
    exit $rv
}

trap "reportExit" EXIT



###############################################################################
#### Parse Command-Line Arguments ####
###############################################################################

getopt --test > /dev/null
if [[ $? -ne 4 ]]; then
    echo "`getopt --test` failed in this environment."
    exit 1
fi

## MODIFY >>> *****************************************************************
## Command line options should match usage description
OPTIONS=hf:o:x:
LONGOPTIONS=help,file:,output:,exec_method:
## ***************************************************************** <<< MODIFY

# -temporarily store output to be able to check for errors
# -e.g. use "--options" parameter by name to activate quoting/enhanced mode
# -pass arguments only via   -- "$@"   to separate them correctly
PARSED=$(\
    getopt --options=$OPTIONS --longoptions=$LONGOPTIONS --name "$0" -- "$@"\
)
if [[ $? -ne 0 ]]; then
    # e.g. $? == 1
    #  then getopt has complained about wrong arguments to stdout
    usage
    exit 2
fi

# read getopt's output this way to handle the quoting right:
eval set -- "$PARSED"

## MODIFY >>> *****************************************************************
## Set any defaults for command line options
EXEC_METHOD=cdc-module
## ***************************************************************** <<< MODIFY

## MODIFY >>> *****************************************************************
## Handle each command line option. Lower-case variables, e.g., ${file}, only
## exist if they are set as environment variables before script execution.
## Environment variables are used by Agave. If the environment variable is not
## set, the Upper-case variable, e.g., ${FILE}, is assigned from the command
## line parameter.
while true; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -f|--file)
            if [ -z "${file}" ]; then
                FILE=$2
            else
                FILE=${file}
            fi
            shift 2
            ;;
        -o|--output)
            if [ -z "${output}" ]; then
                OUTPUT=$2
            else
                OUTPUT=${output}
            fi
            shift 2
            ;;
        -x|--exec_method)
            if [ -z "${exec_method}" ]; then
                EXEC_METHOD=$2
            else
                EXEC_METHOD=${exec_method}
            fi
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Invalid option"
            usage
            exit 3
            ;;
    esac
done
## ***************************************************************** <<< MODIFY

## MODIFY >>> *****************************************************************
## Log any variables passed as inputs
echo "File: ${FILE}"
echo "Output: ${OUTPUT}"
echo "Execution Method: ${EXEC_METHOD}"
## ***************************************************************** <<< MODIFY



###############################################################################
#### Validate and Set Variables ####
###############################################################################

## MODIFY >>> *****************************************************************
## Add app-specific logic for handling and parsing inputs and parameters
# FILE parameter
if [ -z "${FILE}" ]; then
    echo "Input file required"
    echo
    usage
    exit 1
fi
# make sure FILE is staged
count=0
while [ ! -f ${FILE} ]
do
    echo "${FILE} not staged, waiting..."
    sleep 1
    (( count++ ))
    if [ $count == 10 ]; then break; fi
done
if [ ! -f ${FILE} ]; then
    echo "Input not found: ${FILE}"
    exit 1
fi
# infer full path and basename of FILE
FILE_DIR=$(dirname $(readlink -f ${FILE}))
FILE_FILE=$(basename ${FILE})

# OUTPUT parameter
if [ -z "${OUTPUT}" ]; then
    echo "Output file required"
    echo
    usage
    exit 1
fi
## ***************************************************************** <<< MODIFY

## EXEC_METHOD: execution method
## Suggested possible options:
##   cdc-module: module(s) in the CDC environment
##   package: binaries packaged with the app
##   cdc-package: binaries centrally located at the CDC
##   singularity: singularity image packaged with the app
##   cdc-singularity: singularity image centrally located at the CDC
##   docker: docker containers from docker-hub
##   cdc-docker: docker containers from internal CDC registry

## MODIFY >>> *****************************************************************
## List supported execution methods for this app (space delimited)
exec_methods="cdc-module package"
## ***************************************************************** <<< MODIFY

# make sure the specified execution method is included in list
if [[ ! " ${exec_methods} " =~ .*\ ${EXEC_METHOD}\ .* ]]; then
    echo "Invalid execution method: ${EXEC_METHOD}"
    echo
    usage
    exit 1
fi

## SCRIPT_DIR: directory of current script, depends on execution
## environment, which may be detectable using environment variables
if [ -z "${AGAVE_JOB_ID}" ]; then
    # not an agave job
    SCRIPT_DIR=$(dirname $(readlink -f $0))
else
    echo "Agave job detected"
    SCRIPT_DIR=$(pwd)
fi
## ****************************************************************************



###############################################################################
#### App Execution Preparation ####
###############################################################################

## MODIFY >>> *****************************************************************
## Add logic to prepare environment for execution
## There should be one case statement for each item in $exec_methods
case "${EXEC_METHOD}" in
    cdc-module)
        # load modules environment and module(s)
        source /etc/profile.d/modules.sh
        module load app/1.0
        ;;
    package)
        # unzip package, if required by app
        tar\
            --directory=${SCRIPT_DIR}/app-template \
            -xzf ${SCRIPT_DIR}/app-template/app-template.tar.gz
        # make executable
        chmod +x ${SCRIPT_DIR}/app-template/bin/binary
        ;;
esac
## ***************************************************************** <<< MODIFY



###############################################################################
#### App Execution ####
###############################################################################

## MODIFY >>> *****************************************************************
## Add logic to execute app
## There should be one case statement for each item in $exec_methods
case "${EXEC_METHOD}" in
    cdc-module)
        # run app using loaded module(s)
        ;;
    package)
        # construct run command
        CMD="${SCRIPT_DIR}/app-template/bin/binary"
            CMD+=" ${INPUT_DIR}/${INPUT_FILE} > ${OUTPUT} 2> log.stderr"
        echo "CMD=${CMD}"
        safeRunCommand "${CMD}"
        ;;
esac
## ***************************************************************** <<< MODIFY



###############################################################################
#### Cleanup ####
###############################################################################

## MODIFY >>> *****************************************************************
## Add logic to cleanup execution artifacts, if necessary
## There should be one case statement for each item in $exec_methods
case "${EXEC_METHOD}" in
    cdc-module)
        ;;
    package)
        ;;
esac
## ***************************************************************** <<< MODIFY


