
import yaml, os

configfile: "config/longread_samplesheet.yaml" 
configfile: "config/longread_parameter_config.yaml"

OUT = config["workdir"]
S_OUT = config["snakemake_directory"] # Need this for Redbean for which the script is inside this repo

def determine_final_try(wildcards, attempt):
    return attempt * 1

assembler_list = [assembler for assembler in config["subset_used"]]
medaka_samples = [sample for sample in config["samples"] if config["samples"][sample]["run_medaka"] == "True"]
no_polishing = [sample for sample in config["samples"] if config["samples"][sample]["run_medaka"] != "True"]


rule all:
    input:
        assembly_all = expand([OUT + "/assembly/text/{sample}-{assembler}_collected.txt"], sample = config["samples"], assembler = assembler_list),
        medaka_assembly_all = expand([OUT + "/medaka/{sample}/{assembler}" +  "/medaka_completed.txt"], sample = medaka_samples, assembler = assembler_list),
        nanoplot_completed = expand([OUT + "/nanoplot/gz_filtlong/{sample}/min_read_depth.txt"], sample = config["samples"]),
        # pycoqc = OUT + "/pycoqc/sequencing_summary.html",


rule collect_assembly:
    input:
        OUT + "/{assembler}/{sample}/assembly/assembly.fasta",
    output:
        OUT + "/assembly/text/{sample}-{assembler}_collected.txt"
    conda:
        "envs/amr_longread.yaml"
    threads: config["threads"]["default"] # 1
    resources: 
        max_mb = config["max_mb"]["default"],
        mem_mb = config["mem_mb"]["default"], # 4
        runtime_min = config["runtime_min"]["default"] # 30
    params:
        outdir_base = OUT,
        outdir_all = OUT + "/assembly/all/",
        outdir_ass = OUT + "/assembly/{assembler}/",
        output_1 = OUT + "/assembly/{assembler}/{sample}_assembly.fasta",
        output_2 = OUT + "/assembly/all/{sample}_{assembler}_assembly.fasta"
    log:
        OUT + "/log/assembly_collect/{sample}_{assembler}.log"
    shell:
        """
echo $'\n====================================\n==     PROGRAM VERSIONS USED      ==\n====================================\n' >> {log}; conda list >> {log}
mkdir -p {params.outdir_all}
mkdir -p {params.outdir_ass}
cp {input} {params.output_1} \
&& cp {input} {params.output_2} \
&& touch {output}
        """


rule medaka_collect:
# This one is just to make the rule all a bit more clean.
    input:
        OUT + "/medaka/{sample}/{assembler}/assembly.fasta"
    output:
        OUT + "/medaka/{sample}/{assembler}/medaka_completed.txt"
    conda:
        "envs/amr_longread.yaml"
    threads: config["threads"]["default"] # 1
    resources: 
        max_mb = config["max_mb"]["default"],
        mem_mb = config["mem_mb"]["default"], # 4
        runtime_min = config["runtime_min"]["default"] # 30
    log:
        OUT + "/log/medaka_collect/{sample}_{assembler}.log"
    benchmark:
        OUT + "/log/benchmark/medaka_collect/{sample}_{assembler}.txt"
    shell:
        """
echo $'\n====================================\n==     PROGRAM VERSIONS USED      ==\n====================================\n' >> {log}; conda list >> {log}
touch {output}
        """


rule flye:
    input:
        OUT + "/gz/filtlong/{sample}_min1000_best" + config["keep_percent_str"] + ".fastq.gz"
    output:
        OUT + "/flye/{sample}/assembly/assembly.fasta"
    conda:
        "envs/amr_longread.yaml"
    threads: config["threads"]["flye"] # 4
    resources: 
        max_mb = config["max_mb"]["flye"],
        mem_mb = config["mem_mb"]["flye"], # 12
        runtime_min = config["runtime_min"]["longread"] # 1200
    params:
        outdir = OUT + "/flye/{sample}/assembly/"
    log:
        OUT + "/log/flye/{sample}_assembly.log"
    benchmark:
        OUT + "/log/benchmark/flye/{sample}_assembly.txt"
    shell:
        """
echo $'\n====================================\n==     PROGRAM VERSIONS USED      ==\n====================================\n' >> {log}; conda list >> {log}
flye --nano-raw {input} \
    --threads {threads} \
    --out-dir {params.outdir} \
    2> {log}
        """


