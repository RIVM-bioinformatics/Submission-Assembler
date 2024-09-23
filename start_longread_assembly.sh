#!/bin/bash

set -x

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd )"
cd ${DIR}

version="Stripped assembler v1.0 (September 2024)"
dataecho=$(date +%y%m%d"_"%H"h"%M"m"%S"s")
snakedate=$(date +%Y"-"%m"-"%d)
CONDA_RC="$HOME/.condarc"
# The reason for all these empty commands is because in some run options not all flags have to be supplied. So I build the --flag option to parse to python bin/generate_longread_samplesheet.py
WORKDIR_CMD=""
BASECALLED_DIR_CMD=""
NANOPORE_CMD=""
DATAPATH_CMD=""
INPUT_CMD=""
OUTPUT_CMD=""
KEEP_PERCENT_CMD=""
MEDAKA_ROUNDS=""
MEDAKA_ROUNDS_CMD=""
ALLASS_CMD=""
MEDAKA_MODEL='r1041_e82_400bps_sup_v4.3.0'
# MEDAKA_MODELS='r1041_e82_400bps_sup_v4.3.0','r1041_e82_400bps_hac_g632','r1041_e82_260bps_hac_g632','r1041_e82_260bps_sup_g632','r1041_e82_400bps_sup_g615','r941_min_hac_g507'
MEDAKA_MODEL_CMD="--medaka_model ${MEDAKA_MODEL}"
MEDAKA="False"
MEDAKA_CMD=""
UNLOCK="False"
PATH_MASTER_YAML=$(echo "${DIR}/envs/master_snake.yaml") # The environment that contains snakemake and essential programs to run the sample sheet scripts
MASTER_NAME=$(head -n 1 ${PATH_MASTER_YAML} | cut -f2 -d ' ') # Get name from .yaml file
TESTRUN="False"

function usage(){
	printf "\n Script usage:\n"
    printf "# Prefered mode is to utilize iRODS, however for any users outside RIVM this will not work and so only the --longread flag can be used\n"
    printf "# This also means that default samplesheet behaviour does not work and thus average coverage will be based upon 5Mb genome size\n"
    printf "\n"
    printf " Example:\n"
    printf "# To run the pipeline outside iRODS/RIVM you can supply --longread; bash start_longread_assembly.sh --longread path/to/longreaddata/\n"
    printf "# In that case it will regard every fastq file in that directory as input for assembly.\n"
    printf "# When not supplying output in the longread example it will create a timestamped directory in your snakemake directory for output.\n"
    printf "\n"
	printf "\t-v, --version			: Print the version and exit\n"
	printf "\t-h, --help			: Print this message and exit\n"
	printf "\t-i, --input			: Exclusively option for the service account for iRODS, meaning path given will contain the longread data and is retrieved by iget (Can not be used outside RIVM)\n"
	printf "\t-o, --output			: Prefered output directory, will otherwise be in --alt_input for iRODS mode or current working directory + longread_assembly_date (optional)\n"
	printf "\t-ai, --alt_input		: Runs based on expected iRODS output, meaning directory must contain internal_gridion_demultiplexed/dorado_duplex_called. This means all files within that barcode directory are taken as input as opposed to longread flag (Can not be used outside RIVM)\n"
	printf "\t-l, --longread		        : Another input option, expects a directory with single file per isolate. Can be used when not using iRODS mode\n"
	printf "\t-n, --nanopore_dir		    : Can supply to overwrite basedir when using alt_input to use this collection name in iRODS (Can not be used outside RIVM)\n"
	printf "\t-k, --keep_percent	        : Keep percentage for filtering on quality with filtlong, default is 90, must be less than 100 (Optional)\n"
	printf "\t-m, --medaka			: Supply to run medaka, default 1 round of polishing (Optional)\n"
    printf "\t-mr, --medaka_rounds		: Number of medaka rounds for polishing in case of supplying medaka flag, default 1 (Optional)\n"
	printf "\t-aa, --all_assemblers	: Supply to run all 7 assemblers, otherwise will run only those specified in files/assembler_choice.csv with yes or no (Optional)\n"
	printf "\t-if, --isolates			: Optional for non iRODS mode only, .txt file with isolate keynames, will otherwise try to guess from the first underscore index on longread data name (Optional)\n"
	printf "\t-u, --unlock			: Unlock the Snakemake directory\n"
    printf "\t-ts, --testrun			: Command for test run. Will create samplesheet and environment then run following command and then exit: snakemake -np \n\n"
}

