rule prepare_fastq:
	input:
		forward = get_raw_f_fastqs,
		reverse = get_raw_r_fastqs
	output:
		forward = "results/{sample}/Illumina/raw_reads/from_fastq/{lib}/{sample}.{lib}.raw.1.fastq.gz",
		reverse = "results/{sample}/Illumina/raw_reads/from_fastq/{lib}/{sample}.{lib}.raw.2.fastq.gz"
	shell:
		"""
		ln -s {input.forward} {output.forward}
		ln -s {input.reverse} {output.reverse}
		"""
rule sort_bam:
	input:
		get_bam
	output:
		ok = "results/{sample}/Illumina/raw_reads/from_bam/{lib}/{sample}.{lib}.sorting.ok",
	log:
		stdout = "results/{sample}/logs/sort_bam.{lib}.stdout.txt",
		stderr = "results/{sample}/logs/sort_bam.{lib}.stderr.txt"
	params:
		wd = os.getcwd(),
		sample = "{sample}",
		lib = "{lib}",
		targetdir = "results/{sample}/Illumina/raw_reads/from_bam/{lib}/"
	threads: config["threads"]["samtools"]
	singularity: "docker://reslp/samtools:1.11"
	shadow: "minimal"
	shell:
		"""
		samtools sort -@ $(( {threads} - 1 )) -m 2G -n {input} -o {params.sample}.{params.lib}.sorted.bam 1> {log.stdout} 2> {log.stderr}
		mv *.bam {params.wd}/{params.targetdir}
		touch {output.ok}
		"""
rule bam2fastq:
	input:
		rules.sort_bam.output
	output:
		forward = "results/{sample}/Illumina/raw_reads/from_bam/{lib}/{sample}.{lib}.raw.1.fastq.gz",
		reverse = "results/{sample}/Illumina/raw_reads/from_bam/{lib}/{sample}.{lib}.raw.2.fastq.gz"
	log:
		stdout = "results/{sample}/logs/bam2fastq.{lib}.stdout.txt",
		stderr = "results/{sample}/logs/bam2fastq.{lib}.stderr.txt"
	params:
		wd = os.getcwd(),
		sample = "{sample}",
		lib = "{lib}",
		targetdir = "results/{sample}/Illumina/raw_reads/from_bam/{lib}/"
	threads: 2
	singularity: "docker://reslp/bedtools:2.29.2"
	shadow: "minimal"
	shell:
		"""
		bedtools bamtofastq -i {params.wd}/{params.targetdir}/{params.sample}.{params.lib}.sorted.bam -fq {params.targetdir}/{params.sample}.{params.lib}.raw.1.fastq -fq2 {params.targetdir}/{params.sample}.{params.lib}.raw.2.fastq 1> {log.stdout} 2> {log.stderr}
		gzip -v {params.targetdir}*.fastq 1>> {log.stdout} 2>> {log.stderr}
		rm {params.wd}/{params.targetdir}/*.bam
		"""		


rule trim_trimgalore:
	input:
		forward = input_for_trimgalore_f,
		reverse = input_for_trimgalore_r,
	params:
		wd = os.getcwd(),
		lib = "{lib}",
		sample = "{sample}",
