#!/bin/sh

# Updated hello world GeneFlow app demonstrating conditional execution wrapper script


###############################################################################
#### Helper Functions ####
###############################################################################

## MODIFY >>> *****************************************************************
## Usage description should match command line arguments defined below
usage () {
    echo "Usage: $(basename "$0")"
    echo "  --file => Input Text File"
    echo "  --mode => Mode"
    echo "  --output => Output Text File"
    echo "  --exec_method => Execution method (environment, auto)"
    echo "  --help => Display this help message"
}
## ***************************************************************** <<< MODIFY

# report error code for command
safeRunCommand() {
    cmd="$@"
    eval "$cmd"
    ERROR_CODE=$?
    if [ ${ERROR_CODE} -ne 0 ]; then
        echo "Error when executing command '${cmd}'"
        exit ${ERROR_CODE}
    fi
}

# print message and exit
fail() {
    msg="$@"
    echo "${msg}"
    usage
    exit 1
}

# always report exit code
reportExit() {
    rv=$?
    echo "Exit code: ${rv}"
    exit $rv
}

trap "reportExit" EXIT

# check if string contains another string
contains() {
    string="$1"
    substring="$2"

    if test "${string#*$substring}" != "$string"; then
        return 0    # $substring is not in $string
    else
        return 1    # $substring is in $string
    fi
}



###############################################################################
## SCRIPT_DIR: directory of current script, depends on execution
## environment, which may be detectable using environment variables
###############################################################################
if [ -z "${AGAVE_JOB_ID}" ]; then
    # not an agave job
    SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
else
    echo "Agave job detected"
    SCRIPT_DIR=$(pwd)
fi
## ****************************************************************************



###############################################################################
#### Parse Command-Line Arguments ####
###############################################################################

getopt --test > /dev/null
if [ $? -ne 4 ]; then
    echo "`getopt --test` failed in this environment."
    exit 1
fi

## MODIFY >>> *****************************************************************
## Command line options should match usage description
OPTIONS=
LONGOPTIONS=help,exec_method:,file:,mode:,output:,
## ***************************************************************** <<< MODIFY

# -temporarily store output to be able to check for errors
# -e.g. use "--options" parameter by name to activate quoting/enhanced mode
# -pass arguments only via   -- "$@"   to separate them correctly
PARSED=$(\
    getopt --options=$OPTIONS --longoptions=$LONGOPTIONS --name "$0" -- "$@"\
)
if [ $? -ne 0 ]; then
    # e.g. $? == 1
    #  then getopt has complained about wrong arguments to stdout
    usage
    exit 2
fi

# read getopt's output this way to handle the quoting right:
eval set -- "$PARSED"

## MODIFY >>> *****************************************************************
## Set any defaults for command line options
MODE="basic"
EXEC_METHOD="auto"
## ***************************************************************** <<< MODIFY

## MODIFY >>> *****************************************************************
## Handle each command line option. Lower-case variables, e.g., ${file}, only
## exist if they are set as environment variables before script execution.
## Environment variables are used by Agave. If the environment variable is not
## set, the Upper-case variable, e.g., ${FILE}, is assigned from the command
## line parameter.
while true; do
    case "$1" in
        --help)
            usage
            exit 0
            ;;
        --file)
            if [ -z "${file}" ]; then
                FILE=$2
            else
                FILE=${file}
            fi
            shift 2
            ;;
        --mode)
            if [ -z "${mode}" ]; then
                MODE=$2
            else
                MODE=${mode}
            fi
            shift 2
            ;;
        --output)
            if [ -z "${output}" ]; then
                OUTPUT=$2
            else
                OUTPUT=${output}
            fi
            shift 2
            ;;
        --exec_method)
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
echo "Mode: ${MODE}"
echo "Output: ${OUTPUT}"
echo "Execution Method: ${EXEC_METHOD}"
## ***************************************************************** <<< MODIFY



###############################################################################
#### Validate and Set Variables ####
###############################################################################

## MODIFY >>> *****************************************************************
## Add app-specific logic for handling and parsing inputs and parameters

# FILE input

if [ -z "${FILE}" ]; then
    echo "Input Text File required"
    echo
    usage
    exit 1
fi
# make sure FILE is staged
count=0
while [ ! -f "${FILE}" ]
do
    echo "${FILE} not staged, waiting..."
    sleep 1
    count=$((count+1))
    if [ $count == 10 ]; then break; fi
