import os.path, glob, os, json, yaml, pymssql, traceback, argparse, shutil, requests, re, csv, textwrap, subprocess
from termcolor import colored
from datetime import datetime
from pathlib import Path
from sys import exit

def getmylogo(pth):
    exec_globals = {}
    with open(pth, 'r') as lfile:
        exec(lfile.read(), exec_globals)
    logo = exec_globals.get('logo', None)
    return logo

def parse_arguments(logo):
    arg = argparse.ArgumentParser(formatter_class=argparse.RawDescriptionHelpFormatter,
    description=textwrap.dedent(f"""
        {colored(logo, 'magenta', attrs=["bold"])}
        {colored('Assembler for Nanopore data:', 'white', attrs=["bold", "underline"])}

        Generates samplesheet for assembler.
-----------------------------------------------------------------------------------
        {colored('Example usage:', 'green', attrs=["bold", "underline"])}
            python {os.path.abspath(__file__)} 
            --workdir something
-----------------------------------------------------------------------------------
        """))
    arg.add_argument(
        "--workdir",
        metavar="Path",
        help="Runs iRODS mode, Working directory in which to output all generated files - Should not be your Snakemake dir",
        type=str,
        required=False,
    )
    arg.add_argument(
        "--nanoporedir",
        metavar="Name",
        help="Basename of the Nanopore sequencing run, without the final '_ 4 digits'",
        type=str,
        default='NO_DIR',
        required=False,
    )
    arg.add_argument(
        "--basecalled_dir",
        metavar="Name",
        help="Basename of the basecalled directory",
        type=str,
        default='',
        required=False,
    )
    arg.add_argument(
        "--input",
        metavar="Path",
        help="Only useable when running through iRODS service account, this contains the internal_gridion_demultiplexed directory as well",
        type=str,
        required=False,
    )
    arg.add_argument(
        "--output",
        metavar="Path",
        help="Optional output directory for (non)iRODS mode in which to output all generated files",
        type=str,
        required=False,
    )
    arg.add_argument(
        "--longread",
        metavar="Path",
        help="Runs non iRODS mode, must contain your longread data",
        type=str,
        required=False,
    )
    arg.add_argument(
        "--keep_percent",
        metavar="Val",
        help="Keep percent value used for Filtlong to filter for quality of reads, default 90",
        type=str,
        nargs='?',
        const='90',
        default='90',
        required=False,
    )
    arg.add_argument(
        "--trycycler",
        help="Supply if you want to run trycycler",
        action="store_true",
        required=False,
    )
    arg.add_argument(
        "--medaka",
        help="Supply if you want to run medaka",
        action="store_true",
        required=False,
    )
    arg.add_argument(
        "--all_assemblers",
        help="Supply to run all assemblers. To specify other combinations adjust files/assembler_choice.csv",
        action="store_true",
        required=False,
    )
    arg.add_argument(
        "--medaka_rounds",
        metavar="Val",
        help="Number of medaka rounds for polishing in case of supplying medaka flag, default 1",
        type=str,
        nargs='?',
        const='1',
        default='1',
        required=False,
    )
    arg.add_argument(
        "--medaka_model",
        metavar="Name",
        help="Medaka model to use when polishing, will also be supplied through the start_longread_assembly.sh",
        type=str,
        required=False,
    )
    return arg.parse_args()

def determine_outdir():
    """Overwrite the workdir if output flag is supplied"""
    if flags.output: 
        outdir = os.path.abspath(flags.output)
    else:  
        outdir = os.path.abspath(flags.workdir)
    return outdir


def read_txt(filename):
    with open(filename) as f:
        filedata = f.read()
    return filedata

def get_usercfg():
    # output_get_usercfg_h = irods_functions.get_usercfg_h()
    # Has been disabled for running outside RIVM
    # if output_get_usercfg_h:
    #     return output_get_usercfg_h
    # else:
        # with open(os.path.abspath(f"{origin_dir}/config/user.yaml"), "r") as f:
        #     configread = f.read()
        #     configyml = yaml.safe_load(configread)
    print(f"no user config accessible")
    return False
        # exit() # no user config accessible. can outcomment above and add own config
        # return configyml

####################################################################################################
## Declare parameters such as threads, mem_mb and wait for every used tool:                       ##
## Deletes samplesheet if already exists For now only generate config.yaml when it's not present. ##
####################################################################################################

