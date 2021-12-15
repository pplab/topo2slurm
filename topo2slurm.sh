#!/bin/sh
usage(){
 echo "  Convert topology description file to slurm topology.conf               "
 echo "                                                                     "
 echo " usage: $0 -I input_topo_file [-O out_put_slurm_topology.conf] \  "
 echo "                 -v   \                                              "
 echo "                 -h                                                  "
 echo "       -I:     [ description of the parameter ]                      "
 echo "       -O:     [ description of the parameter ]                      "
 echo "       -v:     show verbose information                              "
 echo "       -h:     Show help                                             "
 exit 1
}

DIE() {
    echo $1
    exit 1
}

while getopts "I:O:vh" Options
do
    case ${Options} in
        v  ) verbose_switch=1;;
        I  ) IFILE=$OPTARG;;
        O  ) OFILE=$OPTARG;;
        h  ) usage; exit;;
        *  ) echo "Unimplemented option chosen.";uasge;exit;;
    esac
done

[ $# -eq 0 ] && usage&&exit

if [ "$verbose_switch" ]
then
    echo "input file is " $IFILE
    if [ "$OFILE" ]
    then
        echo "output file is " $OFILE
        cat $IFILE |./topo2slurm.awk|./combineHosts.awk >$OFILE
    else
        echo "output to stdout"
        cat $IFILE |./topo2slurm.awk|./combineHosts.awk
    fi
else
    if [ "$OFILE" ]
    then
        cat $IFILE |./topo2slurm.awk 2>/dev/null|./combineHosts.awk >$OFILE 2>/dev/null
    else
        cat $IFILE |./topo2slurm.awk 2>/dev/null|./combineHosts.awk 2>/dev/null
    fi
fi