if [ $# == 0 ]
then
    printf "No parameters were given.\n"
	usage
	exit 1
fi

while [[ $# -gt 0 ]]
do
    case "$1" in
    -v|--version)
        printf "$version \n"
        exit 0
        ;;
    -h|--help)
        usage
        exit 0
        ;;
    -i|--input) 
        INPUT="$2";
        shift 1
        ;;  
    -o|--output) 
        OUTPUT="$2";
        shift 1
        ;; 
    -ai|--alt_input) 
        ALT_INPUT="$2";
        shift 1
        ;; 
    -l|--longread) 
        LONGREAD="$2";
        shift 1
        ;;
    -n|--nanopore_dir) 
        NANOPORE_DIR="$2";
        shift 1
        ;;
    -k|--keep_percent) 
        KEEP_PERCENT="$2";
        shift 1
        ;; 
    -m|--medaka) 
        MEDAKA="True";
        ;;  
    -mr|--medaka_rounds) 
        if [[ "$2" =~ ^[1-9][0-9]*$ ]]; then
            MEDAKA_ROUNDS="$2";
        shift 1
        else
            echo "Invalid number range format for -mr|--medaka_rounds: $2"
            exit 1
        fi
        ;; 
    -aa|--all_assemblers) 
        ALLASS_CMD="--all_assemblers";
        ;; 
    -if|--isolates) 
        ISOLATES="$2";
        ;;   
    -u|--unlock) 
        UNLOCK="$2";
        ;; 
    -ts|--testrun) 
        TESTRUN="True";
        ;;  
    --)
        shift
        break
        ;;
    *)
        echo "Unknown option: $1"
        exit 1
        ;;
    # --) shift; break;;
    esac
    shift
done

# Just a more easy way of unlocking Snakemake without having to activate the environment
if [ "${UNLOCK}" != "False" ]
then
    cd ${DIR}
    source activate "${MASTER_NAME}" # unlocking only makes sense once Snakemake env has been installed previously so no checks here.
    echo "Unlocking Snakemake directory and exiting."
    snakemake --unlock
    exit 1
fi

######################################################################
###                      (IN)SANITY CHECKS                         ###
######################################################################

# There are 3 ways of supplying input but only 1 can be used
if [ -n "${INPUT}" ] && [ -n "${ALT_INPUT}" ]
then
    printf "Unable to run --input alongside --alt_input, please provide only one\n"
    usage
    exit 1
fi

if [ -n "${INPUT}" ] && [ -n "${LONGREAD}" ]
then
    printf "Unable to run --input alongside --longread, please provide only one\n"
    usage
    exit 1
fi

if [ -n "${ALT_INPUT}" ] && [ -n "${LONGREAD}" ]
then
    printf "Unable to run --alt_input alongside --longread, please provide only one\n"
    usage
    exit 1
fi

# Different flags have to be used for the different input options which is done here.
if [ -n "${INPUT}" ]
then   
    export INPUT_DIR=${INPUT}
    export OUTPUT_DIR=${OUTPUT}
    BASECALLED_DIR="internal_gridion_demultiplexed"
    if find "$INPUT_DIR" -maxdepth 1 -type d -name "*barcode*" -print -quit | grep -q .
    then
        BASECALLED_DIR="${INPUT_DIR}_NOSUBDIR"
    else
        if [ ! -d "${INPUT_DIR}/${BASECALLED_DIR}" ]
        then
            BASECALLED_DIR="dorado_duplex_called"
        fi
    fi
    BASECALLED_DIR_CMD="--basecalled_dir ${BASECALLED_DIR}"
    export SNAKEBACKUP="False"
    INPUT_CMD="--input ${INPUT_DIR}"
    OUTPUT_CMD="--output ${OUTPUT_DIR}"
    NANOPORE_CMD="--nanoporedir $(basename ${var_input_collection}| cut -d_ -f1-5)" # Only works for iRODS in the RIVM uses the variable for input collection
