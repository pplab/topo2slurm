#!/bin/awk -f
BEGIN {FS = ","}
NR<=3{next}
NR==4{nNode=$1;next}
NR>4 && NR<=4+nNode{
    NODE_mac[iNode]=$1;
    NODE_type[$1]=$3;
    NODE_hostname[$1]=$6;
    ++iNode;
    nLink[$1]=0;
    print "The "iNode"th node is loaded, mac: "$1", NODE_type: "NODE_type[$1]", Hostname: ", NODE_hostname[$1] > "/dev/stderr";
    next;
}
NR>4+nNode{ # read the input file until the line with "node"
    if($1 != "node")
    {
        idx=$1","$2;
        Link[idx]=1;
        print "Link: "idx" is loaded" > "/dev/stderr";
        if(NF>14) # multi-links, keep loading other linked nodes
        {
            for(j = 15; j < NF; j+=13)
            {
                idx=$1","$j;
                Link[idx]=1;
                print "Link: "idx" is loaded" > "/dev/stderr";
            }
        }
    }
    else
    {
        print "End of loading links" > "/dev/stderr";
        nextfile;
    }
    next;
}
END{
    # find compute nodes
    for(i = 0; i < iNode; ++i)
    {
        if(NODE_type[NODE_mac[i]] == 0)
        {
            COMP_NODE_mac[NODE_mac[i]] = 1;
            ++nCOMP;
        }
    }
    print nCOMP" compute nodes are found" > "/dev/stderr";
    # find links for every node
    for(l in Link)
    {
        # split the link index to two nodes
        split(l, nn, ",");
        n1=nn[1];
        n2=nn[2];
        print "link: "l" is decomposed to "n1" and "n2 > "/dev/stderr";
        # add n2 to n1's nearest neighbor list
        idx=n1","nNN[n1]++;
        NN[idx]=n2;
        print "add NN["idx"] = "n2 > "/dev/stderr";
        # add n1 to n2's nearest neighbor list if Link[n2,n1] does not existed(usually this wont happlen)
        if(!n2","n1 in Link)
        {
            idx=n2","nNN[n2]++;
            NN[idx]=n1;
            print "add NN["idx"] = "n1 > "/dev/stderr";
        }
    }
    # find leaf switches
    # leaf switches are connect to compute nodes directly
    for(c in COMP_NODE_mac)
    {
        for(i = 0; i < nNN[c]; ++i)
        {
            idx=c","i;
            neighbor=NN[idx];
            print  "NN["idx"] = "neighbor > "/dev/stderr";
            if(NODE_type[neighbor] != 0) # not a compute node
            {
                if(NODE_type[neighbor] == 1) # unclassified switch
                {
                    LEAF_SW_mac[neighbor] = 1;
                    NODE_type[neighbor] = -1; # leaf switches' type is -1
                    ++nLEAF;
                }
                idx=neighbor","LEAF_CHILD_num[neighbor]++;
                LEAF_CHILD[idx] = c;
                print  "LEAF_CHILD["idx"] = "c > "/dev/stderr";
            }
        }
    }
    print nLEAF" leaf switches are found" > "/dev/stderr";
    # find spine switches
    for(L in LEAF_SW_mac)
    {
        for(i = 0; i < nNN[L]; ++i)
        {
            idx=L","i;
            neighbor=NN[idx];
            print  "NN["idx"] = "neighbor > "/dev/stderr";
            if(NODE_type[neighbor] != 0) # not a compute node
            {
                if(NODE_type[neighbor] == 1) # unclassified switch
                {
                    SPINE_SW_mac[neighbor] = 1;
                    NODE_type[neighbor] = -2; # spine switches' type is -2
                    ++nSPINE;
                }
                idx=neighbor","SPINE_CHILD_num[neighbor]++;
                SPINE_CHILD[idx] = L;
                print  "SPINE_CHILD["idx"] = "L > "/dev/stderr";
            }
        }
    }
    print nSPINE" spine switches are found" > "/dev/stderr";
    for(S in SPINE_SW_mac)
    {
        print "Spine switch "S" has "SPINE_CHILD_num[S]" children switches"  > "/dev/stderr";
    }
    # output leaf switches and their child compute nodes
    for(L in LEAF_SW_mac)
    {
        if(LEAF_CHILD_num[L] > 0)
        {
            printf "SwitchName="NODE_hostname[L]" Nodes=";
            for(j=0; j<LEAF_CHILD_num[L]; ++j)
            {
                idx=L","j;
                printf " "NODE_hostname[LEAF_CHILD[idx]];
            }
            printf "\n";
        }
    }
    # output spine switches and their child leaf switches
    for(S in SPINE_SW_mac)
    {
        if(SPINE_CHILD_num[S] > 0)
        {
            printf "SwitchName="NODE_hostname[S]" Switches=";
            for(j=0; j<SPINE_CHILD_num[S]; ++j)
            {
                idx=S","j;
                printf " "NODE_hostname[SPINE_CHILD[idx]];
            }
            printf "\n";
        }
    }
}
