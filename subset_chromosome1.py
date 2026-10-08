#!/usr/bin/env python3
"""
subset_chromosome1.py — potong genome nyata Elaeis guineensis ke ukuran target (Mb)
untuk uji skala resource pipeline (bukan data test/dev, langsung dipakai sebagai
--input pipeline utama).

Baca chromosome 1, 2, 3, ... secara berurutan sampai total panjang mencapai target.
Untuk target kecil (<= panjang chromosome 1), hasilnya sama seperti versi lama
(cuma potongan chromosome 1). Untuk target lebih besar, otomatis lanjut ke
chromosome berikutnya (chr1+chr2+... ) sampai target tercapai atau chromosome habis.

16 chromosome per assembly (sesuai kariotipe Elaeis guineensis, 2n=32):
  EG11     -> CM002081.2 .. CM002096.2
  EGPMv6   -> GK000076.1 .. GK000091.1
  Eg-DCM   -> CBHZAK010000001.1 .. CBHZAK010000016.1

Jalankan dari root project:
    python3 subset_chromosome1.py 10
    -> tulis data_bench/10MB/{EG11,EGPMv6,Eg-DCM}.fa + samplesheet.csv

Lalu jalankan pipeline langsung (bukan profile test terpisah):
    sbatch run_hpc.sh data_bench/10MB/samplesheet.csv results_bench_10MB/
"""

import os
import sys

# 16 chromosome accession per assembly, berurutan (chr1 -> chr16)
EG11_CHRS = [f"CM0020{n}.2" for n in range(81, 97)]
EGPMV6_CHRS = [f"GK0000{n}.1" for n in range(76, 92)]
EGDCM_CHRS = [f"CBHZAK0100000{n:02d}.1" for n in range(1, 17)]

ASSEMBLIES = [
    # (sample, haplotype, cultivar, path_fna, [accession chr1..chr16 berurutan])
    (
        "EG11", "1", "Tenera",
        "data/EG11/ncbi_dataset/data/GCA_000442705.2/GCA_000442705.2_EG11_genomic.fna",
        EG11_CHRS,
    ),
    (
        "EGPMv6", "1", "AVROS",
        "data/EGPMv6/ncbi_dataset/data/GCA_015461965.1/GCA_015461965.1_EGPMv6_genomic.fna",
        EGPMV6_CHRS,
    ),
    (
        "Eg-DCM", "1", "DCM",
        "data/Eg-DCM/ncbi_dataset/data/GCA_966131455.1/GCA_966131455.1_Eg-DCM_assembly_v1_genomic.fna",
        EGDCM_CHRS,
    ),
]

OUT_ROOT = "data_bench"


def extract_chromosomes(fna_path, chr_accessions, max_bp):
    """
    Baca fna_path, ambil chromosome-chromosome di chr_accessions secara berurutan
    (chr1, chr2, ...), gabungkan sampai total max_bp basepair.
    Return: list (accession, list_baris_seq) yang sudah diambil, total bp diambil.
    """
    wanted = set(chr_accessions)
    order = {acc: i for i, acc in enumerate(chr_accessions)}

    records = []  # (accession, [seq_lines])
    bp_so_far = 0
    in_record = False
    current_acc = None
    current_lines = []

    def flush():
        nonlocal current_lines, current_acc
        if current_acc is not None and current_lines:
            records.append((current_acc, current_lines))

    with open(fna_path) as f:
        for line in f:
            line = line.rstrip("\n")
            if line.startswith(">"):
                flush()
                current_lines = []
                current_acc = None
                if bp_so_far >= max_bp:
                    break
                header_id = line[1:].split()[0]
                in_record = header_id in wanted
                current_acc = header_id if in_record else None
                continue
            if in_record:
                remaining = max_bp - bp_so_far
                if remaining <= 0:
                    continue
                chunk = line[:remaining]
                current_lines.append(chunk)
                bp_so_far += len(chunk)
        else:
            flush()

    if not records:
        raise RuntimeError(f"Tidak ada chromosome yang cocok ditemukan di {fna_path}")

    # Urutkan sesuai urutan chr1..chr16 (jaga-jaga kalau file tidak berurutan)
    records.sort(key=lambda r: order.get(r[0], 999))
    return records, bp_so_far


def main():
    if len(sys.argv) != 2:
        print("Usage: python3 subset_chromosome1.py <size_mb>")
        print("  contoh: python3 subset_chromosome1.py 10")
        print("  contoh (lebih besar dari 1 chromosome): python3 subset_chromosome1.py 350")
        sys.exit(1)

    size_arg = sys.argv[1]
    size_mb = float(size_arg)
    max_bp = int(size_mb * 1_000_000)

    out_dir = os.path.join(OUT_ROOT, f"{size_arg}MB")
    os.makedirs(out_dir, exist_ok=True)

    csv_rows = ["sample,fasta,cultivar"]

    print(f"\n{'─' * 60}")
    print(f"  Subsetting -> target {size_mb} Mb per assembly (chr1, chr2, ... berurutan)")
    print(f"{'─' * 60}\n")

    for sample, hap, cultivar, fna_path, chr_accessions in ASSEMBLIES:
        if not os.path.exists(fna_path):
            print(f"  ⚠️  SKIP {sample} — file tidak ditemukan: {fna_path}")
            continue

        records, bp_written = extract_chromosomes(fna_path, chr_accessions, max_bp)

        out_path = os.path.join(out_dir, f"{sample}.fa")
        with open(out_path, "w") as f:
            for accession, seq_lines in records:
                f.write(f">{sample}#{hap}#{accession}\n")
                f.write("\n".join(seq_lines) + "\n")

        chr_list = ", ".join(acc for acc, _ in records)
        print(f"  ✅ {sample} ({cultivar}) — {bp_written:,} bp dari {len(records)} chromosome ({chr_list}) -> {out_path}")
        csv_rows.append(f"{sample},{out_path},{cultivar}")

    csv_path = os.path.join(out_dir, "samplesheet.csv")
    with open(csv_path, "w") as f:
        f.write("\n".join(csv_rows) + "\n")

    print(f"\n{'─' * 60}")
    print(f"  ✅ Samplesheet: {csv_path}")
    print(f"\n  Jalankan pipeline:")
    print(f"  sbatch run_hpc.sh {csv_path} results_bench_{size_arg}MB/")
    print(f"{'─' * 60}\n")


if __name__ == "__main__":
    main()