rule medaka_flye:
    input:
        assembly = OUT + "/flye/{sample}/assembly/assembly.fasta",
        longreadset = OUT + "/gz/filtlong/{sample}_min1000_best" + config["keep_percent_str"] + ".fastq.gz"
    output:
        OUT + "/medaka/{sample}/flye/assembly.fasta"
    conda:
        "envs/medaka.yaml"
    threads: config["threads"]["medaka"] # 
    resources: 
        max_mb = config["max_mb"]["medaka"],
        mem_mb = config["mem_mb"]["medaka"], # 
        runtime_min = config["runtime_min"]["medaka"] # 
    params:
        outdir = OUT + "/medaka/{sample}/flye",
        model = config["medaka_model"],
        rounds = config["medaka_rounds"]
    log:
        OUT + "/log/medaka/medaka_flye_{sample}.log"
    benchmark:
        OUT + "/log/benchmark/medaka/medaka_flye_{sample}.txt"
    shell:
        """
echo $'\n====================================\n==     PROGRAM VERSIONS USED      ==\n====================================\n' >> {log}; conda list >> {log}
for (( round=1; round<={params.rounds}; round++ )) ; do
    if [ $round -eq 1 ] ; then
        input_assembly={input.assembly}
    else
        input_assembly={params.outdir}/round$((round-1))/consensus.fasta
    fi
    medaka_consensus -i {input.longreadset} \
        -d $input_assembly \
        -o {params.outdir}/round$round \
        -t {threads} \
        -m {params.model} \
        2> {log}
done
cp {params.outdir}/round{params.rounds}/consensus.fasta {output}
        """


rule longcycler:
    input:
        OUT + "/gz/filtlong/{sample}_min1000_best" + config["keep_percent_str"] + ".fastq.gz"
    output:
        OUT + "/longcycler/{sample}/assembly/assembly.fasta"
    conda:
        "envs/amr_longread.yaml"
    threads: config["threads"]["longcycler"] # 4
    resources: 
        max_mb = config["max_mb"]["longcycler"],
        mem_mb = config["mem_mb"]["longcycler"], # 12
        runtime_min = config["runtime_min"]["longread"] # 1200
    params:
        outdir = OUT + "/longcycler/{sample}/assembly/"
    log:
        OUT + "/log/longcycler/{sample}_assembly.log"
    benchmark:
        OUT + "/log/benchmark/longcycler/{sample}_assembly.txt"
    shell:
        """
echo $'\n====================================\n==     PROGRAM VERSIONS USED      ==\n====================================\n' >> {log}; conda list >> {log}
unicycler --threads {threads} \
    --long {input} \
    --min_fasta_length 200 \
    --out {params.outdir} \
    --verbosity 2 \
    2> {log}
        """


