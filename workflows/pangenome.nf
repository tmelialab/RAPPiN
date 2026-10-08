/*
========================================================================================
    WORKFLOW: PANGENOME — RAPPiN
    Deskripsi: Workflow utama (konstruksi graf SV dengan Minigraph; Hickey et al. 2024)

    Alur:
      Input FASTA → Preprocessing → QC (QUAST) → Konstruksi Graf (Minigraph)
      → Analisis Graph (odgi/vg)
========================================================================================
*/

include { VALIDATE_INPUT     } from '../subworkflows/local/validate_input'
include { PREPROCESSING      } from '../subworkflows/local/preprocessing'
include { QC                 } from '../subworkflows/local/qc'
include { GRAPH_CONSTRUCTION } from '../subworkflows/local/graph_construction'
include { GRAPH_ANALYSIS     } from '../subworkflows/local/graph_analysis'

workflow PANGENOME_WORKFLOW {

    main:

    // ── Step 0: Validasi & parsing input ─────────────────────────────────────
    VALIDATE_INPUT()
    ch_fasta = VALIDATE_INPUT.out.fasta   // [ meta, fasta ]

    // ── Step 1: Preprocessing — filter sekuens pendek, validasi format ────────
    PREPROCESSING(ch_fasta)
    ch_clean = PREPROCESSING.out.fasta    // [ meta, fasta_clean ]

    // ── Step 2: QC — QUAST per assembly → pilih backbone referensi ────────────
    QC(ch_clean)

    // ── Step 3: Konstruksi Pangenome Graph (Minigraph-Cactus) ─────────────────
    //   minigraph (SV-level) → cactus-minigraph (juga SV-level, via Minigraph)
    GRAPH_CONSTRUCTION(ch_clean)
    ch_graph = GRAPH_CONSTRUCTION.out.gfa   // [ meta, full.gfa ]

    // ── Step 4: Analisis Graph (odgi stats + visualisasi) ─────────────────────
    GRAPH_ANALYSIS(ch_graph)

    emit:
    gfa    = ch_graph
    stats  = GRAPH_ANALYSIS.out.stats
}
