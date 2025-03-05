#!/bin/bash

# Controlla che sia stato passato un file di dataset come parametro
if [[ $# -ne 1 ]]; then
    echo "Utilizzo: $0 <dataset_file>"
    exit 1
fi

# File di input passato come parametro
INPUT_FILE=$1

# Verifica che il file di input esista
if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Errore: Il file di input '$INPUT_FILE' non esiste."
    exit 1
fi

# Directory dei file binari
BIN_DIR="./bin"
# Directory dei file di output
OUTPUTS_DIR="./outputs"
# File di log per i risultati
RESULTS_LOG="results.log"

# Pulisce il file di log precedente
> "$RESULTS_LOG"

# Crea la directory dei risultati se non esiste
mkdir -p "$OUTPUTS_DIR"

# Nome base del file di input (senza percorso e senza estensione)
input_name=$(basename "$INPUT_FILE" .in)

# Itera attraverso tutti i file eseguibili che iniziano con "test_"
for test_exec in "$BIN_DIR"/test_*; do
    if [[ -x "$test_exec" ]]; then
        # Ottieni il suffisso dal nome del file eseguibile (es: _cuda2, _omp2)
        suffix=$(basename "$test_exec" | sed 's/test_//')

        # Nome del file di output
        output_file="$OUTPUTS_DIR/${input_name}__${suffix}.out"

        # Scrive una separazione nel file di log
        echo "========================================" >> "$RESULTS_LOG"
        echo "Eseguendo: $test_exec" >> "$RESULTS_LOG"
        echo "Output file: $output_file" >> "$RESULTS_LOG"

        # Esecuzione del file di test
        echo "Eseguendo: $test_exec < $INPUT_FILE > $output_file"
        "$test_exec" < "$INPUT_FILE" > "$output_file" 2>>"$RESULTS_LOG"
    else
        echo "Saltato (non eseguibile): $test_exec"
    fi
done

# Messaggio di completamento
echo "Esecuzione completata. I risultati sono stati salvati in $RESULTS_LOG."