#		adapters = "--illumina"
	singularity:
		"docker://chrishah/trim_galore:0.6.0"
	log:
		stdout = "results/{sample}/logs/trimgalore.{lib}.stdout.txt",
		stderr = "results/{sample}/logs/trimgalore.{lib}.stderr.txt"
	output:
		ok = "results/{sample}/trimming/trim_galore/{lib}/{sample}.{lib}.status.ok",
		f_trimmed = "results/{sample}/trimming/trim_galore/{lib}/{sample}.{lib}.1.fastq.gz",
		r_trimmed = "results/{sample}/trimming/trim_galore/{lib}/{sample}.{lib}.2.fastq.gz",
		f_orphans = "results/{sample}/trimming/trim_galore/{lib}/{sample}.{lib}.unpaired.1.fastq.gz",
		r_orphans = "results/{sample}/trimming/trim_galore/{lib}/{sample}.{lib}.unpaired.2.fastq.gz"
	shadow: "minimal"
	threads: 4
	shell:
		"""
		trim_galore \
		--paired --length 70 -r1 71 -r2 71 --retain_unpaired --stringency 2 --quality 30 \
		{input.forward} {input.reverse} 1> {log.stdout} 2> {log.stderr}

		mv $(find ./ -name "*_val_1.fq.gz") {output.f_trimmed}
		mv $(find ./ -name "*_val_2.fq.gz") {output.r_trimmed}
	
		if [[ -f $(find ./ -name "*_unpaired_1.fq.gz") ]]; then mv $(find ./ -name "*_unpaired_1.fq.gz") {output.f_orphans}; else touch {output.f_orphans}; fi
		if [[ -f $(find ./ -name "*_unpaired_2.fq.gz") ]]; then mv $(find ./ -name "*_unpaired_2.fq.gz") {output.r_orphans}; else touch {output.r_orphans}; fi

		touch {output.ok}

		"""

rule fastqc_raw:
	input:
		forward = input_for_trimgalore_f,
		reverse = input_for_trimgalore_r,
	params:
		wd = os.getcwd(),
		lib = "{lib}",
		sample = "{sample}",
	singularity:
		"docker://chrishah/trim_galore:0.6.0"
	log:
		stdout = "results/{sample}/logs/fastqc_raw.{sample}.{lib}.stdout.txt",
		stderr = "results/{sample}/logs/fastqc_raw.{sample}.{lib}.stderr.txt"
	output:
		ok = "results/{sample}/read_qc/fastqc_raw/{lib}/{sample}.{lib}.status.ok",
	shadow: "minimal"
	threads: 2
	shell:
		"""
		fastqc -o ./ {input} 1> {log.stdout} 2> {log.stderr}
		mv *.zip *.html {params.wd}/results/{params.sample}/read_qc/fastqc_raw/{params.lib}/
		touch {output}
		"""

rule fastqc_trimmed:
	input:
		f_paired = input_for_clean_trim_fp,
		r_paired = input_for_clean_trim_rp,
		f_unpaired = input_for_clean_trim_fo,
		r_unpaired = input_for_clean_trim_ro
	params:
		wd = os.getcwd(),
		lib = "{lib}",
		sample = "{sample}",
	singularity:
		"docker://chrishah/trim_galore:0.6.0"
	log:
		stdout = "results/{sample}/logs/fastqc_trim_galore.{sample}.{lib}.stdout.txt",
		stderr = "results/{sample}/logs/fastqc_trim_galore.{sample}.{lib}.stderr.txt"
	output:
		ok = "results/{sample}/trimming/trim_galore/{lib}/{sample}.{lib}.fastqc.status.ok",
	shadow: "minimal"
	threads: 2
	shell:
		"""
		fastqc -o ./ {input} 1> {log.stdout} 2> {log.stderr}
		mv *.zip *.html {params.wd}/results/{params.sample}/trimming/trim_galore/{params.lib}/
		touch {output}
		
		"""
rule stats:
	input:
		lambda wildcards: expand(rules.fastqc_trimmed.output.ok, sample=wildcards.sample, lib=unitdict[wildcards.sample])
	singularity:
		"docker://chrishah/r-docker:latest"
	log:
		stdout = "results/{sample}/logs/readstats.{sample}.stdout.txt",
		stderr = "results/{sample}/logs/readstats.{sample}.stderr.txt"
	output: 
		stats = "results/{sample}/trimming/trim_galore/{sample}.readstats.txt"
	threads: 2
	shadow: "shallow"
	shell:
		"""
		echo -e "$(date)\tGetting read stats" 1> {log.stdout}
		bin/get_readstats_from_fastqc.sh $(echo {input} | sed 's/ /,/g' | sed 's/.fastqc.status.ok//g') 1> {output.stats} 2> {log.stderr}
		stats=$(cat {output.stats})
		echo -e "Cummulative length: $(cat {output.stats} | cut -d " " -f 1)" 1>> {log.stdout} 2>> {log.stderr}
		echo -e "Average read length: $(cat {output.stats} | cut -d " " -f 2)\\n" 1>> {log.stdout} 2>> {log.stderr}
		echo -e "$(date)\tDone!" 1>> {log.stdout}
		"""
