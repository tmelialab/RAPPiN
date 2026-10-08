/*
========================================================================================
    MODULE: CACTUS_MINIGRAPH — cactus-minigraph (langkah pertama Minigraph-Cactus)
    Tool   : Cactus (https://github.com/ComparativeGenomicsToolkit/cactus)
    Paper  : Hickey et al. (2024) Nature Biotechnology
    Label  : process_high
    Peran  : Membangun graf pangenome tingkat variasi struktural dengan Minigraph
             (perintah cactus-minigraph). Penyelarasan tingkat basa (graphmap/align/join)
             tidak dijalankan. Output: .full.gfa berformat rGFA untuk analisis odgi/vg.
             Catatan: GFA dari process MINIGRAPH diterima sebagai input tetapi tidak dipakai.
========================================================================================
*/

process CACTUS_MINIGRAPH {

    tag "${meta.id}"
    label 'process_high'
    publishDir "${params.outdir}/graph", mode: 'copy'

    container 'quay.io/comparative-genomics-toolkit/cactus:v2.9.0'

    input:
    tuple val(meta), path(seqfile), path(minigraph_gfa)

    output:
    tuple val(meta), path("*.full.gfa"),   emit: gfa
    tuple val(meta), path("*.sv.gfa"),     emit: sv_gfa
    path "*.log",                          emit: log
    path "versions.yml",                   emit: versions

    script:
    def prefix    = task.ext.prefix ?: "${meta.id}"
    def ref_name  = params.reference_name  // nama sample referensi di seqFile
    def args      = task.ext.args ?: ""
    def jobstore  = "${prefix}_jobstore"

    """
    # cactus-minigraph: konstruksi graf SV dengan Minigraph (bukan penyelarasan tingkat basa)
    # seqFile format: <sample_name> <TAB> <path_to_fasta>
    # referensi = baris pertama di seqFile (nama harus sesuai params.reference_name)

    cactus-minigraph \\
        ${jobstore} \\
        ${seqfile} \\
        ${prefix}.full.gfa \\
        --reference ${ref_name} \\
        --mgCores ${task.cpus} \\
        --binariesMode local \\
        ${args} \\
        2>&1 | tee ${prefix}.cactus.log

    # Buat SV-level GFA (tanpa sekuens basa, hanya struktur)
    # vg view -Fv ${prefix}.full.gfa | vg simplify - | vg view - > ${prefix}.sv.gfa
    cp ${prefix}.full.gfa ${prefix}.sv.gfa

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        cactus: \$(cactus --version 2>&1 | grep -oP 'v[0-9]+\\.[0-9]+\\.[0-9]+' | head -1)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.full.gfa ${prefix}.sv.gfa ${prefix}.cactus.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        cactus: "stub-v2.9.0"
    END_VERSIONS
    """
}