def generate_parameter(filename):
    """Create parameter yaml file"""
    if os.path.isfile(filename) == True:
        os.remove(filename)
        print(f"{parameter_yaml_str} was already present - deleting previous file and making an new one")
    with open(filename, 'a') as parameter_open:
        parameter_open.write("# Single program parameters." + '\n')
        config_yaml = {}
        config_yaml = dict({'workdir' : OUT,
                            'keep_percent' : flags.keep_percent,
                            'keep_percent_str' : flags.keep_percent.split('.')[0],
                            'medaka_model' : flags.medaka_model,
                            'medaka_rounds' : flags.medaka_rounds,
                            'length': '1000', # hardcoded now but could become a flag
                            'headcrop': '80', # hardcoded now but could become a flag
                            'tailcrop': '80' # hardcoded now but could become a flag
                            })
        yaml.dump(config_yaml, parameter_open)
        parameter_open.write('\n' + "# Number of threads, mem_mb and wait (minutes)." + '\n')
        threads_mem_yaml = {}
        threads_mem_yaml['threads'] = dict({'default' : 1,
                                            'canu' : 4,
                                            'flye': 4,
                                            'kraken2':4,
                                            'medaka': 8,
                                            'miniasm_polish': 4, 
                                            'necat': 4, 
                                            'pycoqc': 1,
                                            'raven': 4,
                                            'redbean': 2,
                                            'longcycler': 8})
        threads_mem_yaml['max_mb'] = dict({'default' : 5000,
                                            'canu' : 60000,
                                            'flye': 20000,
                                            'kraken2': 60000,
                                            'medaka': 20000,
                                            'miniasm_polish': 20000, 
                                            'necat': 30000, 
                                            'pycoqc': 30000,
                                            'raven': 30000,
                                            'redbean': 15000,
                                            'longcycler': 60000})
        threads_mem_yaml['mem_mb'] = dict({'default' : 4000,
                                            'canu' : 48000,
                                            'flye': 16000,
                                            'kraken2': 48000,
                                            'medaka': 16000,
                                            'miniasm_polish': 16000, 
                                            'necat': 24000, 
                                            'pycoqc': 24000,
                                            'raven': 24000,
                                            'redbean': 12000,
                                            'longcycler': 48000})
        threads_mem_yaml['runtime_min'] = dict({'default' : 30,
                                            'canu' : 600,
                                            'flye': 60,
                                            'kraken2': 60,
                                            'medaka': 600,
                                            'longread': 1200,
                                            'miniasm_polish': 600, 
                                            'necat': 600, 
                                            'pycoqc': 45,
                                            'raven': 600,
                                            'redbean': 600,
                                            'longcycler': 600})
        yaml.dump(threads_mem_yaml, parameter_open)

    if os.path.isfile(f"{origin_dir}/{config}/{parameter_yaml_str}") == True: # If a current Snakemake parameter config exists delete it
        os.remove(f"{origin_dir}/{config}/{parameter_yaml_str}")
    shutil.copyfile(filename, f"{origin_dir}/{config}/{parameter_yaml_str}")

def ExtractFromSQLServer(key,cfg):
    # Search the CPE database for certain fields (which can differ from MRSA so made into separate functions)
    db = {'1':"db_name_1",'2':"db_name_2"}[key[0]]
    fields = {'1':"[SPECIES_FIELD],[PUBKEY_FIELD]",'2':"[SPECIES_FIELD],[PUBKEY_FIELD]"}[key[0]]
    connection = None
    try:
        connection = pymssql.connect(server=cfg['server'], database=db, user=cfg['user'], password=cfg['password'], as_dict=True)
        with connection.cursor() as cursor:
            cursor.execute(f"SELECT {fields} FROM [TABLE] WHERE [KEY] = '{key}'")
            if cursor.rowcount == 0:
                print("No Data")
            else:
                DATA = cursor.fetchall()
                DATA = [x for x in DATA]
                return DATA
    except Exception as e:
        emsg = traceback.format_exc()
        print(emsg, 'Exception from testSQLServerConnection')		
    finally:
        if not connection == None:
            connection.close()

def determine_single(fullname_dict):
    func_single_name_dict = {}
    func_single_name_count_dict = {}
    for v in fullname_dict:
        single = v.split(' ')[0]
        genomesize = fullname_dict[v]
        if single in func_single_name_dict:
            func_single_name_dict[single] = int((((func_single_name_dict[single] * func_single_name_count_dict[single]) + genomesize) / (func_single_name_count_dict[single]+1)))
            func_single_name_count_dict[single] += 1
        else: 
            func_single_name_dict[single] = genomesize
            func_single_name_count_dict[single] = 1
    return func_single_name_dict

