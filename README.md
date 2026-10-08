# RAPPiN

Resource-Aware Pangenome Pipeline in Nextflow. A Nextflow DSL2 pipeline that
builds and analyses a structural-variant-level pangenome graph from several
genome assemblies on a SLURM cluster, records the resource usage of every task,
and recommends core/RAM allocations for the next run.

Developed and tested on three *Elaeis guineensis* (oil palm) assemblies from
NCBI on HPC Mahameru (BRIN): EG11 (`GCA_000442705.2`, backbone), EGPMv6
(`GCA_015461965.1`) and Eg-DCM (`GCA_966131455.1`).

This repo is the source of truth for the pipeline code. Large/site-local data
(genome FASTA, Nextflow `work/`, results) is intentionally not committed.

## Pipeline

```
samplesheet.csv
  └─ SEQKIT_STATS, SEQKIT_FILTER        preprocessing (drop sequences < 500 bp)
       ├─ QUAST                         assembly quality report
       └─ MINIGRAPH → CACTUS_MINIGRAPH  structural-variant-level graph (.full.gfa, rGFA)
            └─ ODGI_STATS, ODGI_VIZ, VG_STATS   graph statistics + 1D visualisation

results/pipeline_info/trace.tsv
  └─ bin/recommend_resources.sh         --cpus-per-task / --mem for the next run
```

Every process runs as its own SLURM job, so `trace.tsv` records CPU, RAM and
run time per stage.

## Layout

```
main.nf                       entry point
nextflow.config               parameters, profiles, resource labels (effective values)
conf/hpc.config               slurm profile: executor, partition, Cactus native binary
conf/test.config              test profile: small data, reduced resources
workflows/pangenome.nf        main workflow
subworkflows/local/           validate_input, preprocessing, qc, graph_construction, graph_analysis
modules/local/                seqkit_stats, seqkit_filter, quast, minigraph, cactus_minigraph,
                              odgi (stats + viz), vg_stats
bin/recommend_resources.sh    core/RAM recommendation from trace.tsv
run_hpc.sh                    sbatch wrapper (orchestrator job: 32 cores, 64 GB, 72 h, medium-small)
run_test.sh                   quick local test with tests/test_data/
subset_chromosome1.py         builds size-limited test data from chromosomes 1-16 of each assembly
samplesheet.csv               the three E. guineensis assemblies
tests/test_data/              two small test assemblies + samplesheet
data/                         placeholder for downloaded assemblies (not committed)
```

## Requirements

