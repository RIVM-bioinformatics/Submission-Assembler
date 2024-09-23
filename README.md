# atlas-assembler



## Add your files

- [ ] [Create](https://docs.gitlab.com/ee/user/project/repository/web_editor.html#create-a-file) or [upload](https://docs.gitlab.com/ee/user/project/repository/web_editor.html#upload-a-file) files
- [ ] [Add files using the command line](https://docs.gitlab.com/ee/gitlab-basics/add-file.html#add-a-file-using-the-command-line) or push an existing Git repository with the following command:

```
cd existing_repo
git remote add origin https://gitl01-int-p.rivm.nl/bsr-amr-production-pipelines/atlas-assembler.git
git branch -M main
git push -uf origin main
```

## Suggestions for a good README

Every project is different, so consider which of these sections apply to yours. The sections used in the template are suggestions for most open source projects. Also keep in mind that while a README can be too long and detailed, too long is better than too short. If you think your README is too long, consider utilizing another form of documentation rather than cutting out information.

## Assembler used for Genome Medicine paper
This Snakemake pipeline was used to assemble data for our article 'Genomic surveillance of multidrug-resistant organisms based on long-read sequencing' submitted to Genome Medicine.

## Description

Let people know what your project can do specifically. Provide context and add a link to any reference visitors might be unfamiliar with. A list of Features or a Background subsection can also be added here. If there are alternatives to your project, this is a good place to list differentiating factors.

## Installation
# Step 1: Navigate to the directory where you want to clone the project
cd /path/to/your/directory

# Step 2: Clone the repository
git clone https://github.com/yourusername/your-repo.git

# Step 3: Change into the project directory
cd your-repo

## Usage
bash /path/to/your/directory/your-repo/start_longread_assembly.sh --longread /path/to/longread_data/
On default the output directory will be created inside current working directory + "assembly_YYMMDD_HHhMMmSSs"
Use examples liberally, and show the expected output if you can. It's helpful to have inline the smallest example of usage that you can demonstrate, while providing links to more sophisticated examples if they are too long to reasonably include in the README.

## Support


## Authors and acknowledgment
Pipeline written by Fabian Landman and special thanks to Robert Verhagen

## License
For open source projects, say how it is licensed.

## Project status
This pipeline has been uploaded for submission of our article only and shall not be further developed.