def filter_longread(all_files): # Should probably not allow .fasta because filtlong/trycycler won't allow it
    # https://docs.python.org/3/library/re.html / https://regex101.com/
    pattern = '^[a-zA-Z0-9_.\-\#]*(.fastq.gz|.fasta.gz|.fasta|.fa|.fsa|.fastq)+$'
    longreads = []
    for file in all_files:
        if os.path.isfile(file):
            query = os.path.basename(file)
            if re.match(pattern, query):
                longreads.append(file)
            else:
                pass
    return longreads

def get_size(species_name, full_dict):
    func_size = 5000000 # default value
    if species_name in full_dict:
        func_size = full_dict[species_name]
    else:
        func_single_size = determine_single(full_dict)
        single_specie = species_name.split(' ')[0]
        if single_specie in func_single_size:
            func_size = func_single_size[single_specie]
    return func_size

def determine_assemblers(ac_file):
    to_use = []
    with open(ac_file, 'r') as file:
        csv_reader = csv.reader(file)
        for row in csv_reader:
            if row[1].lower() in ['yes', 'y']:
                to_use.append(row[0])
    if len(to_use) == 0:
        print(f"ERROR - no assembler selected to run, please check files/assembler_choice.csv and set at least 1 assembler to yes")
        exit()
    else:
        return to_use

def specific_sub(list_a, n=3):
    count = 0
    subset_yaml = {}
    padd_int_l = []
    for r in range(1,((len(list_a)*n)+1)):
        pad_int = str(r).zfill(2)
        # print((r + 2 % 3))
        if ((r + 2) % n) == 0:
            assembler = list_a[count]
            count += 1
        padd_int_l.append(pad_int)
        if (r % n) == 0:
            subset_yaml[assembler] = {f'name1' : f'sample_{padd_int_l[0]}',
                                        f'name2' : f'sample_{padd_int_l[1]}',
                                        f'name3' : f'sample_{padd_int_l[2]}'
                                        }
            padd_int_l = []
    return subset_yaml

def define_subsets():
    """Returns the correct subsets based on assembler list""" 
    # If I ever intend on making the subsets more flexible here would be the place to do it
    if flags.all_assemblers:
        subset_yaml = {}
        subset_yaml['canu'] = dict({
                    'name1' : 'sample_01',
                    'name2' : 'sample_02',
                    'name3': 'sample_03'})
        subset_yaml['flye'] = dict({
                    'name1' : 'sample_04',
                    'name2' : 'sample_05',
                    'name3': 'sample_06'})
        subset_yaml['miniasm_and_minipolish'] = dict({
                    'name1' : 'sample_07',
                    'name2' : 'sample_08',
                    'name3': 'sample_09'})
        subset_yaml['necat'] = dict({
                    'name1' : 'sample_10',
                    'name2' : 'sample_11',
                    'name3': 'sample_12'})
        subset_yaml['raven'] = dict({
                    'name1' : 'sample_13',
                    'name2' : 'sample_14',
                    'name3': 'sample_15'})
        subset_yaml['redbean'] = dict({
                    'name1' : 'sample_16',
                    'name2' : 'sample_17',
                    'name3': 'sample_18'})    
        subset_yaml['longcycler'] = dict({
                    'name1' : 'sample_19',
                    'name2' : 'sample_20',
                    'name3': 'sample_21'})
        return subset_yaml
    else:
        specific_yaml = specific_sub(determine_assemblers(f"{os.path.abspath(origin_dir)}/files/assembler_choice.csv"))
        return specific_yaml

def GetLongReadInputDir(path_to_barcode_dirs): 
    barcode_dirs = sorted(glob.glob(f"{os.path.abspath(path_to_barcode_dirs)}/barcode*"))
    dict_nanopore_input_dir = {} # Directory with barcode only, used for input rule in Snakemake
    for single_dir in barcode_dirs:
        barcode = single_dir.split('/')[-1]
        if len(glob.glob(f"{single_dir}/*")) == 0:
            # I need to make sure this will then also be exluded from running when no longread is found, however I don't think this will or should happen often.
            fullpath_headfile = f"{single_dir}/no_file_found.fastq.gz"
            directory = os.path.dirname(fullpath_headfile)
            dict_nanopore_input_dir[barcode] = directory
        else:
            fullpath_headfile = glob.glob(f"{single_dir}/*")[0]
            directory = os.path.dirname(fullpath_headfile)
            dict_nanopore_input_dir[barcode] = directory
    return dict_nanopore_input_dir

