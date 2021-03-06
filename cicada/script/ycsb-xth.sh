#ycsb-xth.sh(cicada)
tuple=10000000
maxope=1
#rratioary=(50 95 100)
rratioary=(95)
rmw=on
skew=0.99
ycsb=on
wal=off
group_commit=off
cpu_mhz=2100
io_time_ns=5
group_commit_timeout_us=2
gci=10
prv=10000
extime=3
epoch=3

host=`hostname`
chris41="chris41.omni.hpcc.jp"
dbs11="dbs11"

#basically
thread=24
if  test $host = $dbs11 ; then
  thread=224
fi

cd ../
make clean; make -j KEY_SIZE=8 VAL_SIZE=100
cd script/

for rratio in "${rratioary[@]}"
do
  if test $rratio = 50 ; then
    result=result_cicada_ycsbA_tuple10m_ope16_rmw_skew099.dat
  elif test $rratio = 95 ; then
    result=result_cicada_ycsbB_tuple10m_ope1_rmw_skew099.dat
  elif test $rratio = 100 ; then
    result=result_cicada_ycsbC_tuple10m_ope1_skew099.dat
    maxope=1
  else
    echo "BUG"
    exit 1
  fi
  rm $result

  echo "#tuple num, avg-tps, min-tps, max-tps, avg-ar, min-ar, max-ar, avg-camiss, min-camiss, max-camiss" >> $result
  echo "#sudo perf stat -e cache-misses,cache-references -o ana.txt numactl --interleave=all ../cicada.exe tuple $maxope $thread $rratio $rmw $skew $ycsb $wal $group_commit $cpu_mhz $io_time_ns $group_commit_timeout_us $gci $prv $extime" >> $result
  
  for ((thread=1; thread<=28; thread+=4))
  do
    echo "sudo perf stat -e cache-misses,cache-references -o ana.txt numactl --interleave=all ../cicada.exe $tuple $maxope $thread $rratio $rmw $skew $ycsb $wal $group_commit $cpu_mhz $io_time_ns $group_commit_timeout_us $gci $prv $extime"
    echo "Thread number $thread"
    
    sumTH=0
    sumAR=0
    sumCA=0
    maxTH=0
    maxAR=0
    maxCA=0
    minTH=0 
    minAR=0
    minCA=0
    for ((i = 1; i <= epoch; ++i))
    do
      if test $host = $dbs11 ; then
        sudo perf stat -e cache-misses,cache-references -o ana.txt numactl --interleave=all ../cicada.exe $tuple $maxope $thread $rratio $rmw $skew $ycsb $wal $group_commit $cpu_mhz $io_time_ns $group_commit_timeout_us $gci $prv $extime > exp.txt
      fi
      if test $host = $chris41 ; then
        perf stat -e cache-misses,cache-references -o ana.txt numactl --interleave=all ../cicada.exe $tuple $maxope $thread $rratio $rmw $skew $ycsb $wal $group_commit $cpu_mhz $io_time_ns $group_commit_timeout_us $gci $prv $extime > exp.txt
      fi
    
      tmpTH=`grep throughput ./exp.txt | awk '{print $2}'`
      tmpAR=`grep abort_rate ./exp.txt | awk '{print $2}'`
      tmpCA=`grep cache-misses ./ana.txt | awk '{print $4}'`
      sumTH=`echo "$sumTH + $tmpTH" | bc`
      sumAR=`echo "scale=4; $sumAR + $tmpAR" | bc | xargs printf %.4f`
      sumCA=`echo "$sumCA + $tmpCA" | bc`
      echo "tmpTH: $tmpTH, tmpAR: $tmpAR, tmpCA: $tmpCA"
    
      if test $i -eq 1 ; then
        maxTH=$tmpTH
        maxAR=$tmpAR
        maxCA=$tmpCA
        minTH=$tmpTH
        minAR=$tmpAR
        minCA=$tmpCA
      fi
    
      flag=`echo "$tmpTH > $maxTH" | bc`
      if test $flag -eq 1 ; then
        maxTH=$tmpTH
      fi
      flag=`echo "$tmpAR > $maxAR" | bc`
      if test $flag -eq 1 ; then
        maxAR=$tmpAR
      fi
      flag=`echo "$tmpCA > $maxCA" | bc`
      if test $flag -eq 1 ; then
        maxCA=$tmpCA
      fi
    
      flag=`echo "$tmpTH < $minTH" | bc`
      if test $flag -eq 1 ; then
        minTH=$tmpTH
      fi
      flag=`echo "$tmpAR < $minAR" | bc`
      if test $flag -eq 1 ; then
        minAR=$tmpAR
      fi
      flag=`echo "$tmpCA < $minCA" | bc`
      if test $flag -eq 1 ; then
        minCA=$tmpCA
      fi
    done
    avgTH=`echo "$sumTH / $epoch" | bc`
    avgAR=`echo "scale=4; $sumAR / $epoch" | bc | xargs printf %.4f`
    avgCA=`echo "$sumCA / $epoch" | bc`
    echo "sumTH: $sumTH, sumAR: $sumAR, sumCA: $sumCA"
    echo "avgTH: $avgTH, avgAR: $avgAR, avgCA: $avgCA"
    echo "maxTH: $maxTH, maxAR: $maxAR, maxCA: $maxCA"
    echo "minTH: $minTH, minAR: $minAR, minCA: $minCA"
    echo ""
    echo "$thread $avgTH $minTH $maxTH $avgAR $minAR $maxAR $avgCA $minCA $maxCA" >> $result
  done
done