rule medaka_longcycler:
    input:
        assembly = OUT + "/longcycler/{sample}/assembly/assembly.fasta",
        longreadset = OUT + "/gz/filtlong/{sample}_min1000_best" + config["keep_percent_str"] + ".fastq.gz"
    output:
        OUT + "/medaka/{sample}/longcycler/assembly.fasta"
    conda:
        "envs/medaka.yaml"
    threads: config["threads"]["medaka"] # 
    resources: 
        max_mb = config["max_mb"]["medaka"],
        mem_mb = config["mem_mb"]["medaka"], # 
        runtime_min = config["runtime_min"]["medaka"] # 
    params:
        outdir = OUT + "/medaka/{sample}/longcycler",
        model = config["medaka_model"],
        rounds = config["medaka_rounds"]
    log:
        OUT + "/log/medaka/medaka_longcycler_{sample}.log"
    benchmark:
        OUT + "/log/benchmark/medaka/medaka_longcycler_{sample}.txt"
    shell:
        """
echo $'\n====================================\n==     PROGRAM VERSIONS USED      ==\n====================================\n' >> {log}; conda list >> {log}
for (( round=1; round<={params.rounds}; round++ )) ; do
    if [ $round -eq 1 ] ; then
        input_assembly={input.assembly}
    else
        input_assembly={params.outdir}/round$((round-1))/consensus.fasta
    fi
    medaka_consensus -i {input.longreadset} \
        -d $input_assembly \
        -o {params.outdir}/round$round \
        -t {threads} \
        -m {params.model} \
        2> {log}
done
cp {params.outdir}/round{params.rounds}/consensus.fasta {output}
        """


rule miniasm_and_minipolish:
    input:
        OUT + "/gz/filtlong/{sample}_min1000_best" + config["keep_percent_str"] + ".fastq.gz"
    output:
        OUT + "/miniasm_and_minipolish/{sample}/assembly/assembly.fasta"
    conda:
        "envs/amr_longread.yaml"
    threads: config["threads"]["miniasm_polish"] # 1
    resources: 
        max_mb = config["max_mb"]["miniasm_polish"],
        mem_mb = config["mem_mb"]["miniasm_polish"], # 4
        runtime_min = config["runtime_min"]["longread"] # 1200
    params:
        outdir = OUT + "/miniasm_and_minipolish/{sample}/assembly"
    log:
        OUT + "/log/miniasm_and_minipolish/{sample}_assembly.log"
    benchmark:
        OUT + "/log/benchmark/miniasm_and_minipolish/{sample}_assembly.txt"
    shell:
        """
echo $'\n====================================\n==     PROGRAM VERSIONS USED      ==\n====================================\n' >> {log}; conda list >> {log}
mkdir -p {params.outdir}/ ; \
bin/miniasm_and_minipolish.sh \
    {input} \
    {threads} \
    > {params.outdir}/assembly.gfa \
    2> {log} \
    && any2fasta {params.outdir}/assembly.gfa > {params.outdir}/assembly_miniasm.fasta \
    && sleep 60 \
    && cp {params.outdir}/assembly_miniasm.fasta {output}
        """


rule medaka_miniasm_and_minipolish:
    input:
        assembly = OUT + "/miniasm_and_minipolish/{sample}/assembly/assembly.fasta",
        longreadset = OUT + "/gz/filtlong/{sample}_min1000_best" + config["keep_percent_str"] + ".fastq.gz"
    output:
        OUT + "/medaka/{sample}/miniasm_and_minipolish/assembly.fasta"
    conda:
        "envs/medaka.yaml"
    threads: config["threads"]["medaka"] # 
    resources: 
        max_mb = config["max_mb"]["medaka"],
        mem_mb = config["mem_mb"]["medaka"], # 
        runtime_min = config["runtime_min"]["medaka"] # 
    params:
        outdir = OUT + "/medaka/{sample}/miniasm_and_minipolish",
        model = config["medaka_model"],
        rounds = config["medaka_rounds"]
    log:
        OUT + "/log/medaka/medaka_miniasm_and_minipolish_{sample}.log"
    benchmark:
        OUT + "/log/benchmark/medaka/medaka_miniasm_and_minipolish_{sample}.txt"
    shell:
        """
echo $'\n====================================\n==     PROGRAM VERSIONS USED      ==\n====================================\n' >> {log}; conda list >> {log}
for (( round=1; round<={params.rounds}; round++ )) ; do
    if [ $round -eq 1 ] ; then
        input_assembly={input.assembly}
    else
        input_assembly={params.outdir}/round$((round-1))/consensus.fasta
    fi
    medaka_consensus -i {input.longreadset} \
        -d $input_assembly \
        -o {params.outdir}/round$round \
        -t {threads} \
        -m {params.model} \
        2> {log}
done
cp {params.outdir}/round{params.rounds}/consensus.fasta {output}
        """