rule kmc:
	input:
		f_paired = lambda wildcards: expand("results/{{sample}}/trimming/trim_galore/{lib}/{{sample}}.{lib}.1.fastq.gz", sample=wildcards.sample, lib=unitdict[wildcards.sample]),
		r_paired = lambda wildcards: expand("results/{{sample}}/trimming/trim_galore/{lib}/{{sample}}.{lib}.2.fastq.gz", sample=wildcards.sample, lib=unitdict[wildcards.sample]),
		f_unpaired = lambda wildcards: expand("results/{{sample}}/trimming/trim_galore/{lib}/{{sample}}.{lib}.unpaired.1.fastq.gz", sample=wildcards.sample, lib=unitdict[wildcards.sample]),
		r_unpaired = lambda wildcards: expand("results/{{sample}}/trimming/trim_galore/{lib}/{{sample}}.{lib}.unpaired.2.fastq.gz", sample=wildcards.sample, lib=unitdict[wildcards.sample]),
	params:
		sample = "{sample}",
		k = "{k}",
		max_mem_in_GB = config["kmc"]["max_mem_in_GB"],
		mincount = config["kmc"]["mincount"],
		maxcount = config["kmc"]["maxcount"],
		maxcounter = config["kmc"]["maxcounter"],
		nbin = 64,
	threads: config["threads"]["kmc"]
	singularity:
		"docker://chrishah/kmc3-docker:v3.0"
	log:
		stdout = "results/{sample}/logs/kmc.{sample}.k{k}.stdout.txt",
		stderr = "results/{sample}/logs/kmc.{sample}.k{k}.stderr.txt"
	output: 
#		pre = "results/{sample}/kmc/{sample}.k{k}.kmc_pre",
#		suf = "results/{sample}/kmc/{sample}.k{k}.kmc_suf",
		hist = "results/{sample}/kmc/{sample}.k{k}.histogram.txt",
	shadow: "shallow"
	shell:
		"""
		echo -e "$(date)\tStarting kmc"
		echo "{input}" | sed 's/ /\\n/g' > fastqs.txt
		mkdir {params.sample}.db
		kmc -k{params.k} -m$(( {params.max_mem_in_GB} - 2 )) -v -sm -ci{params.mincount} -cx{params.maxcount} -cs{params.maxcounter} -n{params.nbin} -t$(( {threads} - 1 )) @fastqs.txt {params.sample} {params.sample}.db 1>> {log.stdout} 2>> {log.stderr}
		#kmc_tools histogram {params.sample} -ci{params.mincount} -cx{params.maxcount} {output.hist}
		kmc_tools histogram {params.sample} -ci{params.mincount} {output.hist} 1> /dev/null 2>> {log.stderr}
		"""

rule reformat_read_headers:
	input:
		"results/{sample}/trimming/trim_galore/{lib}/{sample}.{lib}.{pe}.fastq.gz"
	log:
		stdout = "results/{sample}/logs/reformat.{lib}.{pe}.stdout.txt",
		stderr = "results/{sample}/logs/reformat.{lib}.{pe}.stderr.txt"
	params:
		pe = "{pe}"
	threads: 2
	output:
		read = "results/{sample}/errorcorrection/bless/{lib}/{lib}.{pe}.fastq.gz",
		ok = "results/{sample}/errorcorrection/bless/{lib}/headerformat.{lib}.{pe}.ok"
	shell:
		"""
		#check if the read headers contain space - if yes reformat
		if [ "$(zcat {input} | head -n 1 | grep " " | wc -l)" -gt 0 ]
		then
			zcat {input} | sed 's/ {params.pe}.*/\/{params.pe}/' | gzip > {output.read} 
		else
			ln -s $(pwd)/{input} $(pwd)/{output.read}
		fi
		touch {output.ok}
		"""

