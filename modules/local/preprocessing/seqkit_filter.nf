/*
========================================================================================
    MODULE: SEQKIT_FILTER — Filter sekuens berdasarkan panjang minimum
    Tool   : seqkit (https://bioinf.shenwei.me/seqkit)
    Label  : process_low
========================================================================================
*/

process SEQKIT_FILTER {

    tag "${meta.id}"
    label 'process_low'

    // container 'quay.io/biocontainers/seqkit:2.6.1--h9ee0642_0'

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("*filtered.fa"), emit: fasta
    path "versions.yml",                   emit: versions

    script:
    def prefix  = task.ext.prefix ?: "${meta.id}"
    def min_len = params.min_seq_len

    """
    seqkit seq --min-len ${min_len} ${fasta} > ${prefix}.filtered.fa

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        seqkit: \$(seqkit version 2>&1 | sed 's/seqkit v//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    cp ${fasta} ${prefix}.filtered.fa

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        seqkit: "stub-0.0.0"
    END_VERSIONS
    """
}