rule raven:
    input:
        OUT + "/gz/filtlong/{sample}_min1000_best" + config["keep_percent_str"] + ".fastq.gz"
    output:
        OUT + "/raven/{sample}/assembly/assembly.fasta"
    conda:
        "envs/amr_longread.yaml"
    threads: config["threads"]["raven"] # 1
    resources: 
        max_mb = config["max_mb"]["raven"],
        mem_mb = config["mem_mb"]["raven"], # 4
        runtime_min = config["runtime_min"]["longread"] # 1200
    params:
        outdir = OUT + "/raven/{sample}/assembly"
    log:
        OUT + "/log/raven/{sample}_assembly.log"
    benchmark:
        OUT + "/log/benchmark/raven/{sample}_assembly.txt"
    shell:
        """
echo $'\n====================================\n==     PROGRAM VERSIONS USED      ==\n====================================\n' >> {log}; conda list >> {log}
mkdir -p {params.outdir}/ ; \
raven {input} \
    > {params.outdir}/temp_assembly.fasta 2> {log} && \
    sleep 60 ; \
    cp {params.outdir}/temp_assembly.fasta {params.outdir}/assembly.fasta ; 
        """


rule medaka_raven:
    input:
        assembly = OUT + "/raven/{sample}/assembly/assembly.fasta",
        longreadset = OUT + "/gz/filtlong/{sample}_min1000_best" + config["keep_percent_str"] + ".fastq.gz"
    output:
        OUT + "/medaka/{sample}/raven/assembly.fasta"
    conda:
        "envs/medaka.yaml"
    threads: config["threads"]["medaka"] # 
    resources: 
        max_mb = config["max_mb"]["medaka"],
        mem_mb = config["mem_mb"]["medaka"], # 
        runtime_min = config["runtime_min"]["medaka"] # 
    params:
        outdir = OUT + "/medaka/{sample}/raven",
        model = config["medaka_model"],
        rounds = config["medaka_rounds"]
    log:
        OUT + "/log/medaka/medaka_raven_{sample}.log"
    benchmark:
        OUT + "/log/benchmark/medaka/medaka_raven_{sample}.txt"
    shell:
        """
echo $'\n====================================\n==     PROGRAM VERSIONS USED      ==\n====================================\n' >> {log}; conda list >> {log}
for (( round=1; round<={params.rounds}; round++ )) ; do
    if [ $round -eq 1 ] ; then
        input_assembly={input.assembly}
    else
        input_assembly={params.outdir}/round$((round-1))/consensus.fasta
    fi
    medaka_consensus -i {input.longreadset} \
        -d $input_assembly \
        -o {params.outdir}/round$round \
        -t {threads} \
        -m {params.model} \
        2> {log}
done
cp {params.outdir}/round{params.rounds}/consensus.fasta {output}
        """


rule canu:
    input:
        OUT + "/gz/filtlong/{sample}_min1000_best" + config["keep_percent_str"] + ".fastq.gz"
    output:
        OUT + "/canu/{sample}/assembly/assembly.fasta"
    conda:
        "envs/amr_longread.yaml"
    threads: config["threads"]["canu"] # 4
    resources: 
        max_mb = config["max_mb"]["canu"],
        mem_mb = config["mem_mb"]["canu"], # 48
        runtime_min = config["runtime_min"]["longread"] # 1200
    params:
        prefix = "{sample}",
        outdir = OUT + "/canu/{sample}/assembly",
        genome_size = lambda wildcards: config["samples"][wildcards.sample]["genome_size"],
        contigsfile = OUT + "/canu/{sample}/assembly/{sample}.contigs.fasta"
    log:
        OUT + "/log/canu/{sample}_assembly.log"
    benchmark:
        OUT + "/log/benchmark/canu/{sample}_assembly.txt"
    shell:
        """
echo $'\n====================================\n==     PROGRAM VERSIONS USED      ==\n====================================\n' >> {log}; conda list >> {log}
canu -p {params.prefix} \
    -d {params.outdir}/ \
    genomeSize={params.genome_size} \
    stopOnLowCoverage=0 \
    minInputCoverage=1 \
    useGrid=false \
    -nanopore {input} \
    2> {log} \
&& cp {params.contigsfile} {output}
        """


