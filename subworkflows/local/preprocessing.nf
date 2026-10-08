/*
========================================================================================
    SUBWORKFLOW: PREPROCESSING
    Filter sekuens, validasi header format PanSN-spec
========================================================================================
*/

include { SEQKIT_STATS  } from '../../modules/local/preprocessing/seqkit_stats'
include { SEQKIT_FILTER } from '../../modules/local/preprocessing/seqkit_filter'

workflow PREPROCESSING {

    take:
    ch_fasta  // [ meta, fasta ]

    main:

    // Hitung statistik sebelum filter
    SEQKIT_STATS(ch_fasta)

    // Filter sekuens terlalu pendek
    SEQKIT_FILTER(ch_fasta)

    emit:
    fasta = SEQKIT_FILTER.out.fasta   // [ meta, fasta_clean ]
    stats = SEQKIT_STATS.out.tsv
}