rule ec_blessfindk:
	input:
		f_paired = lambda wildcards: expand("results/{{sample}}/trimming/trim_galore/{lib}/{{sample}}.{lib}.1.fastq.gz", sample=wildcards.sample, lib=unitdict[wildcards.sample]),
		r_paired = lambda wildcards: expand("results/{{sample}}/trimming/trim_galore/{lib}/{{sample}}.{lib}.2.fastq.gz", sample=wildcards.sample, lib=unitdict[wildcards.sample]),
		f_unpaired = lambda wildcards: expand("results/{{sample}}/trimming/trim_galore/{lib}/{{sample}}.{lib}.unpaired.1.fastq.gz", sample=wildcards.sample, lib=unitdict[wildcards.sample]),
		r_unpaired = lambda wildcards: expand("results/{{sample}}/trimming/trim_galore/{lib}/{{sample}}.{lib}.unpaired.2.fastq.gz", sample=wildcards.sample, lib=unitdict[wildcards.sample]),
	params:
		wd = os.getcwd(),
		max_mem_in_GB = config["kmc"]["max_mem_in_GB"],
		startk = config["blessfindk"]["startk"],
		script = "bin/bless_iterate_over_ks.sh",
		sample = "{sample}"
	threads: config["threads"]["ec_blessfindk"]
	singularity:
		"docker://chrishah/bless:v1.02"
	log:
		stdout = "results/{sample}/logs/blessfindk.{sample}.stdout.txt",
		stderr = "results/{sample}/logs/blessfindk.{sample}.stderr.txt"
	output:
		"results/{sample}/errorcorrection/bless/{sample}.bestk"
	shell:
		"""

		cd results/{params.sample}/errorcorrection/bless

		for f in {input.f_paired} {input.r_paired} {input.f_unpaired} {input.r_unpaired}; do cat {params.wd}/$f; done > seqs.fastq.gz
		#cat {params.wd}/{input.f_paired} {params.wd}/{input.r_paired} {params.wd}/{input.f_unpaired} {params.wd}/{input.r_unpaired} > seqs.fastq.gz

		bash {params.wd}/{params.script} \
			seqs.fastq.gz \
			{params.sample} \
			{params.startk} \
			$(( {params.max_mem_in_GB} - 2 )) \
			$(( {threads} - 1 )) \
			clean \
			1> {params.wd}/{log.stdout} 2> {params.wd}/{log.stderr}

		rm seqs.fastq.gz

		"""

rule ec_blesspe:
	input:
		bestk = rules.ec_blessfindk.output,
                forward = lambda wildcards: "results/{sample}/errorcorrection/bless/{lib}/{lib}.1.fastq.gz",
                reverse = lambda wildcards: "results/{sample}/errorcorrection/bless/{lib}/{lib}.2.fastq.gz",
	params:
		wd = os.getcwd(),
		sampleID = "{sample}",
		lib = "{lib}",
		max_mem_in_GB = config["kmc"]["max_mem_in_GB"]
	threads: config["threads"]["ec_blesspe"]
	singularity:
		"docker://chrishah/bless:v1.02"
	log:
		stdout = "results/{sample}/logs/blesspe.{sample}.{lib}.stdout.txt",
		stderr = "results/{sample}/logs/blesspe.{sample}.{lib}.stderr.txt"
	output:
		cf = "results/{sample}/errorcorrection/bless/{lib}/{sample}.{lib}.1.corrected.fastq.gz",
		cr = "results/{sample}/errorcorrection/bless/{lib}/{sample}.{lib}.2.corrected.fastq.gz"
	shell:
		"""
		k=$(cat {input.bestk})
		#echo -e "BEST k is: $k"
		cd results/{params.sampleID}/errorcorrection/bless/{params.lib}

		bless -read1 {params.wd}/{input.forward} -read2 {params.wd}/{input.reverse} -kmerlength $k -smpthread $(( {threads} - 1 )) -max_mem $(( {params.max_mem_in_GB} - 2 )) -load ../{params.sampleID}-k$k -notrim -prefix {params.sampleID}.{params.lib} -gzip 1> {params.wd}/{log.stdout} 2> {params.wd}/{log.stderr}

		"""

