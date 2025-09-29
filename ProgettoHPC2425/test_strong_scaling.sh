#!/bin/bash
# Strong scaling: stesso dataset, vario numero di thread.
# Passa il numero di ripetizioni al programma (REPS).
# Assumiamo che il binario accetti come primo argomento il numero di ripetizioni:
#    ./bin/test_omp-skyline1 REPS < input.in

BIN="bin/omp-skyline1.3.2"
DATASET="datasets/test3-N100000-D10.in"
OUTPUT="csv/strong_scaling_omp1.3.2.csv"

echo "Threads,N,D,K,Reps,Time_s" > "$OUTPUT"

for t in 1 2 3 4; do
    if [ "$t" -eq 1 ]; then
        REPS=3
    else
        REPS=10
    fi

    export OMP_NUM_THREADS=$t
    output=$("$BIN" "$REPS" < "$DATASET" 2>&1)

    time=$(echo "$output" | grep "Average execution time" | awk '{print $4}')
    N=$(echo "$output" | grep "points$" | awk '{print $1}')
    D=$(echo "$output" | grep "dimensions" | awk '{print $1}')
    K=$(echo "$output" | grep "points in skyline" | awk '{print $1}')

    echo "$t,$N,$D,$K,$REPS,$time" >> "$OUTPUT"
    echo "Threads=$t, N=$N, D=$D, K=$K, Reps=$REPS -> Time=$time"
done

echo "Strong scaling results saved in $OUTPUT"