rule medaka_canu:
    input:
        assembly = OUT + "/canu/{sample}/assembly/assembly.fasta",
        longreadset = OUT + "/gz/filtlong/{sample}_min1000_best" + config["keep_percent_str"] + ".fastq.gz"
    output:
        OUT + "/medaka/{sample}/canu/assembly.fasta"
    conda:
        "envs/medaka.yaml"
    threads: config["threads"]["medaka"] # 
    resources: 
        max_mb = config["max_mb"]["medaka"],
        mem_mb = config["mem_mb"]["medaka"], # 
        runtime_min = config["runtime_min"]["medaka"] # 
    params:
        outdir = OUT + "/medaka/{sample}/canu",
        model = config["medaka_model"],
        rounds = config["medaka_rounds"]
    log:
        OUT + "/log/medaka/medaka_canu_{sample}.log"
    benchmark:
        OUT + "/log/benchmark/medaka/medaka_canu_{sample}.txt"
    shell:
        """
echo $'\n====================================\n==     PROGRAM VERSIONS USED      ==\n====================================\n' >> {log}; conda list >> {log}
for (( round=1; round<={params.rounds}; round++ )) ; do
    if [ $round -eq 1 ] ; then
        input_assembly={input.assembly}
    else
        input_assembly={params.outdir}/round$((round-1))/consensus.fasta
    fi
    medaka_consensus -i {input.longreadset} \
        -d $input_assembly \
        -o {params.outdir}/round$round \
        -t {threads} \
        -m {params.model} \
        2> {log}
done
cp {params.outdir}/round{params.rounds}/consensus.fasta {output}
        """


rule redbean:
# Redbean works with the .pl script and just needs the dir path with all the extra files
# It's installed through envs/amr_longread.post-deploy.sh
    input:
        OUT + "/gz/filtlong/{sample}_min1000_best" + config["keep_percent_str"] + ".fastq.gz"
    output:
        OUT + "/redbean/{sample}/assembly/assembly.fasta"
    conda:
        "envs/amr_longread.yaml"
    threads: config["threads"]["redbean"] # 16
    resources: 
        max_mb = config["max_mb"]["redbean"],
        mem_mb = config["mem_mb"]["redbean"], # 4
        runtime_min = config["runtime_min"]["longread"] # 1200
    params:
        outdir = OUT + "/redbean/{sample}/assembly",
        redbean = S_OUT + "/wtdbg2/wtdbg2.pl",
        genome_size = lambda wildcards: config["samples"][wildcards.sample]["genome_size"]
    log:
        OUT + "/log/redbean/{sample}_assembly.log"
    benchmark:
        OUT + "/log/benchmark/redbean/{sample}_assembly.txt"
    shell:
        """
echo $'\n====================================\n==     PROGRAM VERSIONS USED      ==\n====================================\n' >> {log}; conda list >> {log}
{params.redbean} \
    -o {params.outdir}/ \
    -g {params.genome_size} \
    -x ont \
    -t 16 \
    {input} \
    2> {log} \
    && cp {params.outdir}/.cns.fa {output}
        """