elif [ -n "${ALT_INPUT}" ]
then
    export OUTPUT_DIR=$(realpath ${ALT_INPUT})
    OUTPUT_CMD="--output ${OUTPUT_DIR}"
    if [ -z "$NANOPORE_DIR" ]
    then
        export NANOPORE_DIR=$(basename "${OUTPUT_DIR}" | cut -d_ -f1-5) # For --input it will get this from iRODS instead; for --alt_input it is the basename dir 
        export NANOPORE_CMD=$(echo "--nanoporedir ${NANOPORE_DIR}")
    else
        export NANOPORE_DIR=$(echo "${NANOPORE_DIR}" | cut -d_ -f1-5) # For --input it will get this from iRODS instead; for --alt_input it is the basename dir 
        export NANOPORE_CMD=$(echo "--nanoporedir ${NANOPORE_DIR}")
    fi
    if [ ! -d "${OUTPUT_DIR}" ] || [ ! -d "${OUTPUT_DIR}/internal_gridion_demultiplexed/" ] && [ ! -d "${OUTPUT_DIR}/dorado_duplex_called/" ] 
    then
        printf "${OUTPUT_DIR}" 
        printf "Input directory or the expected demultiplexed directory does not exist\n"
        usage
        exit 1
    else
        BASECALLED_DIR="internal_gridion_demultiplexed"
        if [ ! -d "${OUTPUT_DIR}/${BASECALLED_DIR}" ]
        then
            BASECALLED_DIR="dorado_duplex_called"
        fi
        BASECALLED_DIR_CMD="--basecalled_dir ${BASECALLED_DIR}"
        printf "Running longread assembly in iRODS mode\n"
        export WORKDIR_CMD=$(echo "--workdir ${OUTPUT_DIR}")
    fi
elif [ -n "${LONGREAD}" ]
then
    REALREAD=$(realpath ${LONGREAD})
    export LONGREAD_DIR=$(echo "${REALREAD}")
    if [ -d "${LONGREAD_DIR}" ]
    then
        printf "Running longread assembly in non iRODS mode\n"
        export DATAPATH_CMD=$(echo "--longread ${LONGREAD_DIR}")
        if [ -n "${OUTPUT}" ]
        then
            echo "${OUTPUT}"
            export OUTPUT_DIR=${OUTPUT}
            OUTPUT_CMD="--output ${OUTPUT_DIR}"
        else
            echo 'No output supplied with --longread flag will use current path'
            OUTPUT_CMD="--output ${DIR}"
        fi
    else
        printf "Unable to run in non iRODS mode, longread directory ${LONGREAD_DIR} does not exist\n"
        usage
        exit 1
    fi
else
    printf "No input option was given, invalid command\n"
    usage
    exit 1
fi

# For iRODS service account mode I don't want to overwrite with --output flag.
if [ -n "${OUTPUT}" ] && [ ! -n "${INPUT}" ] 
then 
    export OUTPUT_DIR=$(realpath ${OUTPUT})
    export OUTPUT_CMD=$(echo "--output ${OUTPUT_DIR}")
    mkdir -p "${OUTPUT_DIR}"
    printf "using ${OUTPUT_DIR} as output directory\n"
elif [ ! -n "${ALT_INPUT}" ] && [ ! -n "${INPUT}" ]
then
    export OUTPUT_DIR="${DIR}"/assembly_"${dataecho}"
    export OUTPUT_CMD=$(echo "--output ${OUTPUT_DIR}")
    mkdir -p "${OUTPUT_DIR}" # there's no error catching for if unable to write here
    printf "using ${OUTPUT_DIR} as output directory\n"
else
    printf "using ${OUTPUT_DIR} as output directory\n" # This one is defined under --alt_input
fi

# Just some extra flags if present, otherwise these variables will be empty and bin/generate_longread_samplesheet.py will know not to use them.
if  [ -n "${KEEP_PERCENT}" ]
then
    export KEEP_PERCENT_CMD=$(echo "--keep_percent ${KEEP_PERCENT}")
fi

if  [ "${MEDAKA}" != "False" ]
then
    export MEDAKA_CMD=$(echo "--medaka")
fi

