/*
========================================================================================
    SUBWORKFLOW: QC
    Jalankan QUAST pada semua assembly untuk menentukan kualitas
    dan backbone referensi terbaik (N50 tertinggi, chromosome-level)
========================================================================================
*/

include { QUAST } from '../../modules/local/qc/quast'

workflow QC {

    take:
    ch_fasta   // [ meta, fasta ]

    main:

    // Jalankan QUAST per assembly
    QUAST(ch_fasta)

    // Kumpulkan semua report TSV untuk ringkasan
    ch_reports = QUAST.out.tsv.collect { meta, tsv -> tsv }

    emit:
    report_dir = QUAST.out.report_dir   // [ meta, report_dir ]
    tsv        = QUAST.out.tsv          // [ meta, report.tsv ]
    all_tsv    = ch_reports             // [ tsv, tsv, ... ] untuk MultiQC
}