rule medaka_redbean:
    input:
        assembly = OUT + "/redbean/{sample}/assembly/assembly.fasta",
        longreadset = OUT + "/gz/filtlong/{sample}_min1000_best" + config["keep_percent_str"] + ".fastq.gz"
    output:
        OUT + "/medaka/{sample}/redbean/assembly.fasta"
    conda:
        "envs/medaka.yaml"
    threads: config["threads"]["medaka"] # 
    resources: 
        max_mb = config["max_mb"]["medaka"],
        mem_mb = config["mem_mb"]["medaka"], # 
        runtime_min = config["runtime_min"]["medaka"] # 
    params:
        outdir = OUT + "/medaka/{sample}/redbean",
        model = config["medaka_model"],
        rounds = config["medaka_rounds"]
    log:
        OUT + "/log/medaka/medaka_redbean_{sample}.log"
    benchmark:
        OUT + "/log/benchmark/medaka/medaka_redbean_{sample}.txt"
    shell:
        """
echo $'\n====================================\n==     PROGRAM VERSIONS USED      ==\n====================================\n' >> {log}; conda list >> {log}
for (( round=1; round<={params.rounds}; round++ )) ; do
    if [ $round -eq 1 ] ; then
        input_assembly={input.assembly}
    else
        input_assembly={params.outdir}/round$((round-1))/consensus.fasta
    fi
    medaka_consensus -i {input.longreadset} \
        -d $input_assembly \
        -o {params.outdir}/round$round \
        -t {threads} \
        -m {params.model} \
        2> {log}
done
cp {params.outdir}/round{params.rounds}/consensus.fasta {output}
        """


rule necat:
    input:
        OUT + "/gz/filtlong/{sample}_min1000_best" + config["keep_percent_str"] + ".fastq.gz"
    output:
        OUT + "/necat/{sample}/assembly/assembly.fasta"
    conda:
        "envs/amr_longread.yaml"
    threads: config["threads"]["necat"] # 16
    resources: 
        max_mb = config["max_mb"]["necat"],
        mem_mb = config["mem_mb"]["necat"], # 12
        runtime_min = config["runtime_min"]["longread"], # 1200
        retry_count = determine_final_try
    params:
        necat_config = OUT + "/necat/{sample}/assembly/necat_cfg.txt",
        outdir = OUT + "/necat/{sample}/assembly",
        contigsfile = OUT + "/necat/{sample}/assembly/assembly/6-bridge_contigs/polished_contigs.fasta"
    log:
        OUT + "/log/necat/{sample}_assembly.log"
    benchmark:
        OUT + "/log/benchmark/necat/{sample}_assembly.txt"
    shell:
        """
echo $'\n====================================\n==     PROGRAM VERSIONS USED      ==\n====================================\n' >> {log}; conda list >> {log}
if [ {resources.retry_count} == 4 ] 
then 
    rm {params.outdir}/core.* 
    if [ ! -f {output} ] 
    then 
        touch {output} 
    fi 
else 
    cd {params.outdir}/ && \
    necat \
    bridge {params.necat_config} \
    2> {log} \
    && cp {params.contigsfile} {output} ; \
fi 
        """


rule medaka_necat:
    input:
        assembly = OUT + "/necat/{sample}/assembly/assembly.fasta",
        longreadset = OUT + "/gz/filtlong/{sample}_min1000_best" + config["keep_percent_str"] + ".fastq.gz"
    output:
        OUT + "/medaka/{sample}/necat/assembly.fasta"
    conda:
        "envs/medaka.yaml"
    threads: config["threads"]["medaka"] # 
    resources: 
        max_mb = config["max_mb"]["medaka"],
        mem_mb = config["mem_mb"]["medaka"], # 
        runtime_min = config["runtime_min"]["medaka"] # 
    params:
        outdir = OUT + "/medaka/{sample}/necat",
        model = config["medaka_model"],
        rounds = config["medaka_rounds"]
    log:
        OUT + "/log/medaka/medaka_necat_{sample}.log"
    benchmark:
        OUT + "/log/benchmark/medaka/medaka_necat_{sample}.txt"
    shell:
        """
echo $'\n====================================\n==     PROGRAM VERSIONS USED      ==\n====================================\n' >> {log}; conda list >> {log}
for (( round=1; round<={params.rounds}; round++ )) ; do
    if [ $round -eq 1 ] ; then
        input_assembly={input.assembly}
    else
        input_assembly={params.outdir}/round$((round-1))/consensus.fasta
    fi
    medaka_consensus -i {input.longreadset} \
        -d $input_assembly \
        -o {params.outdir}/round$round \
        -t {threads} \
        -m {params.model} \
        2> {log}
done
cp {params.outdir}/round{params.rounds}/consensus.fasta {output}
        """