rule ec_blessse:
	input:
		bestk = rules.ec_blessfindk.output,
		reads1 = lambda wildcards: "results/{sample}/trimming/trim_galore/{lib}/{sample}.{lib}.unpaired.1.fastq.gz",
		reads2 = lambda wildcards: "results/{sample}/trimming/trim_galore/{lib}/{sample}.{lib}.unpaired.2.fastq.gz",
#		reads1 = rules.trim_trimgalore.output.f_orphans,
#		reads2 = rules.trim_trimgalore.output.r_orphans
	params:
		wd = os.getcwd(),
		sampleID = "{sample}",
		lib = "{lib}",
		max_mem_in_GB = "10",
		dir = "results/{sample}/errorcorrection/bless/{lib}"
	threads: config["threads"]["ec_blessse"]
	singularity:
		"docker://chrishah/bless:v1.02"
	log:
		stdout = "results/{sample}/logs/blessse.{sample}.{lib}.stdout.txt",
		stderr = "results/{sample}/logs/blessse.{sample}.{lib}.stderr.txt"
	output:
		"results/{sample}/errorcorrection/bless/{lib}/{sample}.{lib}.se.corrected.fastq.gz",
	shell:
		"""
		k=$(cat {input.bestk})
		#echo -e "BEST k is: $k"
		cd {params.dir}

		cat {params.wd}/{input.bestk} \
		<(zcat {params.wd}/{input.reads1} | sed 's/ 1.*/\/1/') \
		<(zcat {params.wd}/{input.reads2} | sed 's/ 2.*/\/2/') | perl -ne 'chomp; if ($.==1){{$k=$_}}else{{$h=$_; $s=<>; $p=<>; $q=<>; if (length($s) > $k){{print "$h\\n$s$p$q"}}}}' > {params.lib}.se.fastq

		bless -read {params.lib}.se.fastq -kmerlength $k -smpthread $(( {threads} - 1 )) -max_mem $(( {params.max_mem_in_GB} - 2 )) -load ../{params.sampleID}-k$k -notrim -prefix {params.sampleID}.{params.lib} -gzip 1> {params.wd}/{log.stdout} 2> {params.wd}/{log.stderr}

		rm {params.lib}.se.fastq
		ln -s $(pwd)/{params.sampleID}.{params.lib}.corrected.fastq.gz {params.wd}/{output}
		"""
rule plot_k_hist:
	input:
		hist = rules.kmc.output.hist,
		stats = rules.stats.output.stats
	output:
		full = "results/{sample}/plots/{sample}-k{k}-distribution-full.pdf",		
	params:
		sample = "{sample}",
		k = "{k}",
		script = "bin/plot.freq.in.R"
	singularity:
		"docker://chrishah/r-docker:latest"
	log:
		stdout = "results/{sample}/logs/plotkmerhist.{sample}.k{k}.stdout.txt",
		stderr = "results/{sample}/logs/plotkmerhist.{sample}.k{k}.stderr.txt"
	shadow: "shallow"
	shell:
		"""
		stats=$(cat {input.stats})
		echo -e "Cummulative length: $(echo -e "$stats" | cut -d " " -f 1)"
		echo -e "Average read length: $(echo -e "$stats" | cut -d " " -f 2)"
		Rscript {params.script} {input.hist} {params.sample} {params.k} $stats 1> {log.stdout} 2> {log.stderr}
		cp {params.sample}-k{params.k}-distribution* results/{params.sample}/plots/
		"""

rule clean_trimmed_libs:
	input:
#		forward = lambda wildcards: expand("results/{{sample}}/trimming/trim_galore/{lib}/{{sample}}.{lib}.1.fastq.gz", sample=wildcards.sample, lib=unitdict[wildcards.sample]),
#		reverse = lambda wildcards: expand("results/{{sample}}/trimming/trim_galore/{lib}/{{sample}}.{lib}.2.fastq.gz", sample=wildcards.sample, lib=unitdict[wildcards.sample]),
#		forward_orphans = lambda wildcards: expand("results/{{sample}}/trimming/trim_galore/{lib}/{{sample}}.{lib}.unpaired.1.fastq.gz", sample=wildcards.sample, lib=unitdict[wildcards.sample]),
#		reverse_orphans = lambda wildcards: expand("results/{{sample}}/trimming/trim_galore/{lib}/{{sample}}.{lib}.unpaired.2.fastq.gz", sample=wildcards.sample, lib=unitdict[wildcards.sample]),
#		forward = lambda wildcards: expand("results/{{test.sample}}/trimming/trim_galore/{test.lib}/{{test.sample}}.{test.lib}.1.fastq.gz", test=illumina_units.itertuples()),
#		reverse = lambda wildcards: expand("results/{{test.sample}}/trimming/trim_galore/{test.lib}/{{test.sample}}.{test.lib}.2.fastq.gz", test=illumina_units.itertuples()),
#		forward_orphans = lambda wildcards: expand("results/{{test.sample}}/trimming/trim_galore/{test.lib}/{{test.sample}}.{test.lib}.unpaired.1.fastq.gz", test=illumina_units.itertuples()),
#		reverse_orphans = lambda wildcards: expand("results/{{test.sample}}/trimming/trim_galore/{test.lib}/{{test.sample}}.{test.lib}.unpaired.2.fastq.gz", test=illumina_units.itertuples()),
		forward = input_for_clean_trim_fp,
		reverse = input_for_clean_trim_rp,
		forward_orphans = input_for_clean_trim_fo,
		reverse_orphans = input_for_clean_trim_ro
	params:
		wd = os.getcwd(),
		sample = "{sample}",
	singularity:
		"docker://chrishah/trim_galore:0.6.0"
	output:
		ok = "results/{sample}/trimming/trim_galore/{sample}-full/{sample}.cat.status.ok",
		f_trimmed = "results/{sample}/trimming/trim_galore/{sample}-full/{sample}.trimgalore.1.fastq.gz",
		r_trimmed = "results/{sample}/trimming/trim_galore/{sample}-full/{sample}.trimgalore.2.fastq.gz",
		orphans = "results/{sample}/trimming/trim_galore/{sample}-full/{sample}.trimgalore.se.fastq.gz",
	shadow: "minimal"
	threads: 2
	shell:
		"""
		if [ $(echo {input.forward} | wc -w) -gt 1 ]
		then
			cat {input.forward} > {output.f_trimmed}
			cat {input.reverse} > {output.r_trimmed}
		else
			ln -s ../../../../../{input.forward} {output.f_trimmed}
			ln -s ../../../../../{input.reverse} {output.r_trimmed}
		fi
		cat {input.forward_orphans} {input.reverse_orphans} > {output.orphans}
		touch {output.ok}
		"""

rule clean_corrected_libs:
	input:
		forward = lambda wildcards: expand("results/{{sample}}/errorcorrection/bless/{lib}/{{sample}}.{lib}.1.corrected.fastq.gz", sample=wildcards.sample, lib=unitdict[wildcards.sample]),
		reverse = lambda wildcards: expand("results/{{sample}}/errorcorrection/bless/{lib}/{{sample}}.{lib}.2.corrected.fastq.gz", sample=wildcards.sample, lib=unitdict[wildcards.sample]),
		orphans = lambda wildcards: expand("results/{{sample}}/errorcorrection/bless/{lib}/{{sample}}.{lib}.se.corrected.fastq.gz", sample=wildcards.sample, lib=unitdict[wildcards.sample]),
	params:
		wd = os.getcwd(),
		sample = "{sample}",
	singularity:
		"docker://chrishah/trim_galore:0.6.0"
	output:
		ok = "results/{sample}/errorcorrection/bless/{sample}-full/{sample}.cat.status.ok",
		f = "results/{sample}/errorcorrection/bless/{sample}-full/{sample}.blesscorrected.1.fastq.gz",
		r = "results/{sample}/errorcorrection/bless/{sample}-full/{sample}.blesscorrected.2.fastq.gz",
		o = "results/{sample}/errorcorrection/bless/{sample}-full/{sample}.blesscorrected.se.fastq.gz"
	shadow: "minimal"
	threads: 2
	shell:
		"""
		if [ $(echo {input.forward} | wc -w) -gt 1 ]
		then
			cat {input.forward} > {output.f}
			cat {input.reverse} > {output.r}
		else
			ln -s ../../../../../{input.forward} {output.f}
			ln -s ../../../../../{input.reverse} {output.r}
		fi
		cat {input.orphans} > {output.o}
		touch {output.ok}
		"""

