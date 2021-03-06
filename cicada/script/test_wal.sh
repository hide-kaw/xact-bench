#test_wal.sh(cicada)
tuple=1000000
maxope=10
workload=2
cpu_mhz=2400
io_time_ns=50000
group_commit_timeout_us=250
lock_release=E
extime=3
epoch=5

wal=OFF
group_commit=OFF
result=result_cicada_r5_waloff_tuple1m.dat
rm $result
echo "#worker thread, throughput, min, max" >> $result
echo "#./cicada.exe $tuple $maxope thread $workload $wal $group_commit $cpu_mhz $io_time_ns $group_commit_timeout_us $lock_release $extime" >> $result

thread=2
sum=0
echo "./cicada.exe $tuple $maxope $thread $workload $wal $group_commit $cpu_mhz $io_time_ns $group_commit_timeout_us $lock_release $extime"
echo "$thread $epoch"
max=0
min=0 
for ((i = 1; i <= epoch; ++i))
do
    tmp=`./cicada.exe $tuple $maxope $thread $workload $wal $group_commit $cpu_mhz $io_time_ns $group_commit_timeout_us $lock_release $extime`
    sum=`echo "$sum + $tmp" | bc -l`
    echo "sum: $sum,   tmp: $tmp"

  if test $i -eq 1 ; then
    max=$tmp
    min=$tmp
  fi

  flag=`echo "$tmp > $max" | bc -l`
  if test $flag -eq 1 ; then
    max=$tmp
  fi
  flag=`echo "$tmp < $min" | bc -l`
  if test $flag -eq 1 ; then
    min=$tmp
  fi
done
avg=`echo "$sum / $epoch" | bc -l`
echo "sum: $sum, epoch: $epoch"
echo "avg $avg"
echo "max: $max"
echo "min: $min"
thout=`echo "$thread - 1" | bc`
echo "$thout $avg $min $max" >> $result

for ((thread=4; thread<=24; thread+=4))
do
    sum=0
  echo "./cicada.exe $tuple $maxope $thread $workload $wal $group_commit $cpu_mhz $io_time_ns $group_commit_timeout_us $lock_release $extime"
  echo "$thread $epoch"
 
  max=0
  min=0 
    for ((i = 1; i <= epoch; ++i))
    do
        tmp=`./cicada.exe $tuple $maxope $thread $workload $wal $group_commit $cpu_mhz $io_time_ns $group_commit_timeout_us $lock_release $extime`
        sum=`echo "$sum + $tmp" | bc -l`
        echo "sum: $sum,   tmp: $tmp"

    if test $i -eq 1 ; then
      max=$tmp
      min=$tmp
    fi

    flag=`echo "$tmp > $max" | bc -l`
    if test $flag -eq 1 ; then
      max=$tmp
    fi
    flag=`echo "$tmp < $min" | bc -l`
    if test $flag -eq 1 ; then
      min=$tmp
    fi
    done
  avg=`echo "$sum / $epoch" | bc -l`
  echo "sum: $sum, epoch: $epoch"
  echo "avg $avg"
  echo "max: $max"
  echo "min: $min"
  thout=`echo "$thread - 1" | bc`
  echo "$thout $avg $min $max" >> $result
done

wal=P
group_commit=5
result=result_cicada_r5_pwal_tuple1m.dat
rm $result
echo "#worker thread, throughput, min, max" >> $result
echo "#./cicada.exe $tuple $maxope thread $workload $wal $group_commit $cpu_mhz $io_time_ns $group_commit_timeout_us $lock_release $extime" >> $result

thread=2
sum=0
echo "./cicada.exe $tuple $maxope $thread $workload $wal $group_commit $cpu_mhz $io_time_ns $group_commit_timeout_us $lock_release $extime"
echo "$thread $epoch"
max=0
min=0 
for ((i = 1; i <= epoch; ++i))
do
    tmp=`./cicada.exe $tuple $maxope $thread $workload $wal $group_commit $cpu_mhz $io_time_ns $group_commit_timeout_us $lock_release $extime`
    sum=`echo "$sum + $tmp" | bc -l`
    echo "sum: $sum,   tmp: $tmp"

  if test $i -eq 1 ; then
    max=$tmp
    min=$tmp
  fi

  flag=`echo "$tmp > $max" | bc -l`
  if test $flag -eq 1 ; then
    max=$tmp
  fi
  flag=`echo "$tmp < $min" | bc -l`
  if test $flag -eq 1 ; then
    min=$tmp
  fi
