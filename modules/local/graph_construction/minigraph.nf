/*
========================================================================================
    MODULE: MINIGRAPH — Konstruksi awal pangenome graph
    Tool   : minigraph (https://github.com/lh3/minigraph)
    Label  : process_high
    Peran  : Langkah pertama Minigraph-Cactus — bangun graph dari referensi + assemblies
             Output GFA digunakan sebagai input ke cactus-minigraph
========================================================================================
*/

process MINIGRAPH {

    tag "${meta.id}"
    label 'process_high'

    // container 'quay.io/biocontainers/minigraph:0.21--he4a0461_1'

    input:
    tuple val(meta), path(reference), path(assemblies)

    output:
    tuple val(meta), path("*.gfa"), emit: gfa
    path "versions.yml",           emit: versions

    script:
    def prefix    = task.ext.prefix ?: "${meta.id}"
    def args      = task.ext.args   ?: ""
    def preset    = params.mg_preset
    def min_mapq  = params.mg_min_mapq

    """
    # Minigraph: reference-guided graph construction
    # Preset dikontrol dari nextflow.config (params.mg_preset)
    minigraph \\
        -cx ${preset} \\
        -t ${task.cpus} \\
        -q ${min_mapq} \\
        ${reference} \\
        ${assemblies} \\
        ${args} \\
        > ${prefix}.gfa

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        minigraph: \$(minigraph --version 2>&1 | head -1)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.gfa

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        minigraph: "stub-0.21"
    END_VERSIONS
    """
}