rule nanoplot:
    input:
        fastq_internal = OUT + "/fastq/chopper/unfiltered_{sample}.fastq",
        gz_chopper = OUT + "/gz/chopper/{sample}_min" + config["length"] + ".fastq.gz",
        gz_filtlong = OUT + "/gz/filtlong/{sample}_min1000_best" + config["keep_percent_str"] + ".fastq.gz"
    output:
        read_depth_try = OUT + "/nanoplot/gz_filtlong/{sample}/min_read_depth.txt" # Was needed for Trycycler subsets but it does make the rule all clean, its a file created by the Python script in this rule.
    conda:
        "envs/nanoplot.yaml"
    threads: config["threads"]["default"]
    resources: 
        max_mb = config["max_mb"]["default"],
        mem_mb = config["mem_mb"]["default"],
        runtime_min = config["runtime_min"]["default"]
    params:
        out_fastq_internal = OUT + "/nanoplot/fastq_unfiltered/{sample}",
        out_gz_chopper = OUT + "/nanoplot/gz_chopper/{sample}",
        out_gz_filtlong = OUT + "/nanoplot/gz_filtlong/{sample}",
        workdir = config["workdir"],
        snakedir = config["snakemake_directory"]
    log:
        OUT + "/log/nanoplot/{sample}.log"
    benchmark:
        OUT + "/log/nanoplot/nanoplot_{sample}.txt"
    shell: # Only when all 3 NanoPlot reports have been generated can the edit python script start - So yeah they run sequentially now
        """
echo $'\n====================================\n==     PROGRAM VERSIONS USED      ==\n====================================\n' >> {log}; conda list >> {log}
NanoPlot --fastq {input.fastq_internal} \
        -o {params.out_fastq_internal} \
        2> {log} \
&& \
NanoPlot --fastq {input.gz_chopper} \
        -o {params.out_gz_chopper} \
        2> {log} \
&& \
NanoPlot --fastq {input.gz_filtlong} \
        -o {params.out_gz_filtlong} \
        2> {log} \
&& \
python bin/edit_nanoplot_longread.py --sample {wildcards.sample} --workdir {params.workdir} --snakedir {params.snakedir}
        """


rule filtlong:
    input:
        gz_chopper = OUT + "/gz/chopper/{sample}_min" + config["length"] + ".fastq.gz"
    output: # If I want to add option to not filter at all (because it has already been done for example) I could make the keep_percent_str to be '_best90' for example. And then if statement for keep_percent flag yes or no.
        temp(OUT + "/gz/filtlong/{sample}_min1000_best" + config["keep_percent_str"] + ".fastq.gz")
    conda:
        "envs/amr_longread.yaml"
    threads: config["threads"]["default"]
    resources: 
        max_mb = config["max_mb"]["default"],
        mem_mb = config["mem_mb"]["default"],
        runtime_min = config["runtime_min"]["default"]
    params:
        filtlong_temp = OUT + "/tmp/temp{sample}.fastq",
        keep_percent = config["keep_percent"],
    log:
        OUT + "/log/filtlong/{sample}.log"
    benchmark:
        OUT + "/log/benchmark/filtlong/{sample}.txt"
    shell: # Write to a temp file because otherwise Snakemake seemed to think the final file had already been created and tried to continue.
        """
echo $'\n====================================\n==     PROGRAM VERSIONS USED      ==\n====================================\n' >> {log}; conda list >> {log}
zcat -f {input.gz_chopper} > {params.filtlong_temp} \
&& \
filtlong    --min_length 1000 \
            --keep_percent {params.keep_percent} \
            {params.filtlong_temp} | gzip > {output} \
            2> {log} \
&& \
rm {params.filtlong_temp}*
        """


