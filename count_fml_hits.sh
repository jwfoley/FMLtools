#! /bin/bash

# usage: count_fml_hits.sh file1.cram file2.cram ...

sam_flags='-q 10 -F 0x4 -F 0x100 -F 0x200 -F 0x800'
wobble=0
motif_bed="~/genome/hs1/motif/CGNR_hs1.bed.zst" # assumed to be zstd-compressed

parallel "samtools view -u $sam_flags {} | python3 -OO ~/FMLtools/count_fml_hits.py -q -w $wobble <(zstdcat $motif_bed) 2> {/.}.$motif.MAPQ$min_mapq.wobble$wobble.log | zstd > {/.}.$motif.bed.zst" ::: "$@"

