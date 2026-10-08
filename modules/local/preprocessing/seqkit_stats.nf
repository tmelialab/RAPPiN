/*
========================================================================================
    MODULE: SEQKIT_STATS — Statistik FASTA
    Tool   : seqkit (https://bioinf.shenwei.me/seqkit)
    Label  : process_low
========================================================================================
*/

process SEQKIT_STATS {

    tag "${meta.id}"
    label 'process_low'

    // container 'quay.io/biocontainers/seqkit:2.6.1--h9ee0642_0'

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("*.stats.tsv"), emit: tsv
    path "versions.yml",                  emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    seqkit stats -a ${fasta} -o ${prefix}.stats.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        seqkit: \$(seqkit version 2>&1 | sed 's/seqkit v//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    printf "file\tformat\ttype\tnum_seqs\tsum_len\tmin_len\tavg_len\tmax_len\n" > ${prefix}.stats.tsv
    printf "${fasta}\tFASTA\tDNA\t5\t500000\t100000\t100000\t100000\n" >> ${prefix}.stats.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        seqkit: "stub-0.0.0"
    END_VERSIONS
    """
}
