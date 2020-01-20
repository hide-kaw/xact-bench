# ycsb-xslprp.sh(tictoc)
tuple=100000000
maxope=10
rratioary=(50)
rmw=off
skew=0.9
ycsb=on
extime=5
epoch=5

host=`hostname`
chris41="chris41.omni.hpcc.jp"
dbs11="dbs11"

# basically
thread=24
if  test $host = $dbs11 ; then
thread=224
fi

if test $host = $dbs11 ; then
cpumhz=2100
fi
if test $host = $chris41 ; then
cpumhz=2400
fi

for rratio in "${rratioary[@]}"
do
  if test $rratio = 50; then
    result=result_tictoc_ycsbA_tuple100m_skew09_slprp0-1000.dat
  elif test $rratio = 95; then
    result=result_tictoc_ycsbB_tuple100m_skew09_val4-1k.dat
  elif test $rratio = 100; then
    result=result_tictoc_ycsbC_tuple100m_skew09_val4-1k.dat
  else
    echo "BUG"
    exit 1
  fi
  rm $result
    
  echo "#worker threads, avg-tps, min-tps, max-tps, avg-ar, min-ar, max-ar, avg-camiss, min-camiss, max-camiss" >> $result
  echo "#sudo perf stat -e cache-misses,cache-references -o ana.txt numactl --interleave=all ../tictoc.exe tuple $maxope $thread $rratio $rmw $skew $ycsb $cpumhz $extime" >> $result
  
  for ((slpclks = 0; slpclks <= 25000; slpclks += 500))
  do
    cd ../
    make clean; make -j SLEEP_READ_PHASE=$slpclks VAL_SIZE=4
    cd script
  
    echo "sudo perf stat -e cache-misses,cache-references -o ana.txt numactl --interleave=all ../tictoc.exe $tuple $maxope $thread $rratio $rmw $skew $ycsb $cpumhz $extime"
    
    sumTH=0
    sumAR=0
    sumCA=0
    maxTH=0
    maxAR=0
    maxCA=0
    minTH=0
    minAR=0
    minCA=0
    sumRLR=0
    sumVLR=0
    sumER=0
    for ((i = 1; i <= epoch; ++i))
    do
      if test $host = $dbs11 ; then
        sudo perf stat -e cache-misses,cache-references -o ana.txt numactl --interleave=all ../tictoc.exe $tuple $maxope $thread $rratio $rmw $skew $ycsb $cpumhz $extime > exp.txt
      fi
      if test $host = $chris41 ; then
        perf stat -e cache-misses,cache-references -o ana.txt numactl --interleave=all ../tictoc.exe $tuple $maxope $thread $rratio $rmw $skew $ycsb $cpumhz $extime > exp.txt
      fi
    
      tmpTH=`grep throughput ./exp.txt | awk '{print $2}'`
      tmpAR=`grep abort_rate ./exp.txt | awk '{print $2}'`
      tmpCA=`grep cache-misses ./ana.txt | awk '{print $4}'`
      tmpER=`grep extra_reads ./exp.txt | awk '{print $2}'`
      tmpRLR=`grep read_latency_rate ./exp.txt | awk '{print $2}'`
      tmpVLR=`grep vali_latency_rate ./exp.txt | awk '{print $2}'`
      sumTH=`echo "$sumTH + $tmpTH" | bc`
      sumAR=`echo "scale=4; $sumAR + $tmpAR" | bc | xargs printf %.4f`
      sumCA=`echo "$sumCA + $tmpCA" | bc`
      sumER=`echo "$sumER + $tmpER" | bc`
      sumRLR=`echo "scale=4; $sumRLR + $tmpRLR" | bc | xargs printf %.4f`
      sumVLR=`echo "scale=4; $sumVLR + $tmpVLR" | bc | xargs printf %.4f`
      echo "tmpTH: $tmpTH, tmpAR: $tmpAR, tmpCA: $tmpCA, tmpER: $tmpER, tmpRLR: $tmpRLR, tmpVLR: $tmpVLR"
    
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
    avgER=`echo "$sumER / $epoch" | bc`
    avgRLR=`echo "scale=4; $sumRLR / $epoch" | bc | xargs printf %.4f`
    avgVLR=`echo "scale=4; $sumVLR / $epoch" | bc | xargs printf %.4f`
    echo "sumTH: $sumTH, sumAR: $sumAR, sumCA: $sumCA"
    echo "avgTH: $avgTH, avgAR: $avgAR, avgCA: $avgCA, avgER: $avgER, avgRLR: $avgRLR, avgVLR: $avgVLR"
    echo "maxTH: $maxTH, maxAR: $maxAR, maxCA: $maxCA"
    echo "minTH: $minTH, minAR: $minAR, minCA: $minCA"
    echo ""
    echo "$slpclks $avgTH $minTH $maxTH $avgAR $minAR $maxAR $avgCA $minCA $maxCA $avgER $avgRLR $avgVLR" >> $result
  done
done
