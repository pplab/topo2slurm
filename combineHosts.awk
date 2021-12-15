#!/bin/awk -f
# load topology file with full hostname and output the
# slurm topology file
# input example:
#   SwitchName=TOR1 Nodes= master s2 s3 s1
#   SwitchName=TOR2 Nodes= s4 s7 s6 s5
#   SwitchName=SPINE1 Switches= TOR1 TOR2

NF==3{ # only one host
    printf $1" "$2$3"\n";
    next;
}
NF>3{ # multi hosts will be combined together
    HEADER=$1" "$2;
    delete host;
    for(i=3; i<=NF; ++i)
        host[i]=$i;
    nh=asort(host);

    print "number of host:",nh > "/dev/stderr";
    # usually, a hostname has two parts: the prefix and the serial number
    # such as: cnode001, rnode01, gnode1, ...
    splitHostname(host, nh, PREFIX, nPREFIX, SN_str);
    print length(nPREFIX),"prefix are found" > "/dev/stderr";
    for(pre in nPREFIX)
        print pre,nPREFIX[pre] > "/dev/stderr";
    # combine hostname with every prefix
    # init output combined HOSTNAME
    combined_HOSTNAME=HEADER;
    isFirstNode=1;
    for(pre in nPREFIX) {
        print "start combine serial numbers of prefix",pre > "/dev/stderr";
        ig=0;
        delete group_SN;
        # collect the SERIALNUMBER with same prefix
        for(i=1; i<=nh; ++i)
        {
            if(PREFIX[i] == pre)
            {
                if(SN_str[i]) {
                    group_SN[++ig]=SN_str[i];
                } else { # if the hostname does not have serial number, add the prefix to combined hostname
                    if(isFirstNode)
                    {
                        combined_HOSTNAME=combined_HOSTNAME""pre;
                        isFirstNode=0;
                    }
                    else
                        combined_HOSTNAME=combined_HOSTNAME","pre;
                }
            }
        }
        print "prefix",pre,"has",ig,"serial numbers" > "/dev/stderr";
        for(i=1; i<=ig; ++i)
            print "group_SN[",i,"] =",group_SN[i] > "/dev/stderr";
        if(ig>0)
        {
            combined_SN="";
            combined_SN=combineSERIALNUMBER(group_SN);
            print "prefix",pre,"combined_SN is:",combined_SN > "/dev/stderr";
            if(isFirstNode)
            {
                combined_HOSTNAME=combined_HOSTNAME""pre"["combined_SN"]";
            }
            else
                combined_HOSTNAME=combined_HOSTNAME","pre"["combined_SN"]";
        }
        print "after add prefix",pre,"combined hostname is:",combined_HOSTNAME > "/dev/stderr";
    }
    print combined_HOSTNAME;
}

function splitHostname(host, nh, PREFIX, nPREFIX, SN_str,   i, pos, pre){
    # split hostname to prefix part and serial number part
    # input:
    #    host: host list
    #    nh: number of hosts
    # output:
    #   PREFIX: prefix of each host
    #   nPREFIX: number of each prefix
    #   SERIALNUMBER: serial number of each host
    delete PREFIX;
    delete nPREFIX;
    for(i=1; i<=nh; ++i) {
        pos=match(host[i], /([0-9]+$)/);
        if(pos==0){  # hostname does not have any serial number
            pre=host[i];
            SN_str[i]="";
        } else {
            pre=substr(host[i], 1, pos-1);
            SN_str[i]=substr(host[i], pos);
        }
        PREFIX[i]=pre;
        ++nPREFIX[pre];
    }
}

function combineSERIALNUMBER(SN_str,    combined_SN, isFloatFormat, i){
    # check whether the idx is fix or float format
    # fix format:
    #  001, 002, 010, 011, 012, 103
    # float format:
    #  1, 2, 10, 11, 12, 13
    # float format has no 0 started strnum, the length may be or not be same
    # input:
    #   SN: list of serial number which have same prefix
    #   such as: 001, 002, 010, 011, 012, 013 (fixed format)
    #        or: 1, 2, 10, 12, 13 (float format)
    # output:
    #   combined_SN: string of combined serial number
    #   such as: 001-002,010-013
    #        or: 1-2,10-13
    isFloatFormat=1;
    for(i = 1; i <= length(SN_str); ++i)
    {
        if(SN_str[i]~"^0")
        {
            isFloatFormat=0;
            break;
        }
    }

    if(isFloatFormat == 1)
    {
        combined_SN = combineFloatSN(SN_str);
        print "combineFloatSN result: ", combined_SN > "/dev/stderr";
    }else
    {
        combined_SN = combineFixSN(SN_str);
        print "combineFixSN result: ", combined_SN > "/dev/stderr";
    }
    return combined_SN;
}

