## Makefile di esempio per il progetto di High Performance Computing
## 2024/2025, corso di laurea in Ingegneria e Scienze Informatiche,
## Universita' di Bologna.

SRC_DIR := ./src
BIN_DIR := ./bin

EXE_OMP := $(addprefix $(BIN_DIR)/, $(basename $(notdir $(wildcard $(SRC_DIR)/omp-*.c))))
EXE_MPI := $(addprefix $(BIN_DIR)/, $(basename $(notdir $(wildcard $(SRC_DIR)/mpi-*.c))))
EXE_CUDA := $(addprefix $(BIN_DIR)/, $(basename $(notdir $(wildcard $(SRC_DIR)/cuda-*.cu))))
EXE_SERIAL := $(BIN_DIR)/skyline
EXE := $(EXE_OMP) $(EXE_MPI) $(EXE_SERIAL) $(EXE_CUDA)

CFLAGS += -std=c99 -Wall -Wpedantic -O2 -D_XOPEN_SOURCE=600
LDLIBS += -lm
NVCC := nvcc
NVCFLAGS += -Wno-deprecated-gpu-targets
NVLDLIBS += -lm

.PHONY: clean test openmp mpi cuda

ALL: $(EXE)

# Regole per compilare i file CUDA
$(BIN_DIR)/% : $(SRC_DIR)/%.cu
	@mkdir -p $(BIN_DIR)
	$(NVCC) $(NVCFLAGS) $< -o $@ $(NVLDLIBS)

# Regole per compilare i file C
$(BIN_DIR)/% : $(SRC_DIR)/%.c
	@mkdir -p $(BIN_DIR)
	$(CC) $(CFLAGS) $< -o $@ $(LDLIBS)

# Aggiunge il flag OpenMP ai file omp-*.c
$(EXE_OMP): CFLAGS += -fopenmp
openmp: $(EXE_OMP)

# Usa mpicc per i file mpi-*.c
$(EXE_MPI): CC = mpicc
mpi: $(EXE_MPI)

# Target per CUDA
cuda: $(EXE_CUDA)

# Pulizia
clean:
	\rm -f $(EXE) $(BIN_DIR)/*.o $(BIN_DIR)/*~

# Regole per il testing
TEST_CFLAGS = $(CFLAGS) -DTESTING
TEST_NVCFLAGS = $(NVCFLAGS) -DTESTING

test: $(patsubst $(BIN_DIR)/%, $(BIN_DIR)/test_%, $(EXE))

$(BIN_DIR)/test_% : $(SRC_DIR)/%.cu
	@mkdir -p $(BIN_DIR)
	$(NVCC) $(TEST_NVCFLAGS) $< -o $@ $(NVLDLIBS)

$(BIN_DIR)/test_% : $(SRC_DIR)/%.c
	@mkdir -p $(BIN_DIR)
	$(CC) $(TEST_CFLAGS) $< -o $@ $(LDLIBS)
