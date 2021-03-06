#!/usr/bin/env nextflow
/*
========================================================================================
                         PhilPalmer/vcf-annotator
========================================================================================
 PhilPalmer/vcf-annotator Nextflow pipeline to annotate VCF files
 #### Homepage / Documentation
 https://github.com/PhilPalmer/vcf-annotator
----------------------------------------------------------------------------------------
*/

Channel
  .fromPath(params.vcf)
  .ifEmpty { exit 1, "VCF file not found: ${params.vcf}" }
  .map { file -> tuple(file.simpleName, file) }
  .set { vcf }
Channel
  .fromPath(params.dbsnp)
  .ifEmpty { exit 1, "dbSNP file not found: ${params.dbsnp}" }
  .set { dbsnp }
Channel
  .fromPath(params.dbsnp_index)
  .ifEmpty { exit 1, "dbSNP index file not found: ${params.dbsnp_index}" }
  .set { dbsnp_index }

/*--------------------------------------------------
  Annotate VCF
---------------------------------------------------*/

process annotate_vcf {
  tag "$name"
  publishDir params.outdir, mode: 'copy'

  input:
  set val(name), file(vcf) from vcf
  each file(dbsnp) from dbsnp
  each file(dbsnp_index) from dbsnp_index

  output:
  file("${name}.vcf.gz") into annotated_vcf

  script:
  """
  vcf=$vcf

  # uncompress bgzipped or gzipped input
  if [[ $vcf == *.gz ]]; then
    compression=\$(htsfile $vcf)
    if [[ \$compression == *"BGZF"* ]]; then
      bgzip -cdf $vcf > tmp.vcf && vcf=tmp.vcf
    elif [[ \$compression == *"gzip"* ]]; then
      gzip -cdf $vcf > tmp.vcf && vcf=tmp.vcf
    fi
  fi

  vcf_remapper.py --input_file \$vcf --output_file ${name}
  mv output/${name}.vcf ${name}.tmp.vcf
  bgzip ${name}.tmp.vcf
  tabix -p vcf ${name}.tmp.vcf.gz

  bcftools annotate -c CHROM,FROM,TO,ID -a ${dbsnp} -Oz -o ${name}.vcf.gz ${name}.tmp.vcf.gz
  """ 
}