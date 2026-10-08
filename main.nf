#!/usr/bin/env nextflow

/*
========================================================================================
    RAPPiN — Resource-Aware Pangenome Pipeline in Nextflow
========================================================================================
    Pipeline Nextflow DSL2 untuk konstruksi dan analisis graf pangenome tingkat
    variasi struktural (Minigraph, dijalankan melalui cactus-minigraph), disertai
    perekaman pemakaian sumber daya dan rekomendasi alokasi core/RAM.

    Pengembang : Doni Arman S. — Program Studi Sistem Informasi, Universitas Riau
    Repositori : https://github.com/tmelialab/RAPPiN
========================================================================================
*/

nextflow.enable.dsl = 2

// ─────────────────────────────────────────────────────────────────────────────
// IMPORT WORKFLOWS
// ─────────────────────────────────────────────────────────────────────────────
include { PANGENOME_WORKFLOW } from './workflows/pangenome'

// ─────────────────────────────────────────────────────────────────────────────
// MAIN ENTRY POINT
// ─────────────────────────────────────────────────────────────────────────────
workflow {

    log.info """
    ╔══════════════════════════════════════════════════════════════════╗
    ║   RAPPiN  |  Resource-Aware Pangenome Pipeline in Nextflow      ║
    ╚══════════════════════════════════════════════════════════════════╝
    Input    : ${params.input}
    Output   : ${params.outdir}
    Mode     : ${params.mode}
    Profile  : ${workflow.profile}
    """.stripIndent()

    PANGENOME_WORKFLOW()
}
