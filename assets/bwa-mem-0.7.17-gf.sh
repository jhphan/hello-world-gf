#!/bin/sh

# BWA Mem wrapper script


###############################################################################
#### Helper Functions ####
###############################################################################

## MODIFY >>> *****************************************************************
## Usage description should match command line arguments defined below
usage () {
    echo "Usage: $(basename "$0")"
    echo "  --input => Sequence FASTQ File"
    echo "  --pair => Paired-End Sequence FASTQ File"
    echo "  --reference => Reference Index"
    echo "  --threads => CPU Threads"
    echo "  --output => Output SAM File"
    echo "  --exec_method => Execution method (singularity, cdc-shared-singularity, docker, environment, auto)"
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
LONGOPTIONS=help,exec_method:,input:,pair:,reference:,threads:,output:,
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
THREADS=2    
EXEC_METHOD=auto
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
        --input)
            if [ -z "${input}" ]; then
                INPUT=$2
            else
                INPUT=${input}
            fi
            shift 2
            ;;
        --pair)
            if [ -z "${pair}" ]; then
                PAIR=$2
            else
                PAIR=${pair}
            fi
            shift 2
            ;;
        --reference)
            if [ -z "${reference}" ]; then
                REFERENCE=$2
            else
                REFERENCE=${reference}
            fi
            shift 2
            ;;
        --threads)
            if [ -z "${threads}" ]; then
                THREADS=$2
            else
                THREADS=${threads}
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
echo "Input: ${INPUT}"
echo "Pair: ${PAIR}"
echo "Reference: ${REFERENCE}"
echo "Threads: ${THREADS}"
echo "Output: ${OUTPUT}"
echo "Execution Method: ${EXEC_METHOD}"
## ***************************************************************** <<< MODIFY



###############################################################################
#### Validate and Set Variables ####
###############################################################################

## MODIFY >>> *****************************************************************
## Add app-specific logic for handling and parsing inputs and parameters

# INPUT input

if [ -z "${INPUT}" ]; then
    echo "Sequence FASTQ File required"
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
    count=$((count+1))
    if [ $count == 10 ]; then break; fi
done
if [ ! -f ${INPUT} ]; then
    echo "Sequence FASTQ File not found: ${INPUT}"
    exit 1
fi
INPUT_FULL=$(readlink -f "${INPUT}")
INPUT_DIR=$(dirname "${INPUT_FULL}")
INPUT_BASE=$(basename "${INPUT_FULL}")


# PAIR input

if [ -n "${PAIR}" ]; then
    # make sure ${PAIR} is staged
    count=0
    while [ ! -f ${PAIR} ]
    do
        echo "${PAIR} not staged, waiting..."
        sleep 1
        count=$((count+1))
        if [ $count == 10 ]; then break; fi
    done
    if [ ! -f ${PAIR} ]; then
        echo "Paired-End Sequence FASTQ File not found: ${PAIR}"
        exit 1
    fi
    PAIR_FULL=$(readlink -f "${PAIR}")
    PAIR_DIR=$(dirname "${PAIR_FULL}")
    PAIR_BASE=$(basename "${PAIR_FULL}")
fi



# REFERENCE input

if [ -z "${REFERENCE}" ]; then
    echo "Reference Index required"
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
    count=$((count+1))
    if [ $count == 10 ]; then break; fi
done
if [ ! -d ${REFERENCE} ]; then
    echo "Reference Index not found: ${REFERENCE}"
    exit 1
fi
REFERENCE_FULL=$(readlink -f "${REFERENCE}")
REFERENCE_DIR=$(dirname "${REFERENCE_FULL}")
REFERENCE_BASE=$(basename "${REFERENCE_FULL}")
MNT=""; ARG=""; CMD0="BWT_FILE=$(ls ${REFERENCE_FULL} | grep '.bwt$') ${ARG}"; CMD="${CMD0}"; echo "CMD=${CMD}"; safeRunCommand "${CMD}"; 
if [ -z "${BWT_FILE}" ]; then MNT=""; ARG=""; CMD0="fail 'Invalid BWA reference index' ${ARG}"; CMD="${CMD0}"; echo "CMD=${CMD}"; safeRunCommand "${CMD}"; fi; 
MNT=""; ARG=""; CMD0="BWT_PREFIX=\"${BWT_FILE%.*}\" ${ARG}"; CMD="${CMD0}"; echo "CMD=${CMD}"; safeRunCommand "${CMD}"; 