done
avg=`echo "$sum / $epoch" | bc -l`
echo "sum: $sum, epoch: $epoch"
echo "avg $avg"
echo "max: $max"
echo "min: $min"
thout=`echo "$thread - 1" | bc`
echo "$thout $avg $min $max" >> $result

for ((thread=4; thread<=24; thread+=4))
do
    sum=0
  echo "./cicada.exe $tuple $maxope $thread $workload $wal $group_commit $cpu_mhz $io_time_ns $group_commit_timeout_us $lock_release $extime"
  echo "$thread $epoch"
 
  max=0
  min=0 
    for ((i = 1; i <= epoch; ++i))
    do
        tmp=`./cicada.exe $tuple $maxope $thread $workload $wal $group_commit $cpu_mhz $io_time_ns $group_commit_timeout_us $lock_release $extime`
        sum=`echo "$sum + $tmp" | bc -l`
        echo "sum: $sum,   tmp: $tmp"

    if test $i -eq 1 ; then
      max=$tmp
      min=$tmp
    fi

    flag=`echo "$tmp > $max" | bc -l`
    if test $flag -eq 1 ; then
      max=$tmp
    fi
    flag=`echo "$tmp < $min" | bc -l`
    if test $flag -eq 1 ; then
      min=$tmp
    fi
    done
  avg=`echo "$sum / $epoch" | bc -l`
  echo "sum: $sum, epoch: $epoch"
  echo "avg $avg"
  echo "max: $max"
  echo "min: $min"
  thout=`echo "$thread - 1" | bc`
  echo "$thout $avg $min $max" >> $result
done

wal=S
result=result_cicada_r5_swal_tuple1m.dat
rm $result
echo "#worker thread, throughput, min, max" >> $result
echo "#./cicada.exe $tuple $maxope thread $workload $wal $group_commit $cpu_mhz $io_time_ns $group_commit_timeout_us $lock_release $extime" >> $result

thread=2
sum=0
echo "./cicada.exe $tuple $maxope $thread $workload $wal $group_commit $cpu_mhz $io_time_ns $group_commit_timeout_us $lock_release $extime"
echo "$thread $epoch"
max=0
min=0 
for ((i = 1; i <= epoch; ++i))
do
    tmp=`./cicada.exe $tuple $maxope $thread $workload $wal $group_commit $cpu_mhz $io_time_ns $group_commit_timeout_us $lock_release $extime`
    sum=`echo "$sum + $tmp" | bc -l`
    echo "sum: $sum,   tmp: $tmp"

  if test $i -eq 1 ; then
    max=$tmp
    min=$tmp
  fi

  flag=`echo "$tmp > $max" | bc -l`
  if test $flag -eq 1 ; then
    max=$tmp
  fi
  flag=`echo "$tmp < $min" | bc -l`
  if test $flag -eq 1 ; then
    min=$tmp
  fi
done
avg=`echo "$sum / $epoch" | bc -l`
echo "sum: $sum, epoch: $epoch"
echo "avg $avg"
echo "max: $max"
echo "min: $min"
thout=`echo "$thread - 1" | bc`
echo "$thout $avg $min $max" >> $result

for ((thread=4; thread<=24; thread+=4))
do
    sum=0
  echo "./cicada.exe $tuple $maxope $thread $workload $wal $group_commit $cpu_mhz $io_time_ns $group_commit_timeout_us $lock_release $extime"
  echo "$thread $epoch"
 
  max=0
  min=0 
    for ((i = 1; i <= epoch; ++i))
    do
        tmp=`./cicada.exe $tuple $maxope $thread $workload $wal $group_commit $cpu_mhz $io_time_ns $group_commit_timeout_us $lock_release $extime`
        sum=`echo "$sum + $tmp" | bc -l`
        echo "sum: $sum,   tmp: $tmp"

    if test $i -eq 1 ; then
      max=$tmp
      min=$tmp
    fi

    flag=`echo "$tmp > $max" | bc -l`
    if test $flag -eq 1 ; then
      max=$tmp
    fi
    flag=`echo "$tmp < $min" | bc -l`
    if test $flag -eq 1 ; then
      min=$tmp
    fi
    done
  avg=`echo "$sum / $epoch" | bc -l`
  echo "sum: $sum, epoch: $epoch"
  echo "avg $avg"
  echo "max: $max"
  echo "min: $min"
  thout=`echo "$thread - 1" | bc`
  echo "$thout $avg $min $max" >> $result
done

