import os.path, glob, os, yaml, pymssql, traceback, argparse, shutil, requests, re
from datetime import datetime
from pathlib import Path
from sys import exit

# This script will make the required config and read.txt files needed by necat assembler.
# example usage:
# python /path/to/snakemake/bin/necat_generate_cfg.py --workdir /path/to/collection_name --samplecfg /path/to/collection_name/config/samplesheet.yaml

arg = argparse.ArgumentParser()

arg.add_argument(
    "--workdir",
    metavar="Name",
    help="Working directory where all data will be output to, the necat directory will be created inside this.",
    type=str,
    required=False,
)

arg.add_argument(
    "--samplecfg",
    metavar="Name",
    help="Path to samplesheet yaml file",
    type=str,
    required=True,
)

arg.add_argument(
    "--paramcfg",
    metavar="Name",
    help="Path to samplesheet yaml file",
    type=str,
    required=True,
)

flags = arg.parse_args()

if str(flags.workdir) == 'None':
    OUT = os.path.abspath('')
else:
    OUT = flags.workdir

snakeionary_sample_sheet = os.path.abspath(flags.samplecfg)
snakeionary_params = os.path.abspath(flags.paramcfg)

with open(snakeionary_sample_sheet) as file:
    yaml_list = yaml.load(file, Loader=yaml.FullLoader)

with open(snakeionary_params) as file:
    yaml_param_list = yaml.load(file, Loader=yaml.FullLoader)

if "subset_used" in yaml_list and "necat" not in yaml_list["subset_used"]:
    print(f"Necat was not selected as an assembler and will not generate the config files")
    exit()

# necat_cfg_list = [yaml_list["subset_used"]["necat"][subset] for subset in yaml_list["subset_used"]["necat"]]
# necat_cfg_list.append("original")
necat_cfg_list= ["assembly"]
samplelist = [sample for sample in yaml_list['samples']]
keep_percent = f"{yaml_param_list['keep_percent_str']}"

################################
## template necat config file ##
################################

for sample in samplelist:
    genome_size = f"{yaml_list['samples'][sample]['genome_size']}"
    species_full = f"{yaml_list['samples'][sample]['species_full']}"
    rivm_name = f"{yaml_list['samples'][sample]['publication_key']}"

    for necatper in necat_cfg_list:
        if necatper == 'assembly':
            necat_read_name = f"{OUT}/gz/filtlong/{sample}_min1000_best{keep_percent}.fastq.gz"
        else:
            necat_read_name = f"{OUT}/gz/trycycler_subsets/{sample}/{necatper}.fastq"
        directory_to_make = f"{OUT}/necat/{sample}/{necatper}"

        Path(f"{os.path.abspath(OUT)}/necat/{sample}/{necatper}").mkdir(parents=True, exist_ok=True)

        necat_individual_cfg_file = f"{OUT}/necat/{sample}/{necatper}/necat_cfg.txt"
        if os.path.isfile(necat_individual_cfg_file) == True:
            os.remove(necat_individual_cfg_file)
        necat_individual_cfg_file_open = open(necat_individual_cfg_file, 'a')

        necat_read_file = f"{OUT}/necat/{sample}/{necatper}/necat_read_file.txt"
        if os.path.isfile(necat_read_file) == True:
            os.remove(necat_read_file)

        necat_individual_cfg_file_open.write(f"PROJECT=assembly" + '\n'
        + f"ONT_READ_LIST={necat_read_file}" + '\n'
        + f"GENOME_SIZE={genome_size}" + '\n'
        + f"THREADS=16" + '\n'
        + f"MIN_READ_LENGTH=3000" + '\n'
        + f"PREP_OUTPUT_COVERAGE=40" + '\n'
        + f"OVLP_FAST_OPTIONS=-n 500 -z 20 -b 2000 -e 0.5 -j 0 -u 1 -a 1000" + '\n'
        + f"OVLP_SENSITIVE_OPTIONS=-n 500 -z 10 -e 0.5 -j 0 -u 1 -a 1000" + '\n'
        + f"CNS_FAST_OPTIONS=-a 2000 -x 4 -y 12 -l 1000 -e 0.5 -p 0.8 -u 0" + '\n'
        + f"CNS_SENSITIVE_OPTIONS=-a 2000 -x 4 -y 12 -l 1000 -e 0.5 -p 0.8 -u 0" + '\n'
        + f"TRIM_OVLP_OPTIONS=-n 100 -z 10 -b 2000 -e 0.5 -j 1 -u 1 -a 400" + '\n'
        + f"ASM_OVLP_OPTIONS=-n 100 -z 10 -b 2000 -e 0.5 -j 1 -u 0 -a 400" + '\n'
        + f"NUM_ITER=2" + '\n'
        + f"CNS_OUTPUT_COVERAGE=30" + '\n'
        + f"CLEANUP=1" + '\n'
        + f"USE_GRID=false" + '\n'
        + f"GRID_NODE=0" + '\n'
        + f"GRID_OPTIONS=" + '\n'
        + f"SMALL_MEMORY=0" + '\n'
        + f"FSA_OL_FILTER_OPTIONS=" + '\n'
        + f"FSA_ASSEMBLE_OPTIONS=" + '\n'
        + f"FSA_CTG_BRIDGE_OPTIONS=" + '\n'
        + f"POLISH_CONTIGS=true" + '\n'
        )
        necat_individual_cfg_file_open.close()

        necat_read_file_open = open(necat_read_file, "a")
        necat_read_file_open.write(f"{necat_read_name}"
            )
        necat_read_file_open.close()