# THREADS parameter
if [ -n "${THREADS}" ]; then
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
else
    :
    echo "Output SAM File required"
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
exec_methods="singularity cdc-shared-singularity docker environment auto"
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
    if { [ "${SINGULARITY}" = "yes" ] && [ -f "${SCRIPT_DIR}/bwa-0.7.17-biocontainers.simg" ]; }; then
        AUTO_EXEC=singularity
    elif { [ "${SINGULARITY}" = "yes" ] && [ -f "/apps/standalone/singularity/bwa/bwa-0.7.17-biocontainers.simg" ]; }; then
        AUTO_EXEC=cdc-shared-singularity
    elif [ "${DOCKER}" = "yes" ]; then
        AUTO_EXEC=docker
    elif command -v bwa >/dev/null 2>&1; then
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
    singularity)
        MNT=""; ARG=""; ARG="${ARG} -t"; ARG="${ARG} \"${THREADS}\""; MNT="${MNT} -B "; MNT="${MNT}\"${REFERENCE_DIR}:/data2\""; ARG="${ARG} \"/data2/${REFERENCE_BASE}/${BWT_PREFIX}\""; MNT="${MNT} -B "; MNT="${MNT}\"${INPUT_DIR}:/data3\""; ARG="${ARG} \"/data3/${INPUT_BASE}\""; if [ -n "${PAIR}" ]; then MNT="${MNT} -B "; MNT="${MNT}\"${PAIR_DIR}:/data4\""; ARG="${ARG} \"/data4/${PAIR_BASE}\""; fi; CMD0="singularity run ${MNT} ${SCRIPT_DIR}/bwa-0.7.17-biocontainers.simg bwa mem ${ARG}"; CMD0="${CMD0} >\"${OUTPUT_DIR}/${OUTPUT_BASE}\""; CMD0="${CMD0} 2>\"log.stderr\""; CMD="${CMD0}"; echo "CMD=${CMD}"; safeRunCommand "${CMD}"; 
        ;;
    cdc-shared-singularity)
        MNT=""; ARG=""; ARG="${ARG} -t"; ARG="${ARG} \"${THREADS}\""; MNT="${MNT} -B "; MNT="${MNT}\"${REFERENCE_DIR}:/data2\""; ARG="${ARG} \"/data2/${REFERENCE_BASE}/${BWT_PREFIX}\""; MNT="${MNT} -B "; MNT="${MNT}\"${INPUT_DIR}:/data3\""; ARG="${ARG} \"/data3/${INPUT_BASE}\""; if [ -n "${PAIR}" ]; then MNT="${MNT} -B "; MNT="${MNT}\"${PAIR_DIR}:/data4\""; ARG="${ARG} \"/data4/${PAIR_BASE}\""; fi; CMD0="singularity run ${MNT} /apps/standalone/singularity/bwa/bwa-0.7.17-biocontainers.simg bwa mem ${ARG}"; CMD0="${CMD0} >\"${OUTPUT_DIR}/${OUTPUT_BASE}\""; CMD0="${CMD0} 2>\"log.stderr\""; CMD="${CMD0}"; echo "CMD=${CMD}"; safeRunCommand "${CMD}"; 
        ;;
    docker)
        MNT=""; ARG=""; ARG="${ARG} -t"; ARG="${ARG} \"${THREADS}\""; MNT="${MNT} -v "; MNT="${MNT}\"${REFERENCE_DIR}:/data2\""; ARG="${ARG} \"/data2/${REFERENCE_BASE}/${BWT_PREFIX}\""; MNT="${MNT} -v "; MNT="${MNT}\"${INPUT_DIR}:/data3\""; ARG="${ARG} \"/data3/${INPUT_BASE}\""; if [ -n "${PAIR}" ]; then MNT="${MNT} -v "; MNT="${MNT}\"${PAIR_DIR}:/data4\""; ARG="${ARG} \"/data4/${PAIR_BASE}\""; fi; CMD0="docker run --rm ${MNT} quay.io/biocontainers/bwa:0.7.17--pl5.22.0_2 bwa mem ${ARG}"; CMD0="${CMD0} >\"${OUTPUT_DIR}/${OUTPUT_BASE}\""; CMD0="${CMD0} 2>\"log.stderr\""; CMD="${CMD0}"; echo "CMD=${CMD}"; safeRunCommand "${CMD}"; 
        ;;
    environment)
        MNT=""; ARG=""; ARG="${ARG} -t"; ARG="${ARG} \"${THREADS}\""; ARG="${ARG} \"${REFERENCE_FULL}/${BWT_PREFIX}\""; ARG="${ARG} \"${INPUT_FULL}\""; if [ -n "${PAIR}" ]; then ARG="${ARG} \"${PAIR_FULL}\""; fi; CMD0="bwa mem ${ARG}"; CMD0="${CMD0} >\"${OUTPUT_DIR}/${OUTPUT_BASE}\""; CMD0="${CMD0} 2>\"log.stderr\""; CMD="${CMD0}"; echo "CMD=${CMD}"; safeRunCommand "${CMD}"; 
        ;;
esac
## ***************************************************************** <<< MODIFY



###############################################################################
#### Cleanup, Common to All Exec Methods ####
###############################################################################

## MODIFY >>> *****************************************************************
## Add logic to cleanup execution artifacts, if necessary
## ***************************************************************** <<< MODIFY