if  [ -n "${MEDAKA_ROUNDS}" ]
then
    export MEDAKA_CMD=$(echo "--medaka") # just set to true as well because why else would you supply rounds
    export MEDAKA_ROUNDS_CMD=$(echo "--medaka_rounds ${MEDAKA_ROUNDS}")
fi

######################################################################
###                        ENVIRONMENT TIME                        ###
######################################################################

if [ ! -f "${PATH_MASTER_YAML}" ] ;
    then
        echo "Warning! "${PATH_MASTER_YAML}" file was not found! Can not run pipeline." 
        printf "\n"
        echo "Exiting. "
        exit 1
fi

if [[ $PATH != *${MASTER_NAME}* ]] ; then # If echo $PATH does not contain the conda env name I will force install it.
    echo 'The environment '${MASTER_NAME}' is currently not in your PATH, will try to activate'; 
    source activate ${MASTER_NAME} # Might be double..
    if ! source activate ${MASTER_NAME} ; then # Only when it fails to activate this env it will force install.
        echo 'Could not find '${MASTER_NAME}' . Am now going to create a new environment with this name'
        mamba env update -f ${PATH_MASTER_YAML}
        source activate ${MASTER_NAME}
    fi
else # If it didn't fail it means I can activate it so am using that
    echo ${MASTER_NAME}' found, will now activate it.'; 
    source activate ${MASTER_NAME}
    # mamba env update -f ${PATH_MASTER_YAML} # This can be tricky because it can break your working environment when running this multiple times locally
fi

conda config --env --set channel_priority strict

######################################################################
###                        SAMPLESHEET TIME                        ###
######################################################################

echo "Generating the sample sheet with the following command:"
echo "python bin/generate_longread_samplesheet.py ${WORKDIR_CMD} ${NANOPORE_CMD} ${DATAPATH_CMD} ${KEEP_PERCENT_CMD} ${ALLASS_CMD} ${MEDAKA_CMD} ${MEDAKA_ROUNDS_CMD} ${INPUT_CMD} ${OUTPUT_CMD} ${MEDAKA_MODEL_CMD} ${BASECALLED_DIR_CMD}"
python bin/generate_longread_samplesheet.py ${WORKDIR_CMD} ${NANOPORE_CMD} ${DATAPATH_CMD} ${KEEP_PERCENT_CMD} ${ALLASS_CMD} ${MEDAKA_CMD} ${MEDAKA_ROUNDS_CMD} ${INPUT_CMD} ${OUTPUT_CMD} ${MEDAKA_MODEL_CMD} ${BASECALLED_DIR_CMD}

SAMPLESHEET="${OUTPUT_DIR}/config/longread_samplesheet.yaml"
PARAMETER_CONFIG="${OUTPUT_DIR}/config/longread_parameter_config.yaml"

# If samplesheet did not get created exit here.
if [ ! -f "${SAMPLESHEET}" ]
then
    echo "No samplesheet was found, unable to run script.."
    echo "Should've just been generated by bin/generate_longread_samplesheet.py..."
    exit 1
fi

# Generates the Necat config files based on the available samplesheet.
run_necat="$(grep -w 'necat' files/assembler_choice.csv | cut -d, -f 2)"
if [[ "$run_necat" == "y" ]] || [[ ! -z "${ALLASS_CMD}" ]]
then
    echo "Generating necat config files with the following command:"
    echo "python bin/necat_generate_cfg.py --workdir ${OUTPUT_DIR} --samplecfg ${SAMPLESHEET}"
    python bin/necat_generate_cfg.py --workdir "${OUTPUT_DIR}" --samplecfg "${SAMPLESHEET}" --paramcfg "${PARAMETER_CONFIG}"
fi

######################################################################
###                        SNAKEMAKE TIME                          ###
######################################################################

# Dry run or possibility to create a dag
if [ ${TESTRUN} == "True" ]
then
    echo "running a snakemake dry run then exiting."
    # snakemake --dag | dot -Tsvg > dag.svg
    snakemake -np --cores all #--omit-from somerule
    exit 1
fi

snakemake --configfiles "${SAMPLESHEET}" \
--profile "${DIR}"/config \
--restart-times 4 \
--attempt 1 \
--rerun-triggers mtime

cp .snakemake/log/"${snakedate}"*.log "${OUTPUT_DIR}"/log/
