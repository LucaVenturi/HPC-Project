#!/bin/bash
# Weak scaling: aumenta N proporzionalmente alla radice quadrata dei thread (BASE_N * sqrt(t))
# per mantenere costante il carico di lavoro O(N²) per thread

BIN="bin/omp-skyline1.3.2"
OUTPUT="csv/weak_scaling_omp1.3.2.csv"

echo "Threads,N,D,K,Reps,Time_s" > "$OUTPUT"

BASE_N=100000
D=10
REPS=3

for t in 1 2 3 4; do
    # Calcola N = BASE_N * sqrt(t)
    # Usa awk per calcolare la radice quadrata con precisione
    N=$(awk "BEGIN {printf \"%.0f\", $BASE_N * sqrt($t)}")
    
    DATASET="datasets/test3-N${N}-D${D}.in"

    if [ ! -f "$DATASET" ]; then
        echo "Dataset $DATASET non trovato, salto..."
        continue
    fi

    # if [ "$t" -eq 1 ]; then
    #     REPS=3
    # else
    #     REPS=10
    # fi

    export OMP_NUM_THREADS=$t
    output=$("$BIN" "$REPS" < "$DATASET" 2>&1)

    time=$(echo "$output" | grep "Average execution time" | awk '{print $4}')
    K=$(echo "$output" | grep "points in skyline" | awk '{print $1}')

    echo "$t,$N,$D,$K,$REPS,$time" >> "$OUTPUT"
    echo "Threads=$t, N=$N, D=$D, K=$K, Reps=$REPS -> Time=$time"
done

echo "Weak scaling results saved in $OUTPUT"