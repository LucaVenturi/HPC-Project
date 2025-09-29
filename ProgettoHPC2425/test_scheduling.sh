#!/bin/bash
# Test OpenMP scheduling e chunk size
# Sempre tutti i thread disponibili, dataset fisso

BIN="bin/omp-skyline1.3.2"
OUTPUT="scheduling_test_omp1.3.2_piccolo.csv"

echo "Threads,N,D,K,Reps,Schedule,Chunk,Time_s" > "$OUTPUT"

REPS=5
DATASET="datasets/test3-N100000-D10.in"

if [ ! -f "$DATASET" ]; then
    echo "Dataset $DATASET non trovato, esco..."
    exit 1
fi

# Numero di thread da usare (tutti)
THREADS=$(nproc)  # oppure scegli un numero fisso, es. 4

# Tipi di scheduling e chunk size da testare
# SCHEDULES=("static" "dynamic" "guided")
# CHUNKS=(1 8 32 64 128)

SCHEDULES=("dynamic" "guided")
CHUNKS=(16 32 64 128)

export OMP_NUM_THREADS=$THREADS

for sched in "${SCHEDULES[@]}"; do
    for chunk in "${CHUNKS[@]}"; do
        export OMP_SCHEDULE="${sched},${chunk}"
        echo "Testing schedule=$sched, chunk=$chunk with $THREADS threads..."
        
        output=$("$BIN" "$REPS" < "$DATASET" 2>&1)
        
        time=$(echo "$output" | grep "Average execution time" | awk '{print $4}')
        N=$(echo "$output" | grep "points$" | awk '{print $1}')
        D=$(echo "$output" | grep "dimensions" | awk '{print $1}')
        K=$(echo "$output" | grep "points in skyline" | awk '{print $1}')
        
        echo "$THREADS,$N,$D,$K,$REPS,$sched,$chunk,$time" >> "$OUTPUT"
        echo "Schedule=$sched, Chunk=$chunk -> Time=$time s"
    done
done

echo "Scheduling test results saved in $OUTPUT"