rule chopper:
    input:
        lambda wildcards: config["samples"][wildcards.sample]["nanopore_input"]
    output: # The unfiltered set to get QC on data directly from the nanopore sequencer, the gz_chopper to clip 80 bp from head and tail for easy removal of barcodes and filter for a min length.
        fastq_internal = temp(OUT + "/fastq/chopper/unfiltered_{sample}.fastq"), 
        gz_chopper = temp(OUT + "/gz/chopper/{sample}_min" + config["length"] + ".fastq.gz")
    conda:
        "envs/nanoplot.yaml"
    threads: config["threads"]["default"]
    resources: 
        mem_mb = config["mem_mb"]["default"],
        max_mb = config["max_mb"]["default"],
        runtime_min = config["runtime_min"]["default"]
    params:
        irods_mode = lambda wildcards: config["samples"][wildcards.sample]["iRODS_mode"], #The iRODS mode is actually true for the entire run so doesn't have to be sample specific, but it's not wrong.
        length = config["length"],
        headcrop = config["headcrop"],
        tailcrop = config["tailcrop"]
    log:
        OUT + "/log/chopper/{sample}.log"
    benchmark:
        OUT + "/log/benchmark/chopper_{sample}.txt"
    shell: # Data from iRODS is always inside a directory per isolate so it's zcat {input}/*fastq* in non irods_mode input is a single file per isolate.
        """
echo $'\n====================================\n==     PROGRAM VERSIONS USED      ==\n====================================\n' >> {log}; conda list >> {log}
if [ {params.irods_mode} == "True" ]
then
zcat -f {input}/*fastq* | chopper \
    > {output.fastq_internal}
zcat -f {input}/*fastq* | chopper \
    --quality 12 \
    --minlength {params.length} \
    --headcrop {params.headcrop} \
    --tailcrop {params.tailcrop} \
    | pigz > {output.gz_chopper}
else
zcat -f {input} | chopper \
    > {output.fastq_internal}
zcat -f {input} | chopper \
    --minlength {params.length} \
    --quality 12 \
    --headcrop {params.headcrop} \
    --tailcrop {params.tailcrop} \
    | pigz > {output.gz_chopper}
fi
        """


rule pycoqc:
    input:
        config["sequencing_summary"]
    output:
        OUT + "/pycoqc/sequencing_summary.html"
    conda:
        "envs/amr_longread.yaml"
    threads: config["threads"]["pycoqc"]
    resources: 
        mem_mb=lambda wildcards, attempt: config["mem_mb"]["pycoqc"] * attempt,
        max_mb=lambda wildcards, attempt: config["max_mb"]["pycoqc"] * attempt,
        runtime_min = config["runtime_min"]["pycoqc"]
    params:
        mockfile = OUT + "/irods_files/no_sequencing_summary.html" # touch this if non-irods mode is used.
    log:
        OUT + "/log/pycoqc/pycoqc.log"
    benchmark:
        OUT + "/log/benchmark/pycoqc.txt"
    shell:
        """
echo $'\n====================================\n==     PROGRAM VERSIONS USED      ==\n====================================\n' >> {log}; conda list >> {log}
if [ -f {params.mockfile} ]
then
    touch {output}
else
    pycoQC --summary_file {input} \
            -o {output}
fi
        """