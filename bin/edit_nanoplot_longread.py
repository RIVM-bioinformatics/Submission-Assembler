import os.path, re, glob, os, yaml, argparse, csv, json
import pandas as pd
from pathlib import Path

# This entire script is pretty specific but it converts the default Nanoplot report files (NanoStats.txt) to a .csv that can be imported into BioNumerics.
# python /path/to/bin/edit_nanoplot_longread.py.py --sample R0131_barcode01_11045503 --workdir /path/to/collection_name

arg = argparse.ArgumentParser()

arg.add_argument(
    "--sample",
    metavar="Name",
    help="Isolate key to use in renaming and editing the assembly.fasta",
    type=str,
    required=True,
)

arg.add_argument(
    "--workdir",
    metavar="Name",
    help="Working directory in which to output all generated files - Should not be your Snakemake dir",
    type=str,
    required=False,
)

arg.add_argument(
    "--snakedir",
    metavar="Name",
    help="Snakemake directory in which all scripts are located, required for path to species_size.txt",
    type=str,
    required=True,
)

flags = arg.parse_args()

if str(flags.workdir) == 'None':
    out = os.path.abspath('')
else:
    out = os.path.abspath(flags.workdir)

snakeionary = f"{out}/config/longread_samplesheet.yaml"
with open(snakeionary) as file:
    samplesheet = yaml.load(file, Loader=yaml.FullLoader)

species_full_name = f"{samplesheet['samples'][flags.sample]['species_full']}"

species_file = f"{os.path.abspath(flags.snakedir)}/files/species_size.txt"
with open(species_file) as f:
    species_data = f.read()

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

species_full_size_dict = json.loads(species_data)

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

size_to_use = get_size(species_full_name, species_full_size_dict)

def calc_min_read_depth(size, totalbases):
    calc_total_bases = int(totalbases.split('.')[0]) # The total bases from Nanoplot always has a trailing ".0"
    func_read_depth = int(calc_total_bases / int(size))
    if func_read_depth >= 25:
        return 25
    else:
        return func_read_depth

keyname = flags.sample.split('_')[0] # changed to 0 for non irods version
output_directories = f"{os.path.abspath(out)}/nanoplot/*"

for single_dir in glob.glob(output_directories):
    filename_raw_stats = f"{single_dir}/{flags.sample}/NanoStats.txt"
    filename_save_stats = f"{single_dir}/{flags.sample}/{flags.sample}_NanoStats.csv"
    filename_min_read_depth = f"{single_dir}/{flags.sample}/min_read_depth.txt"
    dataframe = pd.read_csv(filename_raw_stats, delimiter = ";", header=None, engine='python')
    dataframe.columns = ['hoi']
    dataframe = dataframe.hoi.str.split(":", expand=True)
    dataframe.columns = ['Description','Value']
    dataframe['Value'] = dataframe['Value'].str.replace(',','')
    dataframe['Value'] = dataframe['Value'].str.replace('\t','')
    dataframe['Description'] = dataframe['Description'].str.replace('\t',' ')
    GENERALINDEX_SEARCH = 'General summary'
    SEARCHSTRING1 = 'Number, percentage and megabases of reads above quality cutoffs'
    SEARCHSTRING2 = 'Top 5 highest mean basecall quality scores and their read lengths'
    SEARCHSTRING3 = 'Top 5 longest reads and their mean basecall quality score'
    GENERALINDEX = dataframe[dataframe['Description'] == GENERALINDEX_SEARCH].index[0]
    LOOP1 = dataframe[dataframe['Description'] == SEARCHSTRING1].index[0]
    LOOP2 = dataframe[dataframe['Description'] == SEARCHSTRING2].index[0]
    LOOP3 = dataframe[dataframe['Description'] == SEARCHSTRING3].index[0]
    dataframe_list = []
    for i in range(1, 9):
        dataframe_list.append(f"{dataframe['Description'][i]}," + f"{dataframe['Value'][i]}")
        if i == 8:
            total_bases = f"{dataframe['Value'][i]}"
            min_read_depth = calc_min_read_depth(size_to_use,total_bases)
            coverage = round(int(total_bases.split('.')[0]) / int(size_to_use),2)
            dataframe_list.append(f"Coverage," + f"{coverage}")
            with open(filename_min_read_depth, 'w') as read_infile:
                read_infile.write(str(min_read_depth))
    for a in range(5):
        INDEX1 = (LOOP1 + a + 1)
        INDEX2 = (LOOP2 + a + 1)
        INDEX3 = (LOOP3 + a + 1)
        for x in range(len(dataframe['Value'][INDEX1].split(' '))): # The initial Value column actually contains 2 or 3 values that will be assigned to a new row
            if x == 2:
                dataframe_list.append(f"Megabases {dataframe['Description'][INDEX1]}," + f"{dataframe['Value'][INDEX1].split(' ')[x]}")
            if 'NA' not in dataframe['Value'][INDEX2].split(' '):
                if x == 0:
                    dataframe_list.append(f"Number of reads {dataframe['Description'][INDEX1]}," + f"{dataframe['Value'][INDEX1].split(' ')[x]}")
                    dataframe_list.append(f"Top {dataframe['Description'][INDEX2]} highest mean basecall quality score," + f"{dataframe['Value'][INDEX2].split(' ')[x]}")
                    dataframe_list.append(f"Top {dataframe['Description'][INDEX3]} longest read," + f"{dataframe['Value'][INDEX3].split(' ')[x]}")
                if x == 1:
                    dataframe_list.append(f"Percentage of reads {dataframe['Description'][INDEX1]}," + f"{dataframe['Value'][INDEX1].split(' ')[x]}")
                    dataframe_list.append(f"Top {dataframe['Description'][INDEX2]} highest mean read length," + f"{dataframe['Value'][INDEX2].split(' ')[x]}")
                    dataframe_list.append(f"Top {dataframe['Description'][INDEX3]} highest qscore," + f"{dataframe['Value'][INDEX3].split(' ')[x]}")

    dataframe_new = pd.DataFrame(dataframe_list)
    # dataframe_new[['Description', 'Value']] = dataframe_new[0].str.split(',', 1, expand=True) # gave an error with pandas 2.0.2
    dataframe_new[['Description', 'Value']] = dataframe_new[0].str.split(',', expand=True)
    dataframe_new = dataframe_new.drop(columns=[0])
    dataframe_new.insert(0, "Key", keyname, True)
    dataframe_new.insert(3, "Run_Bar_Key", flags.sample, True)
    dataframe_new['Value'] = dataframe_new['Value'].str.replace('[(,%,),Mb]', '', regex=True)
    dataframe_new.to_csv(filename_save_stats, sep=',', header=['Key', 'Description', 'Value', 'Run_Bar_Key'], index=False)
