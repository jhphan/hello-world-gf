#!/bin/bash

# template for GeneFlow app wrapper script


#### Helper Functions ####

## *** Modify usage function with app-specific options

usage () {
    echo "Usage: $(basename $0) [-h] -f file -o output [-x execenv]"
    echo "  -f,--file       Input file"
    echo "  -o,--output     Output file"
    echo "  -x,--execenv    Execution environment (package, docker, singularity)"
    echo "  -h,--help       Display this help message"
}

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



#### Parse Command-Line Arguments ####

## *** Modify command line options to match app definition

getopt --test > /dev/null
if [[ $? -ne 4 ]]; then
    echo "`getopt --test` failed in this environment."
    exit 1
fi

OPTIONS=hf:o:x:
LONGOPTIONS=help,file:,output:,execenv:

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

# now process options in order until we see --
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
        -x|--execenv)
            if [ -z "${execenv}" ]; then
                EXECENV=$2
            else
                EXECENV=${execenv}
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



#### Log Any Variables Passed as Inputs ####

echo "File: ${FILE}"
echo "Output: ${OUTPUT}"



#### Check and Set Required Vars ####

## *** Add app-specific logic for handling 
## *** and parsing inputs and parameters

## FILE
if [ -z "${FILE}" ]; then
    echo "input file required"
    echo
    usage
    exit 1
fi

# make sure input file is staged
count=0
while [ ! -f ${FILE} ]
do
    echo "${FILE} not staged, waiting..."
    sleep 1
    (( count++ ))
    if [ $count == 30 ]; then break; fi
done
if [ ! -f ${FILE} ]; then
    echo "Input not found: ${FILE}"
    exit 1
fi

FILE_DIR=$(dirname $(readlink -f ${FILE}))
FILE_FILE=$(basename ${FILE})

## OUTPUT
if [ -z "${OUTPUT}" ]; then
    echo "Output file required"
    echo
    usage
    exit 1
fi

## EXECENV
if [ -z "${EXECENV}" ]; then
    # default execution environment is package
    EXECENV=package # other options=docker,singularity
fi


#### Construct App Command ####

## *** Add app-specific logic for execution of the app binaries

if [ -z "${AGAVE_JOB_ID}" ]; then
    # not an agave job
    SCRIPT_DIR=$(dirname $(readlink -f $0))
else
    echo "Agave Job Detected"
    SCRIPT_DIR=$(pwd)
fi

case "${EXECENV}" in
    package)
        # unzip package, if required by app app
        tar --directory=${SCRIPT_DIR}/app-template -xzf ${SCRIPT_DIR}/app-template/app-template.tar.gz
        # make executable
        chmod +x ${SCRIPT_DIR}/app-template/bin/binary

        # construct command without pair
        CMD="${SCRIPT_DIR}/app-template/bin/binary ${INPUT_DIR}/${INPUT_FILE} > ${OUTPUT}"
        if [ -z "${AGAVE_JOB_ID}" ]; then
            # not agave, suppress stderr
            CMD="${CMD} 2> /dev/null"
        fi
        ;;
    docker)
        # construct docker command
        CMD="docker run"
        ;;
    singularity)
        # construct singularity command
        CMD="singularity-cmd"
        ;;
esac


#### Run Command ####

echo "CMD=${CMD}"
safeRunCommand "${CMD}"


