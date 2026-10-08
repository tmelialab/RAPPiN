/*
========================================================================================
    SUBWORKFLOW: GRAPH_ANALYSIS
    Tahap analisis graf:
      - odgi stats  → node, edge, path count
      - odgi viz    → visualisasi 1D layout
      - vg stats    → statistik graph level vg
========================================================================================
*/

include { ODGI_STATS } from '../../modules/local/graph_analysis/odgi'
include { ODGI_VIZ   } from '../../modules/local/graph_analysis/odgi'
include { VG_STATS   } from '../../modules/local/graph_analysis/vg_stats'

workflow GRAPH_ANALYSIS {

    take:
    ch_gfa   // [ meta, gfa ]

    main:

    // ── odgi stats — node, edge, path count ───────────────────────────────────
    ODGI_STATS(ch_gfa)

    // ── odgi viz — visualisasi 1D layout ─────────────────────────────────────
    ODGI_VIZ(ch_gfa)

    // ── vg stats — statistik via vg toolkit ───────────────────────────────────
    VG_STATS(ch_gfa)

    // ── core vs variable sequences — via bin/extract_core_var.sh ─────────────
    // (dipanggil dari dalam process ODGI_STATS karena butuh .og file)
    // Script ada di bin/ → otomatis masuk PATH saat runtime Nextflow

    emit:
    stats      = ODGI_STATS.out.stats    // [ meta, stats.yaml ]
    viz        = ODGI_VIZ.out.png        // [ meta, 1D.png ]
    vg_stats   = VG_STATS.out.stats      // [ meta, vg_stats.txt ]
}
