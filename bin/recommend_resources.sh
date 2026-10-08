#!/usr/bin/env bash
# =============================================================================
# recommend_resources.sh
# =============================================================================
# Baca trace.tsv hasil satu run pipeline (nextflow -with-trace), lalu
# merekomendasikan jumlah CPU core dan RAM yang sebaiknya dialokasikan untuk
# run berikutnya, berdasarkan peak %CPU dan peak RSS aktual yang terpakai.
#
# Latar belakang: run produksi nyata (full genome) sejauh ini selalu
# dialokasikan 32 core / 64GB RAM, padahal peak pemakaian sebenarnya jauh
# di bawah itu (misal ~7 core efektif, ~61GB RAM). Script ini menghitung
# rekomendasi dari data aktual, bukan tebakan.
#
# Penggunaan:
#   bin/recommend_resources.sh <trace.tsv> [margin_ram_persen]
#
# Contoh:
#   bin/recommend_resources.sh results/pipeline_info/trace.tsv
#   bin/recommend_resources.sh results/pipeline_info/trace.tsv 20
#
# Output:
#   Rekomendasi core CPU (dibulatkan ke atas dari peak %CPU tertinggi/100)
#   dan RAM (peak RSS tertinggi + margin keamanan, default 20%).
# =============================================================================

set -euo pipefail

TRACE_TSV="${1:?Usage: $0 <trace.tsv> [margin_ram_persen]}"
MARGIN_PCT="${2:-20}"

if [ ! -f "$TRACE_TSV" ]; then
    echo "ERROR: file tidak ditemukan: $TRACE_TSV" >&2
    exit 1
fi

echo "=============================================="
echo "  Rekomendasi Resource — RAPPiN"
echo "=============================================="
echo "  Sumber data : ${TRACE_TSV}"
echo "  Margin RAM  : +${MARGIN_PCT}%"
echo "----------------------------------------------"

# ── Ambil kolom name, %cpu, peak_rss dari header (urutan kolom trace.tsv
#    Nextflow bisa beda tergantung versi/config, jadi dicari by name) ────────
HEADER=$(head -n1 "$TRACE_TSV")
NAME_COL=$(echo "$HEADER" | tr '\t' '\n' | grep -nx "name" | cut -d: -f1)
CPU_COL=$(echo "$HEADER" | tr '\t' '\n' | grep -nx "%cpu" | cut -d: -f1)
RSS_COL=$(echo "$HEADER" | tr '\t' '\n' | grep -nx "peak_rss" | cut -d: -f1)

if [ -z "$NAME_COL" ] || [ -z "$CPU_COL" ] || [ -z "$RSS_COL" ]; then
    echo "ERROR: kolom 'name', '%cpu', atau 'peak_rss' tidak ditemukan di header." >&2
    exit 1
fi

# ── Cari task dengan %cpu tertinggi dan peak_rss tertinggi ──────────────────
RESULT=$(tail -n +2 "$TRACE_TSV" | awk -F'\t' -v name_col="$NAME_COL" -v cpu_col="$CPU_COL" -v rss_col="$RSS_COL" '
function to_gb(val,   num, unit) {
    if (val == "-" || val == "") return 0
    num = val + 0
    unit = val
    gsub(/^[0-9.]+[ \t]*/, "", unit)
    if (unit ~ /^TB/) return num * 1024
    if (unit ~ /^GB/) return num
    if (unit ~ /^MB/) return num / 1024
    if (unit ~ /^KB/) return num / 1024 / 1024
    return num / 1024 / 1024 / 1024   # asumsi Byte polos
}
{
    cpu = $(cpu_col) + 0
    rss_gb = to_gb($(rss_col))
    if (cpu > max_cpu) { max_cpu = cpu; max_cpu_task = $(name_col) }
    if (rss_gb > max_rss) { max_rss = rss_gb; max_rss_task = $(name_col) }
}
END {
    printf "%.1f|%s|%.2f|%s", max_cpu, max_cpu_task, max_rss, max_rss_task
}
')

MAX_CPU=$(echo "$RESULT" | cut -d'|' -f1)
MAX_CPU_TASK=$(echo "$RESULT" | cut -d'|' -f2)
MAX_RSS=$(echo "$RESULT" | cut -d'|' -f3)
MAX_RSS_TASK=$(echo "$RESULT" | cut -d'|' -f4)

# ── Hitung rekomendasi ───────────────────────────────────────────────────────
# Core: bulatkan ke atas dari (peak %CPU / 100), minimum 1
REC_CORES=$(awk -v c="$MAX_CPU" 'BEGIN { v = c / 100; r = int(v); if (v > r) r += 1; if (r < 1) r = 1; print r }')

# RAM: peak RSS + margin keamanan, dibulatkan ke atas ke GB terdekat, minimum 1
REC_RAM_GB=$(awk -v rss="$MAX_RSS" -v margin="$MARGIN_PCT" 'BEGIN {
    v = rss * (1 + margin / 100)
    r = int(v)
    if (v > r) r += 1
    if (r < 1) r = 1
    print r
}')

echo "  Peak %CPU tertinggi : ${MAX_CPU}% (task: ${MAX_CPU_TASK})"
echo "  Peak RAM tertinggi  : ${MAX_RSS} GB (task: ${MAX_RSS_TASK})"
echo "----------------------------------------------"
echo "  REKOMENDASI untuk run berikutnya:"
echo "    --cpus-per-task=${REC_CORES}"
echo "    --mem=${REC_RAM_GB}G"
echo "=============================================="
