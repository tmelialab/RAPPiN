/*
========================================================================================
    MODULE: QUAST — Quality Assessment of Genome Assemblies
    Tool   : QUAST (https://quast.sourceforge.net/)
    Label  : process_medium
    Output : laporan kualitas per assembly (N50, contig count, GC%, total length)
             → digunakan untuk memilih backbone referensi terbaik
========================================================================================
*/

process QUAST {

    tag "${meta.id}"
    label 'process_medium'
    publishDir "${params.outdir}/qc", mode: 'copy'

    // container 'quay.io/biocontainers/quast:5.2.0--py39pl5321h2add14b_1'

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("${meta.id}_quast/"), emit: report_dir
    tuple val(meta), path("${meta.id}_quast/report.tsv"), emit: tsv
    path "versions.yml", emit: versions

    script:
    def prefix    = meta.id
    def min_contig = params.min_contig
    """
    quast.py \\
        ${fasta} \\
        --output-dir ${prefix}_quast \\
        --threads ${task.cpus} \\
        --min-contig ${min_contig} \\
        --no-html

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        quast: \$(quast.py --version 2>&1 | grep -oP '[0-9]+\\.[0-9]+\\.[0-9]+')
    END_VERSIONS
    """

    stub:
    def prefix = meta.id
    """
    mkdir -p ${prefix}_quast
    printf "Assembly\\t${prefix}\\n"           > ${prefix}_quast/report.tsv
    printf "# contigs\\t1000\\n"              >> ${prefix}_quast/report.tsv
    printf "Total length\\t750000000\\n"      >> ${prefix}_quast/report.tsv
    printf "N50\\t1500000\\n"                 >> ${prefix}_quast/report.tsv
    printf "GC (%%)\\t29.5\\n"               >> ${prefix}_quast/report.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        quast: "stub-5.2.0"
    END_VERSIONS
    """
}
