/*
========================================================================================
    MODULE: ODGI_STATS — Statistik Pangenome Graph
    Tool   : odgi stats (https://odgi.readthedocs.io)
    Label  : process_medium
    Note   : GFA dari Minigraph-Cactus = rGFA, perlu konversi dulu via vg
========================================================================================
*/

process ODGI_STATS {

    tag "${meta.id}"
    label 'process_medium'
    publishDir "${params.outdir}/analysis", mode: 'copy'

    input:
    tuple val(meta), path(gfa)

    output:
    tuple val(meta), path("*.stats.yaml"), emit: stats
    path "versions.yml",                   emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    # Konversi rGFA/Cactus-GFA → standard GFA (odgi-compatible)
    # Step 1: convert rGFA → PackedGraph (vg format)
    vg convert -g ${gfa} -p > ${prefix}.temp.vg 2>/dev/null

    # Step 2: urutkan ID node secara topologis. Catatan: keluaran vg ids -s ke stdout
    #         dan tidak disimpan, sehingga langkah ini tidak mengubah temp.vg.
    #         Pengenal teks rGFA (s1, s2, ...) sudah diubah menjadi bilangan oleh Step 1.
    vg ids -s ${prefix}.temp.vg

    # Step 3: convert kembali ke GFA1 standard
    vg convert -f ${prefix}.temp.vg > ${prefix}.std.gfa
    rm -f ${prefix}.temp.vg

    # Convert GFA → ODGI binary format
    odgi build -g ${prefix}.std.gfa -o ${prefix}.unsorted.og -t ${task.cpus}
    odgi sort  -i ${prefix}.unsorted.og -o ${prefix}.og -t ${task.cpus}
    rm -f ${prefix}.unsorted.og

    # Hitung statistik dasar
    odgi stats -i ${prefix}.og -S -y > ${prefix}.stats.yaml

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        odgi: \$(odgi version 2>&1 | head -1)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "length: 0\\nnodes: 0\\nedges: 0\\npaths: 0" > ${prefix}.stats.yaml
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        odgi: "stub-0.0.0"
    END_VERSIONS
    """
}

/*
========================================================================================
    MODULE: ODGI_VIZ — Visualisasi 1D Layout
    Note   : GFA dari Minigraph-Cactus = rGFA, perlu konversi dulu via vg
========================================================================================
*/

process ODGI_VIZ {

    tag "${meta.id}"
    label 'process_medium'
    publishDir "${params.outdir}/analysis", mode: 'copy'

    input:
    tuple val(meta), path(gfa)

    output:
    tuple val(meta), path("*.png"), emit: png
    path "versions.yml",            emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    # Konversi rGFA/Cactus-GFA → standard GFA (odgi-compatible)
    # Step 1: convert rGFA → PackedGraph (vg format)
    vg convert -g ${gfa} -p > ${prefix}.temp.vg 2>/dev/null

    # Step 2: urutkan ID node secara topologis. Catatan: keluaran vg ids -s ke stdout
    #         dan tidak disimpan, sehingga langkah ini tidak mengubah temp.vg.
    #         Pengenal teks rGFA (s1, s2, ...) sudah diubah menjadi bilangan oleh Step 1.
    vg ids -s ${prefix}.temp.vg

    # Step 3: convert kembali ke GFA1 standard
    vg convert -f ${prefix}.temp.vg > ${prefix}.std.gfa
    rm -f ${prefix}.temp.vg

    odgi build -g ${prefix}.std.gfa -o ${prefix}.og -t ${task.cpus}
    odgi sort  -i ${prefix}.og -o ${prefix}.sorted.og -t ${task.cpus}
    odgi viz   -i ${prefix}.sorted.og -o ${prefix}.1D.png -x 1500 -y 500

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        odgi: \$(odgi version 2>&1 | head -1)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.1D.png
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        odgi: "stub-0.0.0"
    END_VERSIONS
    """
}