def generate_samplesheet_samples(run_barcode_keys, seqsum_filename, cfg):
    samplesheet_yaml = {}
    samplesheet_yaml['samples'] = {}
    samplesheet_yaml['subset_used'] = define_subsets()
    samplesheet_yaml['sequencing_summary'] = {}
    samplesheet_yaml['sequencing_summary'] = f"{OUT}/irods_files/{seqsum_filename}"
    for x in range(len(run_barcode_keys)): # ExtractFromBarcodeFilename(barcode_directories)[5] is ordered
        # Could get this part below in a seprate small function to determine the run_bar_key or otherwise sample names.
        if flags.longread:
            searchstring = os.path.basename(run_barcode_keys[x])
            pattern = '^PR[0-9]{4}_barcode[0-9]{2}_[0-9]{8}[_-]?[a-zA-Z0-9_.-]*(.fastq|.fastq.gz)+$'
            # pattern = '^R[0-9]{4}_barcode[0-9]{2}_[0-9]{8}[a-zA-Z0-9_.-]+$'
            if re.fullmatch(pattern, searchstring, flags=re.M): # If supplying a longread flag, check if these files have the file notation as expected so that type-ned key on 2nd index split on '_'
                sample = '_'.join(((searchstring).split('.')[0]).split('_')[:3])
                key = sample.split('_')[2]
                barcode = sample.split('_')[1]
            else:
                sample = os.path.basename(run_barcode_keys[x]).split('.')[0]
                key = sample.split('_')[0]
                barcode = 'barcode00'
        else:
            sample = run_barcode_keys[x]
            key = run_barcode_keys[x].split('_')[2]
            barcode = run_barcode_keys[x].split('_')[1]
        basecalled_dir = '' if flags.basecalled_dir.split('_')[-1] == 'NOSUBDIR' else flags.basecalled_dir
        if flags.input:
            barcode_directories = f"{os.path.abspath(flags.input)}/{basecalled_dir}"
        else:
            barcode_directories = f"{os.path.abspath(OUT)}/{basecalled_dir}"
        barcode_available = [os.path.basename(path) for path in sorted(glob.glob(f"{os.path.abspath(barcode_directories)}/barcode*"))]
        # if barcode not in barcode_available:
        #     pass
        # else:
        samplesheet_yaml['samples'][sample] = {}
        samplesheet_yaml['samples'][sample]['barcode'] = f"{barcode}"
        samplesheet_yaml['samples'][sample]['isolate_id'] = f"{key}"
        samplesheet_yaml['samples'][sample]['run_hybrid'] = f"False"

        samplesheet_yaml['samples'][sample]['run_trycycler'] = "True" if flags.trycycler else "False"
        samplesheet_yaml['samples'][sample]['run_medaka'] = "True" if flags.medaka else "False"

        if flags.longread:
            samplesheet_yaml['samples'][sample]["iRODS_mode"] = "False"
            samplesheet_yaml['samples'][sample]["filtlong_input"] = f"{run_barcode_keys[x]}"
            samplesheet_yaml['samples'][sample]["nanopore_input"] = f"{run_barcode_keys[x]}"
            # samplesheet_yaml['samples'][sample]["filtlong_input"] = f"{os.path.dirname(run_barcode_keys[x])}/{sample}"
        else:
            samplesheet_yaml['samples'][sample]["iRODS_mode"] = "True"
            samplesheet_yaml['samples'][sample]["filtlong_input"] = GetLongReadInputDir(barcode_directories)[barcode]
            samplesheet_yaml['samples'][sample]["nanopore_input"] = GetLongReadInputDir(barcode_directories)[barcode]
        # If the functions below returns 'No data' I should fill it with a default value else it will break here
        # if str(key).startswith('220') or str(key).startswith('290') or str(key).startswith('270') == True:
        #     samplesheet_yaml['samples'][sample]['species_full'] = ExtractFromSQLServer(key,cfg)[0]['ISOLATE_TL_SPECIES']
        #     samplesheet_yaml['samples'][sample]['publication_key'] = ExtractFromSQLServer(key,cfg)[0]['RIVM_PUBLIC_KEY']
        # elif str(key).startswith('110') or str(key).startswith('190') or str(key).startswith('111') == True:
        #     samplesheet_yaml['samples'][sample]['species_full'] = "Staphylococcus aureus"
        #     samplesheet_yaml['samples'][sample]['publication_key'] = ExtractFromSQLServer(key,cfg)[0]['RIVM_PUBLIC_KEY']
        samplesheet_yaml['samples'][sample]['species_full'] = "Not Provided"
        samplesheet_yaml['samples'][sample]['publication_key'] = f"{key}"
        samplesheet_yaml['samples'][sample]['genome_size'] = get_size(samplesheet_yaml['samples'][sample]['species_full'], species_full_size_dict)

    samplesheet_yaml['medaka_model_ss'] = {}
    samplesheet_yaml['medaka_model_ss'] = flags.medaka_model
    samplesheet_yaml['snakemake_directory'] = {}
    samplesheet_yaml['snakemake_directory'] = os.path.abspath(origin_dir)

    return samplesheet_yaml

