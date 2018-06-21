#!/bin/bash

# BWA Mem app wrapper script



###############################################################################
#### Helper Functions ####
###############################################################################

## MODIFY >>> *****************************************************************
## Usage description should match command line arguments defined below
usage () {
    echo "Usage: $(basename $0) [-h] -i input [-p pair] -r reference -o output"
    echo "      [-x exec_method]"
    echo "  -i,--input        Input sequence file"
    echo "  -p,--pair         Paired-end sequence file"
    echo "  -r,--reference    BWA reference index"
    echo "  -o,--output       Output SAM file"
    echo "  -x,--exec_method  Execution method (package, cdc-shared-package,"
    echo "                      singularity, cdc-shared-singularity, docker,"
    echo "                      environment)"
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
OPTIONS=hi:p:r:o:x:
LONGOPTIONS=help,input:,pair:,reference:,output:,exec_method:
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
EXEC_METHOD=package
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
        -i|--input)
            if [ -z "${input}" ]; then
                INPUT=$2
            else
                INPUT=${input}
            fi
            shift 2
            ;;
        -p|--pair)
            if [ -z "${pair}" ]; then
                PAIR=$2
            else
                PAIR=${pair}
            fi
            shift 2
            ;;
        -r|--reference)
            if [ -z "${reference}" ]; then
                REFERENCE=$2
            else
                REFERENCE=${reference}
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
echo "Input: ${INPUT}"
echo "Pair: ${PAIR}"
echo "Reference: ${REFERENCE}"
echo "Output: ${OUTPUT}"
echo "Execution Method: ${EXEC_METHOD}"
## ***************************************************************** <<< MODIFY



###############################################################################
#### Validate and Set Variables ####
###############################################################################

## MODIFY >>> *****************************************************************
## Add app-specific logic for handling and parsing inputs and parameters
# INPUT parameter
if [ -z "${INPUT}" ]; then
    echo "input sequence file required"
    echo
    usage
    exit 1
fi
# make sure INPUT is staged
count=0
while [ ! -f ${INPUT} ]
do
    echo "${INPUT} not staged, waiting..."
    sleep 1
    (( count++ ))
    if [ $count == 10 ]; then break; fi
done
if [ ! -f ${INPUT} ]; then
    echo "Input not found: ${INPUT}"
    exit 1
fi
INPUT_DIR=$(dirname $(readlink -f ${INPUT}))
INPUT_FILE=$(basename ${INPUT})

# PAIR parameter
if [ -n "${PAIR}" ]; then
    # make sure PAIR is staged
    count=0
    while [ ! -f ${PAIR} ]
    do
        echo "${PAIR} not staged, waiting..."
        sleep 1
        (( count++ ))
        if [ $count == 10 ]; then break; fi
    done
    if [ ! -f ${PAIR} ]; then
        echo "Pair not found: ${PAIR}"
        exit 1
    fi
    PAIR_DIR=$(dirname $(readlink -f ${PAIR}))
    PAIR_FILE=$(basename ${PAIR})
fi

# REFERENCE parameter
if [ -z "${REFERENCE}" ]; then
    echo "BWA reference index required"
    echo
    usage
    exit 1
fi
# make sure REFERENCE is staged
count=0
while [ ! -d ${REFERENCE} ]
do
    echo "${REFERENCE} not staged, waiting..."
    sleep 1
    (( count++ ))
    if [ $count == 10 ]; then break; fi
done
if [ ! -d ${REFERENCE} ]; then
    echo "Reference not found: ${REFERENCE}"
    exit 1
fi
# infer full path of REFERENCE
REFERENCE_DIR=$(readlink -f ${REFERENCE})
# reference directory should contain a *.bwt file
BWT_FILE=$(ls ${REFERENCE_DIR} | grep '.bwt$')
if [ -z "${BWT_FILE}" ]; then
    # bwt file not found, not a valid BWA reference index
    echo "Invalid BWA reference index"
    echo
    usage
    exit 1
fi
# get base of bwt file
BWT_PREFIX="${BWT_FILE%.*}"

# OUTPUT parameter
if [ -z "${OUTPUT}" ]; then
    echo "Output SAM file required"
    echo
    usage
    exit 1
fi
OUTPUT_DIR=$(dirname $(readlink -f ${OUTPUT}))
OUTPUT_FILE=$(basename ${OUTPUT})
## ***************************************************************** <<< MODIFY

## EXEC_METHOD: execution method
## Suggested possible options:
##   package: binaries packaged with the app
##   cdc-shared-package: binaries centrally located at the CDC
##   singularity: singularity image packaged with the app
##   cdc-shared-singularity: singularity image centrally located at the CDC
##   docker: docker containers from docker-hub
##   environment: binaries available in environment path