- A SLURM cluster. Tested on HPC Mahameru, partition `medium-small`, student
  account (no root, at most 2 running jobs). Account registration:
  [tmelialab/HPC](https://github.com/tmelialab/HPC). External BRIN accounts
  expire every 3 months: fill in the usage report in ELSA, then email
  `hpc@brin.go.id` (subject "Aktivasi", with your username and ELSA proposal
  number) to reactivate.
- Java 21 (tested 21.0.4-tem, via SDKMAN) and Nextflow >= 23.04.0
  (tested 26.04.6) in `~/bin`.
- Conda environment `pangenome` (Miniforge in `~/miniforge3`) with
  `seqkit quast minigraph odgi vg`.
- Cactus 2.9.0 as a native binary in `~/cactus-bin-v2.9.0/venv-cactus-v2.9.0`.
  Singularity failed with `unknown userid` on some Mahameru nodes and Docker
  is not allowed, so the container is disabled for `CACTUS_MINIGRAPH`.

`run_hpc.sh` and `conf/hpc.config` read these locations; adjust both if you
install elsewhere. Install once, on the login node:

```bash
# Java 21 + Nextflow
curl -s https://get.sdkman.io | bash
source ~/.sdkman/bin/sdkman-init.sh
sdk install java 21.0.4-tem
curl -s https://get.nextflow.io | bash && mkdir -p ~/bin && mv nextflow ~/bin/

# Bioinformatics tools
curl -L -o miniforge.sh \
  https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
bash miniforge.sh -b -p ~/miniforge3 && ~/miniforge3/bin/conda init bash && source ~/.bashrc
mamba create -y -n pangenome python=3.12
conda activate pangenome
mamba install -y -c bioconda -c conda-forge seqkit quast minigraph odgi vg ncbi-datasets-cli

# Cactus 2.9.0 native binary (follows Cactus BIN-INSTALL.md)
cd ~
wget https://github.com/ComparativeGenomicsToolkit/cactus/releases/download/v2.9.0/cactus-bin-v2.9.0.tar.gz
tar -xzf cactus-bin-v2.9.0.tar.gz && cd cactus-bin-v2.9.0
virtualenv -p python3 venv-cactus-v2.9.0
printf "export PATH=$(pwd)/bin:\$PATH\nexport PYTHONPATH=$(pwd)/lib:\$PYTHONPATH\n" >> venv-cactus-v2.9.0/bin/activate
source venv-cactus-v2.9.0/bin/activate
python3 -m pip install -U setuptools pip wheel
python3 -m pip install -U .
python3 -m pip install -U -r ./toil-requirement.txt
deactivate
```

## Setup (idempotent — safe to re-run)

The code stays in the cloned repo; data, samplesheet, Nextflow `work/` and
results live in a separate working folder, so the repo folder stays clean.

```bash
# 1. Get the code (once; update later with: git -C ~/RAPPiN pull)
git clone https://github.com/tmelialab/RAPPiN.git ~/RAPPiN

# 2. Working folder
mkdir -p ~/rappin_run/data
cd ~/rappin_run

# 3. Download the assemblies (login node only; finished ones are skipped)
for x in EG11:GCA_000442705.2 EGPMv6:GCA_015461965.1 Eg-DCM:GCA_966131455.1; do
  s=${x%%:*}; acc=${x##*:}
  [ -d data/$s/ncbi_dataset ] && continue
  datasets download genome accession $acc --include genome --filename $s.zip
  unzip -o $s.zip -d data/$s && rm $s.zip
done

# 4. Samplesheet + submit script pointing at the repo
cp ~/RAPPiN/samplesheet.csv .
sed 's#nextflow run main.nf#nextflow run ~/RAPPiN/main.nf#' ~/RAPPiN/run_hpc.sh > run_hpc.sh
```

## Run order

Submit every job from the working folder so relative paths resolve:

```bash
cd ~/rappin_run
sbatch run_hpc.sh                                     # samplesheet.csv -> results/ (-resume on)
sbatch run_hpc.sh samplesheet.csv results/ noresume   # fresh run, ignore the cache
squeue -u $USER
```

Size-limited test data (target size in MB per assembly, read from
chromosome 1 onwards):

```bash
python3 ~/RAPPiN/subset_chromosome1.py 10   # -> data_bench/10MB/{EG11,EGPMv6,Eg-DCM}.fa + samplesheet.csv
sbatch run_hpc.sh data_bench/10MB/samplesheet.csv results_bench_10MB/ noresume
```

Resource recommendation from a finished run:

```bash
~/RAPPiN/bin/recommend_resources.sh results/pipeline_info/trace.tsv      # RAM margin 20%
~/RAPPiN/bin/recommend_resources.sh results/pipeline_info/trace.tsv 30   # RAM margin 30%
```

Cores = ceil(highest `%cpu` / 100); RAM = highest `peak_rss` + margin. The
output (`--cpus-per-task`, `--mem`) is meant for the heaviest task: apply it to
the `process_high` label in `nextflow.config` and raise `max_memory` if needed
(see Known issues).

Quick local test (laptop, from the repo folder; Cactus runs in Docker here):

```bash
cd ~/RAPPiN && bash run_test.sh   # -profile conda,test -> results_test/
```

## Samplesheet format

`samplesheet.csv`: CSV with header `sample,fasta,cultivar`.

- `sample`: unique name, no spaces. The backbone must equal `--reference_name`
  (default `EG11`).
- `fasta`: assembly path, relative to the working folder or absolute.
- `cultivar`: free-text label, not used by the analysis.

For another organism, use at least 2 assemblies and set `--reference_name` to
the best one (chromosome-level, highest N50). `run_hpc.sh` uses the default
reference, so add `--reference_name <sample>` to the `nextflow run` line of your
copy. If sequence names collide across assemblies (e.g. `Chr01` everywhere),
rename the headers to [PanSN-spec](https://github.com/pangenome/PanSN-spec)
(`>{sample}#1#{name}`).

## Outputs (`results/`)

```
qc/{sample}_quast/              QUAST report per assembly (report.tsv, report.txt)
graph/pangenome.full.gfa        structural-variant-level graph (rGFA)
graph/pangenome.sv.gfa          copy of pangenome.full.gfa
graph/pangenome.cactus.log      cactus-minigraph log
analysis/pangenome.stats.yaml   odgi stats: length, nodes, edges, paths, steps
analysis/pangenome.vg_stats.txt vg stats: nodes, edges
analysis/pangenome.1D.png       odgi viz 1D layout
pipeline_info/trace.tsv         CPU, RAM and time per task
pipeline_info/report.html, timeline.html, dag.html
```

## Parameters

| Parameter | Default | Notes |
|-----------|---------|-------|
| `--input` | `null` | samplesheet CSV |
| `--outdir` | `./results` | output folder |
| `--reference_name` | `EG11` | backbone sample name (required) |
| `--min_seq_len` | `500` | minimum sequence length kept by SeqKit |
| `--min_contig` | `500` | minimum contig length for QUAST |
| `--mg_preset` | `ggs` | Minigraph preset |
| `--mg_min_mapq` | `5` | Minigraph minimum mapping quality |
| `--cactus_cores` | `8` | currently has no effect (see Known issues) |
| `--max_cpus` / `--max_memory` / `--max_time` | `8` / `16.GB` / `24.h` | per-process caps; the `slurm` profile raises them to 32 / 64 GB / 72 h |

Profiles: `conda`, `slurm` (use `-profile conda,slurm` on Mahameru), `test`,
`docker`, `singularity`, `local`.

## Known issues

Found while measuring the pipeline on Mahameru; documented, not yet fixed:

1. Effective resource labels. `process_low/medium/high` are defined in both
   `conf/hpc.config` (4/8/16 cores, 8/16/32 GB) and the main `process` block of
   `nextflow.config` (2/4/8 cores, 4/8/16 GB). The `nextflow.config` block comes
   after `profiles`, so **2/4/8 cores and 4/8/16 GB apply**. Check with
   `nextflow config -profile conda,slurm`.
2. `max_memory` caps every label (64 GB in the `slurm` profile). To use a RAM
   recommendation above 64 GB (e.g. 74 GB for the full oil palm genome), raise
   `max_memory` as well.
3. The graph is built twice. `cactus-minigraph` runs Minigraph itself and does
   not use the GFA from `MINIGRAPH`, so graph construction runs twice
   (~3.3 h each for the full oil palm genome).
4. Graph level. `.full.gfa` is a structural-variant-level graph (rGFA). The
   base-level Minigraph-Cactus steps (`cactus-graphmap`, `cactus-align`,
   `cactus-graphmap-join`, or `cactus-pangenome`) are not run.
5. `--cactus_cores` is unused; `CACTUS_MINIGRAPH` takes `task.cpus` from
   `process_high`.
6. `vg ids -s` in `odgi.nf` has no effect (its output is not saved);
   `vg convert` already turns the rGFA node names into integers.
7. On Mahameru, tasks that exceeded their memory request were not killed, so a
   `COMPLETED` status does not prove an allocation is sufficient.

## Credits

Developed by Doni Arman S. (Sistem Informasi, Universitas Riau) under the
supervision of Tisha Melia, Ph.D. Tools: SeqKit (Shen et al., 2024), QUAST
(Gurevich et al., 2013), Minigraph (Li et al., 2020), Cactus/Minigraph-Cactus
(Hickey et al., 2024), ODGI (Guarracino et al., 2022), VG (Garrison et al.,
2018), Nextflow (Di Tommaso et al., 2017).
