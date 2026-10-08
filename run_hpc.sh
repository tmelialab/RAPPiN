#!/bin/bash
# ==============================================================================
# run_hpc.sh — Jalankan pipeline di HPC Mahameru BRIN (SLURM)
# ==============================================================================
# Prasyarat (semua sudah terpenuhi):
#   ✅ 1. Nextflow    → ~/bin/nextflow
#   ✅ 2. Java 21     → sdkman (~/.sdkman)
#   ✅ 3. Conda env   → ~/miniforge3/envs/pangenome
#   ✅ 4. Cactus     → ~/cactus-bin-v2.9.0/venv-cactus-v2.9.0 (native install, bukan container —
#                       Singularity gagal "unknown userid" di beberapa node, lihat README.md)
#   ✅ 5. Data genome → data/EG11/, data/EGPMv6/, data/Eg-DCM/
#
# Cara submit ke SLURM:
#   cd ~/RAPPiN
#   sbatch run_hpc.sh                                             ← run production penuh
#   sbatch run_hpc.sh data_bench/10MB/samplesheet.csv results_bench_10MB/   ← run skala resource
#   sbatch run_hpc.sh data_bench/10MB/samplesheet.csv results_bench_10MB_run2/ noresume
#                                                                  ← run ULANG tanpa -resume, buat
#                                                                    ukur variasi runtime (3x run per
#                                                                    ukuran benchmark). Tanpa "noresume"
#                                                                    di argumen ke-3, Nextflow default
#                                                                    pakai -resume dan bisa nge-skip
#                                                                    task via cache kalau hash sama.
#
# Monitor progress:
#   squeue -u $USER
#   tail -f slurm-pangenome-<JOBID>.out
# ==============================================================================

#SBATCH --job-name=pangenome-elaeis
#SBATCH --output=slurm-pangenome-%j.out
#SBATCH --error=slurm-pangenome-%j.err
#SBATCH --partition=medium-small
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=64G
#SBATCH --time=72:00:00
#SBATCH --exclude=trembesi72,trembesi68,trembesi54

echo "============================================================"
echo "  RAPPiN — HPC Mahameru Run"
echo "  Start : $(date)"
echo "  Node  : $(hostname)"
echo "  CPUs  : $SLURM_CPUS_PER_TASK"
echo "  RAM   : ${SLURM_MEM_PER_NODE:-64000} MB"
echo "============================================================"

# ── Aktifkan Java (sdkman) ──────────────────────────────────────────────────
export SDKMAN_DIR="$HOME/.sdkman"
source "$HOME/.sdkman/bin/sdkman-init.sh"

# ── Aktifkan Conda env pangenome ────────────────────────────────────────────
source ~/miniforge3/etc/profile.d/conda.sh
conda activate pangenome

# ── Tambahkan Nextflow ke PATH ──────────────────────────────────────────────
export PATH=$HOME/bin:$PATH

# ── Input/output — default ke run produksi penuh, bisa dioverride ───────────
#   sbatch run_hpc.sh <samplesheet.csv> <outdir/> [noresume]
SAMPLESHEET="${1:-samplesheet.csv}"
OUTDIR="${2:-results/}"
RESUME_MODE="${3:-resume}"

# ── Matikan -resume kalau diminta (run ulang murni buat ukur variasi runtime,
#    bukan reuse cache dari run sebelumnya) ──────────────────────────────────
RESUME_ARG="-resume"
if [ "$RESUME_MODE" = "noresume" ]; then
    RESUME_ARG=""
    echo "  Mode   : NO-RESUME (run ulang murni, cache diabaikan)"
fi

# ── Jalankan pipeline ───────────────────────────────────────────────────────
nextflow run main.nf \
    -profile conda,slurm \
    --input "$SAMPLESHEET" \
    --outdir "$OUTDIR" \
    --cactus_cores 16 \
    $RESUME_ARG \
    -with-report "${OUTDIR}/pipeline_info/report.html" \
    -with-timeline "${OUTDIR}/pipeline_info/timeline.html" \
    -with-trace "${OUTDIR}/pipeline_info/trace.tsv"

echo "============================================================"
echo "  Selesai: $(date)"
echo "  Hasil  : ${OUTDIR}"
echo "  Log    : slurm-pangenome-${SLURM_JOB_ID}.out"
echo "============================================================"

