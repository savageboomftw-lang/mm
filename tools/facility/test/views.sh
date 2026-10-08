#!/usr/bin/env bash
# render a set of preview views: views.sh scene.txt outdir
S=$1; O=$2; mkdir -p $O; R="$(dirname "$0")/render.py"
python3 $R $S $O/01_reception.png "20,8,32" "-4,5,6" 78 960 540 &
python3 $R $S $O/02_security.png "0,6,-2" "0,5,-22" 78 960 540 &
python3 $R $S $O/03_corridor.png "0,6,-27" "0,5,-75" 72 960 540 &
python3 $R $S $O/04_lab.png "-9,6,-27" "-36,5,-44" 80 960 540 &
python3 $R $S $O/05_medical.png "10,6,-38" "38,4.5,-40" 78 960 540 &
python3 $R $S $O/06_storage.png "-9,6,-72" "-32,6,-66" 80 960 540 &
python3 $R $S $O/07_maint.png "9,7,-72" "28,6,-68" 82 960 540 &
python3 $R $S $O/08_contain.png "0,6,-99" "0,9,-120" 80 960 540 &
python3 $R $S $O/09_extract.png "0,6,-138" "0,5,-156" 78 960 540 &
python3 $R $S $O/10_service.png "34,5,-86" "34,4,-104" 78 960 540 &
wait