rule clean_merged_libs:
	input:
		merged = lambda wildcards: expand("results/{{sample}}/readmerging/usearch/{lib}/{{sample}}.{lib}.merged.fastq.gz", sample=wildcards.sample, lib=unitdict[wildcards.sample]),
		forward = lambda wildcards: expand("results/{{sample}}/readmerging/usearch/{lib}/{{sample}}.{lib}_1.nm.fastq.gz", sample=wildcards.sample, lib=unitdict[wildcards.sample]),
		reverse = lambda wildcards: expand("results/{{sample}}/readmerging/usearch/{lib}/{{sample}}.{lib}_2.nm.fastq.gz", sample=wildcards.sample, lib=unitdict[wildcards.sample]),
	params:
		wd = os.getcwd(),
		sample = "{sample}",
	singularity:
		"docker://chrishah/trim_galore:0.6.0"
	output:
		ok = "results/{sample}/readmerging/usearch/{sample}-full/{sample}.cat.status.ok",
		m = "results/{sample}/readmerging/usearch/{sample}-full/{sample}.usearchmerged.fastq.gz",
		f = "results/{sample}/readmerging/usearch/{sample}-full/{sample}.usearchnotmerged.1.fastq.gz",
		r = "results/{sample}/readmerging/usearch/{sample}-full/{sample}.usearchnotmerged.2.fastq.gz",
	shadow: "minimal"
	threads: 2
	shell:
		"""
		if [ $(echo {input.merged} | wc -w) -gt 1 ]
		then
			cat {input.merged} > {output.m}
			cat {input.forward} > {output.f}
			cat {input.reverse} > {output.r}
		else
			ln -s ../../../../../{input.merged} {output.m}
			ln -s ../../../../../{input.forward} {output.f}
			ln -s ../../../../../{input.reverse} {output.r}
		fi
		touch {output.ok}
		"""

#rule merge_libs_merged:
#rule filter_by_kmer_coverage:
#	input:
#	params:
#		sample = "{sample}",
#		k = "{k}",
#		max_mem_in_GB = config["kmc"]["max_mem_in_GB"],
#		mincount = config["kmc"]["mincount"],
#		maxcount = config["kmc"]["maxcount"],
#		maxcounter = config["kmc"]["maxcounter"],
#		nbin = 64,
#	threads: config["threads"]["kmc"]
#	singularity:
#		"docker://chrishah/kmc3-docker:v3.0"
#	log:
#		stdout = "results/{sample}/logs/kmc.{sample}.k{k}.stdout.txt",
#		stderr = "results/{sample}/logs/kmc.{sample}.k{k}.stderr.txt"
#	output: 
##		pre = "results/{sample}/kmc/{sample}.k{k}.kmc_pre",
##		suf = "results/{sample}/kmc/{sample}.k{k}.kmc_suf",
#		hist = "results/{sample}/kmc/{sample}.k{k}.histogram.txt",
#	shadow: "shallow"
#	shell:
#		"""
#		echo "{input}" | sed 's/ /\\n/g' > fastqs.txt
#		kmc_tools filter $db_prefix -ci$min_kmer_cov -cx$max_kmer_cov @fastqs.txt -ci$min_perc_kmers -cx$max_perc_kmers {output.fastq}
#		"""
#rule merge_k_hists:
#pdftk $(ls -1 $s-* | grep "\-full.pdf" | tr '\n' ' ') cat output $s.distribution.full.pdf
#pdftk $(ls -1 $s-* | grep -v "\-full.pdf" | tr '\n' ' ') cat output $s.distribution.pdf