def iget_files(irodspath):
    if irodspath:
        print(f"Downloading {irodspath}...", end=' ')
        SUB_CMD = f"iget -rvf {irodspath} {OUT}/irods_files/"
        SUB = subprocess.Popen(SUB_CMD, shell=True, stdout=subprocess.PIPE)
        SUB.communicate()
        print('...download completed!')
    else:
        pass

def determine_runbarkey():
    if flags.longread:
        runbarkey_list = filter_longread(sorted(glob.glob(f"{os.path.abspath(flags.longread)}/*")))
    else:
        if flags.nanoporedir: # Will be the case with input and alt_input flags
            nanopore_basename_dir = os.path.abspath(flags.nanoporedir) # This is without the 4 digits added by iRODS.
            runbarkey_list = irods_functions.ExtractFromjson(nanopore_basename_dir)[1]
    return runbarkey_list

def backup_samplesheet():
    # Want to make an backup because I sometimes rerun stuff :)
    now = datetime.now()
    dt_string = now.strftime("%Y%m%d_%H%M%S")
    Path(f"{os.path.abspath(OUT)}/{config}/backup").mkdir(parents=True, exist_ok=True)
    backup_savepath = f"{os.path.abspath(OUT)}/{config}/backup/{dt_string}_{samplesheet_yaml_str}"
    shutil.copyfile(filename_samplesheet_yaml, backup_savepath)
    os.remove(filename_samplesheet_yaml)
    print(f"config/samplesheet was already present - made an backup in the web but starting fresh :)")

def main():
    # TEXT
    global config; config = 'config'
    global parameter_yaml_str; parameter_yaml_str = "longread_parameter_config.yaml"
    global samplesheet_yaml_str; samplesheet_yaml_str = "longread_samplesheet.yaml"

    # PATHS
    current_file_path = os.path.abspath(__file__)
    global origin_dir; origin_dir = os.path.dirname(os.path.dirname(current_file_path))
    logo_path = os.path.join(origin_dir, "files", "logo.txt")
    global flags; flags = parse_arguments(getmylogo(logo_path))
    global OUT; OUT = determine_outdir()
    global filename_samplesheet_yaml; filename_samplesheet_yaml = f"{os.path.abspath(OUT)}/{config}/{samplesheet_yaml_str}"
    Path(f"{os.path.abspath(OUT)}/{config}").mkdir(parents=True, exist_ok=True)
    Path(f"{os.path.abspath(OUT)}/irods_files").mkdir(parents=True, exist_ok=True)

    # FILES / DATA
    species_data = read_txt(f"{os.path.abspath(origin_dir)}/files/species_size.txt")
    global species_full_size_dict; species_full_size_dict = json.loads(species_data)
    global configyml; configyml = get_usercfg()
    # html_output = irods_functions.irods_for_html_report(flags.nanoporedir)
    # sequence_sum_output = irods_functions.irods_for_sequence_sum(flags.nanoporedir)
    # iget_files(html_output[1]); iget_files(sequence_sum_output[1])

    # DO STUFF
    generate_parameter(f"{OUT}/{config}/{parameter_yaml_str}")
    if os.path.isfile(filename_samplesheet_yaml) == True:
        backup_samplesheet()
    with open(filename_samplesheet_yaml, 'a') as samplesheet_open:
        to_dump = generate_samplesheet_samples(determine_runbarkey(),'no_sequencing_summary.html',configyml)
        yaml.dump(to_dump, samplesheet_open)
    try: 
        shutil.copyfile(filename_samplesheet_yaml, f"{origin_dir}/{config}/{samplesheet_yaml_str}")
    except (shutil.SameFileError):
        print(f"Snakemake and working directory yaml were identical.")

if __name__ == "__main__":
    main()