## MODIFY >>> *****************************************************************
## List supported execution methods for this app (space delimited)
exec_methods="package cdc-shared-package singularity cdc-shared-singularity"
    exec_methods+=" docker environment"
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
    package)
        # unzip package, if required by app
        tar --directory=${SCRIPT_DIR}/bwa -xzf ${SCRIPT_DIR}/bwa/bwa.tar.gz
        # make executable
        chmod +x ${SCRIPT_DIR}/bwa/bin/bwa
        ;;
    cdc-shared-package)
        ;;
    singularity)
        ;;
    cdc-shared-singularity)
        ;;
    docker)
        ;;
    environment)
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
    package)
        CMD="${SCRIPT_DIR}/bwa/bin/bwa mem"
            CMD+=" ${REFERENCE_DIR}/${BWT_PREFIX}"
            CMD+=" ${INPUT_DIR}/${INPUT_FILE}"
            if [ -n "${PAIR_DIR}" ]; then
                CMD+=" ${PAIR_DIR}/${PAIR_FILE}"
            fi
            CMD+=" > ${OUTPUT_DIR}/${OUTPUT_FILE} 2> log.stderr"
        ;;
    cdc-shared-package)
        CMD="/apps/standalone/package/bwa-0.7.17/bin/bwa mem"
            CMD+=" ${REFERENCE_DIR}/${BWT_PREFIX}"
            CMD+=" ${INPUT_DIR}/${INPUT_FILE}"
            if [ -n "${PAIR_DIR}" ]; then
                CMD+=" ${PAIR_DIR}/${PAIR_FILE}"
            fi
            CMD+=" > ${OUTPUT_DIR}/${OUTPUT_FILE} 2> log.stderr"
        ;;
    singularity)
        CMD="singularity run ${SCRIPT_DIR}/bwa-0.7.17-biocontainers.simg"
            CMD+=" bwa mem"
            CMD+=" ${REFERENCE_DIR}/${BWT_PREFIX}"
            CMD+=" ${INPUT_DIR}/${INPUT_FILE}"
            if [ -n "${PAIR_DIR}" ]; then
                CMD+=" ${PAIR_DIR}/${PAIR_FILE}"
            fi
            CMD+=" > ${OUTPUT_DIR}/${OUTPUT_FILE} 2> log.stderr"
        ;;
    cdc-shared-singularity)
        CMD="singularity run"
            CMD+=" /apps/standalone/singularity/bwa/bwa-0.7.17-biocontainers.simg"
            CMD+=" bwa mem"
            CMD+=" ${REFERENCE_DIR}/${BWT_PREFIX}"
            CMD+=" ${INPUT_DIR}/${INPUT_FILE}"
            if [ -n "${PAIR_DIR}" ]; then
                CMD+=" ${PAIR_DIR}/${PAIR_FILE}"
            fi
            CMD+=" > ${OUTPUT_DIR}/${OUTPUT_FILE} 2> log.stderr"
        ;;
    docker)
        CMD="docker run --rm"
            CMD+=" -v ${INPUT_DIR}:/data1"
            if [ -n "${PAIR_DIR}" ]; then
                CMD+=" -v ${PAIR_DIR}:/data2"
            fi
            CMD+=" -v ${REFERENCE_DIR}:/reference"
            CMD+=" quay.io/biocontainers/bwa:0.7.17--pl5.22.0_2"
            CMD+=" bwa mem"
            CMD+=" /reference/${BWT_PREFIX}"
            CMD+=" /data1/${INPUT_FILE}"
            if [ -n "${PAIR_DIR}" ]; then
                CMD+=" /data2/${PAIR_FILE}"
            fi
            CMD+=" > ${OUTPUT_DIR}/${OUTPUT_FILE} 2> log.stderr"
        ;;
    environment)
        CMD="bwa mem"
            CMD+=" ${REFERENCE_DIR}/${BWT_PREFIX}"
            CMD+=" ${INPUT_DIR}/${INPUT_FILE}"
            if [ -n "${PAIR_DIR}" ]; then
                CMD+=" ${PAIR_DIR}/${PAIR_FILE}"
            fi
            CMD+=" > ${OUTPUT_DIR}/${OUTPUT_FILE} 2> log.stderr"
        ;;
esac
echo "CMD=${CMD}"
safeRunCommand "${CMD}"
## ***************************************************************** <<< MODIFY



###############################################################################
#### Cleanup ####
###############################################################################

## MODIFY >>> *****************************************************************
## Add logic to cleanup execution artifacts, if necessary
## There should be one case statement for each item in $exec_methods
case "${EXEC_METHOD}" in
    package)
        ;;
    cdc-shared-package)
        ;;
    singularity)
        ;;
    cdc-shared-singularity)
        ;;
    docker)
        ;;
    environment)
        ;;
esac
## ***************************************************************** <<< MODIFY