done
if [ ! -f "${FILE}" ]; then
    echo "Input Text File not found: ${FILE}"
    exit 1
fi
FILE_FULL=$(readlink -f "${FILE}")
FILE_DIR=$(dirname "${FILE_FULL}")
FILE_BASE=$(basename "${FILE_FULL}")



# MODE parameter
if [ -n "${MODE}" ]; then
    :
else
    :
fi


# OUTPUT parameter
if [ -n "${OUTPUT}" ]; then
    :
    OUTPUT_FULL=$(readlink -f "${OUTPUT}")
    OUTPUT_DIR=$(dirname "${OUTPUT_FULL}")
    OUTPUT_BASE=$(basename "${OUTPUT_FULL}")
    LOG_FULL="${OUTPUT_DIR}/_log"
    TMP_FULL="${OUTPUT_DIR}/_tmp"
else
    :
    echo "Output Text File required"
    echo
    usage
    exit 1
fi


## ***************************************************************** <<< MODIFY

## EXEC_METHOD: execution method
## Suggested possible options:
##   auto: automatically determine execution method
##   package: binaries packaged with the app
##   cdc-shared-package: binaries centrally located at the CDC
##   singularity: singularity image packaged with the app
##   cdc-shared-singularity: singularity image centrally located at the CDC
##   docker: docker containers from docker-hub
##   environment: binaries available in environment path
##   module: environment modules

## MODIFY >>> *****************************************************************
## List supported execution methods for this app (space delimited)
exec_methods="environment auto"
## ***************************************************************** <<< MODIFY

# make sure the specified execution method is included in list
if ! contains " ${exec_methods} " " ${EXEC_METHOD} "; then
    echo "Invalid execution method: ${EXEC_METHOD}"
    echo
    usage
    exit 1
fi



###############################################################################
#### Auto-Detect Execution Method ####
###############################################################################

# assign to new variable in order to auto-detect after Agave
# substitution of EXEC_METHOD
AUTO_EXEC=${EXEC_METHOD}
## MODIFY >>> *****************************************************************
## Add app-specific paths to detect the execution method.
if [ "${EXEC_METHOD}" = "auto" ]; then
    # detect if singularity available
    if command -v singularity >/dev/null 2>&1; then
        SINGULARITY=yes
    else
        SINGULARITY=no
    fi

    # detect if docker available
    if command -v docker >/dev/null 2>&1; then
        DOCKER=yes
    else
        DOCKER=no
    fi

    # detect execution method
    if command -v cat >/dev/null 2>&1 && command -v wc >/dev/null 2>&1 && command -v echo >/dev/null 2>&1; then
        AUTO_EXEC=environment
    else
        echo "Valid execution method not detected"
        echo
        usage
        exit 1
    fi
    echo "Detected Execution Method: ${AUTO_EXEC}"
fi
## ****************************************************************************



###############################################################################
#### App Execution Preparation, Common to all Exec Methods ####
###############################################################################

## MODIFY >>> *****************************************************************
## Add logic to prepare environment for execution
## ***************************************************************** <<< MODIFY



###############################################################################
#### App Execution, Specific to each Exec Method ####
###############################################################################

## MODIFY >>> *****************************************************************
## Add logic to execute app
## There should be one case statement for each item in $exec_methods
case "${AUTO_EXEC}" in
    environment)
        if [ "${MODE}" = "basic" ]; then MNT=""; ARG=""; CMD0="echo 'Hello World!' ${ARG}"; CMD0="${CMD0} >\"${OUTPUT_FULL}\""; CMD="${CMD0}"; echo "CMD=${CMD}"; safeRunCommand "${CMD}"; else CMD=""; MNT=""; ARG=""; CMD1="cat ${FILE_FULL} ${ARG}"; CMD="${CMD}${CMD1}"; MNT=""; ARG=""; CMD2="wc -w ${ARG}"; CMD2="${CMD2} >\"${OUTPUT_FULL}\""; CMD="${CMD}|${CMD2}"; echo "CMD=${CMD}"; safeRunCommand "${CMD}"; fi; 
        ;;
esac
## ***************************************************************** <<< MODIFY



###############################################################################
#### Cleanup, Common to All Exec Methods ####
###############################################################################

## MODIFY >>> *****************************************************************
## Add logic to cleanup execution artifacts, if necessary
## ***************************************************************** <<< MODIFY

