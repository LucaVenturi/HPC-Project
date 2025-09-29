#!/bin/bash

BIN_DIR="bin"
DATASETS_DIR="datasets"
OUTPUT_CSV="csv/results_cuda3.csv"

EXECUTABLES=("cuda-skyline1.1" "cuda-skyline3") # Binari da testare

REPS=1  # Numero di ripetizioni da passare come parametro

make

# Header CSV
echo "Executable,Dataset,SkylinePoints,AvgTime_s" > "$OUTPUT_CSV"

# Ciclo sugli eseguibili
for ds in "$DATASETS_DIR"/*N1000000-*.in; do
    for exe in "${EXECUTABLES[@]}"; do
        BIN="$BIN_DIR/$exe"
        
        # Esegui il programma passando REPS come parametro
        output=$("$BIN" "$REPS" < "$ds" 2>&1)

        # Estrai numero di punti nello skyline
        skyline_points=$(echo "$output" | grep "points in skyline" | awk '{print $1}')

        # Estrai tempo medio (già calcolato dal programma)
        avg_time=$(echo "$output" | grep "Average execution time" | awk '{print $4}')

        # Mostra a video
        echo "$exe on $(basename "$ds") -> SkylinePoints: $skyline_points, AvgTime: $avg_time s"

        # Salva CSV
        echo "$exe,$(basename "$ds"),$skyline_points,$avg_time" >> "$OUTPUT_CSV"
    done
done

echo "Risultati salvati in $OUTPUT_CSV"








# #!/bin/bash

# BIN_DIR="bin"
# DATASETS_DIR="datasets"
# OUTPUT_CSV="csv/results_omp_DOPOBASTA.csv"

# EXECUTABLES=("omp-skyline1.3.2") # Binari da testare
# THREADS_LIST=(1 4)  # Numero di thread con cui testare

# make

# # Header CSV
# echo "Executable,Dataset,SkylinePoints,AvgTime_s,Threads,Reps" > "$OUTPUT_CSV"

# # Funzione per determinare il numero di ripetizioni
# get_reps() {
#     local dataset="$1"
#     local threads="$2"
    
#     # Estrai N e D dal nome del file
#     local N=$(echo "$dataset" | grep -oP 'N\K\d+' || echo "0")
#     local D=$(echo "$dataset" | grep -oP 'D\K\d+' || echo "0")
    
#     # Calcola un "peso" del dataset (N * D^2 per considerare l'impatto delle dimensioni)
#     local weight=$((N * D * D))
    
#     # Determina le ripetizioni in base al peso e ai thread
#     if [ "$threads" -eq 1 ]; then
#         # Con 1 thread tutto è più lento
#         if [ "$weight" -lt 1000000 ]; then      # Dataset piccoli (es. circle-N1000-D2)
#             echo 3
#         elif [ "$weight" -lt 10000000 ]; then  # Dataset medi (es. test1-N100000-D3)
#             echo 2
#         else                                   # Dataset grandi (es. test7-N100000-D200)
#             echo 1
#         fi
#     else
#         # Con 4 thread possiamo permetterci più ripetizioni
#         if [ "$weight" -lt 1000000 ]; then      # Dataset piccoli
#             echo 5
#         elif [ "$weight" -lt 10000000 ]; then  # Dataset medi
#             echo 3
#         elif [ "$weight" -lt 50000000 ]; then  # Dataset grandi
#             echo 2
#         else                                   # Dataset molto grandi (D=200, D=50)
#             echo 1
#         fi
#     fi
# }

# # Ciclo sui thread, poi sugli eseguibili e dataset
# for num_threads in "${THREADS_LIST[@]}"; do
#     echo "=== Testing with $num_threads threads ==="
    
#     for ds in "$DATASETS_DIR"/*.in; do
#         # Salta file che non sono dataset
#         if [[ "$(basename "$ds")" == "Makefile" ]] || [[ "$(basename "$ds")" == "README" ]]; then
#             continue
#         fi
        
#         # Determina il numero di ripetizioni per questo dataset e numero di thread
#         REPS=$(get_reps "$(basename "$ds")" "$num_threads")
        
#         echo "Dataset: $(basename "$ds") - Using $REPS repetitions with $num_threads threads"
        
#         for exe in "${EXECUTABLES[@]}"; do
#             BIN="$BIN_DIR/$exe"

#             # Esegui una sola volta passando REPS come parametro al programma
#             echo -n "  Running $REPS repetitions... "
#             output=$(OMP_NUM_THREADS=$num_threads "$BIN" "$REPS" < "$ds" 2>&1)

#             skyline_points=$(echo "$output" | grep "points in skyline" | awk '{print $1}')
#             avg_time=$(echo "$output" | grep "Average execution time" | awk '{print $4}')
#             echo "Avg Time: ${avg_time}s"

#             # Salva CSV
#             echo "$exe,$(basename "$ds"),$skyline_points,$avg_time,$num_threads,$REPS" >> "$OUTPUT_CSV"
#         done
#         echo ""
#     done
# done

# echo "Risultati multithread salvati in $OUTPUT_CSV"