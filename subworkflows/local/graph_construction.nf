/*
========================================================================================
    SUBWORKFLOW: GRAPH_CONSTRUCTION — konstruksi graf SV (Minigraph)
    Hickey et al. (2024) Nature Biotechnology

    Alur:
      1. Minigraph   → initial SV-level graph (.gfa) dari referensi + assemblies
      2. cactus-minigraph → graf SV dengan Minigraph (.full.gfa, rGFA);
                            penyelarasan tingkat basa Cactus tidak dijalankan
========================================================================================
*/

include { MINIGRAPH       } from '../../modules/local/graph_construction/minigraph'
include { CACTUS_MINIGRAPH } from '../../modules/local/graph_construction/cactus_minigraph'

workflow GRAPH_CONSTRUCTION {

    take:
    ch_fasta   // [ meta, fasta ] — sudah dipreprocessing

    main:

    // ── Step 1: Pisahkan referensi backbone vs non-referensi ──────────────────
    ch_ref = ch_fasta
        .filter { meta, fasta -> meta.id == params.reference_name }
        .first()   // [ ref_meta, ref_fasta ]

    // Kumpulkan semua fasta non-referensi ke satu list
    ch_other_fastas = ch_fasta
        .filter { meta, fasta -> meta.id != params.reference_name }
        .map { meta, fasta -> fasta }
        .collect()                    // [ [fasta1, fasta2, ...] ]
        .toList()                     // pastikan jadi list

    // ── Step 2: Minigraph — SV-level graph ────────────────────────────────────
    // Gabungkan ref + others menjadi satu tuple
    ch_minigraph_input = ch_ref
        .combine(ch_other_fastas)
        .map { items ->
            def meta = [ id: 'pangenome' ]
            def ref_fasta = items[1]       // ref fasta
            def others = items[2..-1]      // sisanya = other fastas
            if (others.size() == 1 && others[0] instanceof List) {
                others = others[0]
            }
            return tuple( meta, ref_fasta, others )
        }

    MINIGRAPH(ch_minigraph_input)

    // ── Step 3: Buat seqFile untuk Cactus ─────────────────────────────────────
    // Kumpulkan semua sample name + fasta path
    ch_seqfile_data = ch_fasta
        .map { meta, fasta -> "${meta.id}\t${fasta}" }
        .collect()

    ch_seqfile = ch_seqfile_data.map { lines ->
        def f = file("${workDir}/seqfile.txt")
        f.text = lines.join('\n') + '\n'
        return f
    }

    // ── Step 4: cactus-minigraph — graf SV ──────────────────────────
    ch_cactus_input = MINIGRAPH.out.gfa
        .combine(ch_seqfile)
        .map { meta, gfa, seqfile ->
            return tuple( meta, seqfile, gfa )
        }

    CACTUS_MINIGRAPH(ch_cactus_input)

    emit:
    gfa        = CACTUS_MINIGRAPH.out.gfa       // [ meta, full.gfa ]
    sv_gfa     = CACTUS_MINIGRAPH.out.sv_gfa    // [ meta, sv.gfa ]
    raw_gfa    = MINIGRAPH.out.gfa              // [ meta, minigraph.gfa ]
}
