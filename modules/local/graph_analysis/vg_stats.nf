/*
========================================================================================
    MODULE: VG_STATS — Statistik Pangenome Graph via vg
    Tool   : vg stats (https://github.com/vgteam/vg)
    Label  : process_medium
    Output : statistik graph: node, edge, length
========================================================================================
*/

process VG_STATS {

    tag "${meta.id}"
    label 'process_medium'
    publishDir "${params.outdir}/analysis", mode: 'copy'

    // container 'quay.io/biocontainers/vg:1.54.0--h607a9b5_0'

    input:
    tuple val(meta), path(gfa)

    output:
    tuple val(meta), path("*.vg_stats.txt"), emit: stats
    path "versions.yml",                     emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # Konversi GFA ke vg format lalu hitung statistik
    vg convert -g ${gfa} -p | vg stats -z - > ${prefix}.vg_stats.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        vg: \$(vg version 2>&1 | grep -oP 'v[0-9]+\\.[0-9]+\\.[0-9]+' | head -1)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    cat > ${prefix}.vg_stats.txt << 'EOF'
    nodes: 12500
    edges: 15300
    length: 750000000
    EOF

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        vg: "stub-1.54.0"
    END_VERSIONS
    """
}
