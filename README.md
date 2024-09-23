# submission-assembler

```
cd existing_repo
git remote add origin https://github.com/RIVM-bioinformatics/Submission-Assembler
git branch -M main
git push -uf origin main
```

## Assembler used for Genome Medicine paper
This Snakemake pipeline was used to assemble data for our article 'Genomic surveillance of multidrug-resistant organisms based on long-read sequencing' submitted to Genome Medicine.

## Description
Will assemble longread data using six different assemblers. Canu, Flye, Miniasm and minipolish, Necat, Raven, Redbean, and Longcycler (Unicycler's long-read option)

## Installation
#Step 1: Navigate to the directory where you want to clone the project
```
cd /path/to/your/directory
```
#Step 2: Clone the repository
```
git clone https://github.com/RIVM-bioinformatics/Submission-Assembler.git
```
#Step 3: Change into the project directory
```
cd your-repo
```

## Usage
bash /path/to/your/directory/your-repo/start_longread_assembly.sh --longread /path/to/longread_data/
On default the output directory will be created inside current working directory + "assembly_YYMMDD_HHhMMmSSs"
Optionally --output flag can be suplied.

## Authors and acknowledgment
Pipeline written by Fabian Landman and special thanks to Robert Verhagen for usage of cluster commands

## License
This project is licensed under the MIT License - see the LICENSE file for details.

## Project status
This pipeline has been uploaded for submission of our article only and shall not be further developed.