#!/bin/bash
# ==============================================================================
# run_test.sh — Test pipeline lokal dengan sample data kecil
# ==============================================================================
# Jalankan: bash run_test.sh
# Output  : results_test/
# ==============================================================================

echo "============================================"
echo "  RAPPiN — Local Test Run"
echo "============================================"

# Bersihkan hasil lama kalau ada
rm -rf results_test work .nextflow .nextflow.log*

# Aktifkan conda
source ~/miniforge3/etc/profile.d/conda.sh
conda activate pangenome

# Jalankan test (data kecil ~760 KB di tests/test_data/)
nextflow run main.nf \
    -profile conda,test \
    --outdir results_test \
    -resume

echo "============================================"
echo "  Selesai! Output ada di: results_test/"
echo ""
echo "  Buka hasil:"
echo "    xdg-open results_test/pipeline_info/timeline.html"
echo "    xdg-open results_test/analysis/pangenome.1D.png"
echo "    xdg-open results_test/qc/EGPMv6_quast/report.txt"
echo "============================================"