function combineFloatSN(SN_str,    combined_SN, SN, n, i, pre_SN, cur_SN, isContinous) {
    n=strtoSN(SN_str, SN);
    print "SN has",n,"elements" > "/dev/stderr";
    pre_SN=SN[1];
    combined_SN=pre_SN;
    print "After add sn:", SN[1], "combined_SN =",combined_SN > "/dev/stderr";
    isContinous=0;
    for(i=2; i<=n; ++i)
    {
        cur_SN=SN[i];
        if(cur_SN == pre_SN+1) # continous numbers should be combined together
        {
            if(isContinous == 0) # first continous number
            {
                combined_SN=combined_SN"-";
                isContinous=1;
            }
            if(i == n) # last number
                combined_SN=combined_SN""cur_SN;
            else
                pre_SN=cur_SN;
        }else
        {
            if(isContinous == 1) # end of continous numbers
            {
                isContinous = 0;
                combined_SN=combined_SN""pre_SN;
            }
            combined_SN=combined_SN","cur_SN;
            pre_SN=cur_SN;
        }
        print "After add sn:", SN[i], "combined_SN =",combined_SN > "/dev/stderr";
    }
    print "final returned combined_SN =",combined_SN > "/dev/stderr";
    return combined_SN
}

function strtoSN(SN_str, SN, n,   i){
    # remove beginning 0s
    delete SN;
    for(i=1; i<=length(SN_str); ++i)
    {
        sub(/^0+/,"",SN_str[i]);
        SN[i]=strtonum(SN_str[i]);
        print "string", SN_str[i], "is converted to", SN[i] > "/dev/stderr";
    }
    n=asort(SN);
    print "SN has total",n,"elements" > "/dev/stderr";
    return n;
}

function combineFixSN(SN_str,    combined_SN, LENGTH, nLENGTH, len, n, i, SN_group, combined_SN_group) {
    # combine serial number of fixed format, which means they have same length
    # the serial numbers string may have different length, first divide them
    # to different groups of different length
    # then combine the SN of same length together

    # check whether they are same length
    # not same length, devide to groups in which they are same length
    getSNLength(SN_str, LENGTH, nLENGTH);
    combined_SN="";
    for(len in nLENGTH)
    {
        n=0;
        for(i=1; i<=length(SN_str); ++i)
        {
            if(LENGTH[i] == len)
            {
                SN_group[n++] = SN_str[i];
            }
        }
        combineFixSERIALNUMBER_LEN(SN_group, combined_SN_group);
        if(combined_SN)
            combined_SN=combined_SN","combined_SN_group;
        else
            combined_SN=combined_SN_group;
    }
    return combined_SN;
}

function getSNLength(SN_str, LENGTH, nLENGTH,    i) {
    # count the length each string in SN_str list
    # input:
    #   SN_str: SN string list
    # output:
    #   LENGTH: SN string length list
    #   nLENGTH: number of SNs of the same length
    for(i=1; i<=length(SN_str); ++i)
    {
        LENGTH[i]=length(SN_str[i]);
        ++nLENGTH[LENGTH[i]];
    }
}

function combineFixSERIALNUMBER_LEN(SN_group,    combined_SN, len, SN, n_SN, isContinous, pre, cur, fmt){
    # combine fixed length SN string together
    # input:
    #   SN_group: fixed length serial number string list, such as: 001, 002, 005, 009, 010, 011
    # output:
    #   combined_SN: combined string of serail number list, such as: 001-002,005,009-011
    len=length(SN_group[1]);
    strtoSN(SN_group, SN, n_SN);
    isContinous=0;
    pre=1;
    fmt="%"len"."len"d";
    #combined_SN=SN[pre];
    combined_SN=sprintf(fmt,SN[pre]);
    for(i=2; i<=n_SN; ++i)
    {
        cur=i;
        if(SN[cur] == SN[pre]+1) # continous numbers should be combined together
        {
            if(isContinous == 0) # first continous number
            {
                combined_SN=combined_SN"-";
                isContinous=1;
            }
            if(i == n) # last number
                #combined_SN=combined_SN""SN[cur];
                combined_SN=sprintf(combined_SN""fmt,SN[cur]);
            else
                pre=cur;
        }else
        {
            if(isContinous == 1) # end of continous numbers
            {
                isContinous = 0;
                combined_SN=sprintf(combined_SN""fmt,SN[pre]);
            }
            combined_SN=sprintf(combined_SN""fmt,SN[cur]);
            pre=cur;
        }
    }
    return combined_SN;
}
