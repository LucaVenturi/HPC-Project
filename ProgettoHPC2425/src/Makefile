# Makefile per il progetto HPC 2024/25
# Luca Venturi, matricola 0000978350

# Si possono compilare i programmi OpenMP, MPI, CUDA e seriali.
# Per compilare, da dentro la cartella src:
#    make
# oppure
#    make test
# E' una versione modificata del Makefile fornito per il progetto
# che ora compila dentro alla cartella ../bin
# e può compilare i programmi con il flag -DTESTING per raccogliere dati
# con il comando "make test".


BINDIR:=../bin

EXE_OMP:=$(basename $(wildcard omp-*.c))
EXE_MPI:=$(basename $(wildcard mpi-*.c))
EXE_CUDA:=$(basename $(wildcard cuda-*.cu))
EXE_SERIAL:=skyline

# eseguibili normali
EXE_OMP_BIN:=$(addprefix $(BINDIR)/,$(EXE_OMP))
EXE_MPI_BIN:=$(addprefix $(BINDIR)/,$(EXE_MPI))
EXE_CUDA_BIN:=$(addprefix $(BINDIR)/,$(EXE_CUDA))
EXE_SERIAL_BIN:=$(addprefix $(BINDIR)/,$(EXE_SERIAL))
EXE:=$(EXE_OMP_BIN) $(EXE_MPI_BIN) $(EXE_SERIAL_BIN) $(EXE_CUDA_BIN)

# eseguibili di test
EXE_OMP_TEST:=$(addprefix $(BINDIR)/test_,$(EXE_OMP))
EXE_MPI_TEST:=$(addprefix $(BINDIR)/test_,$(EXE_MPI))
EXE_CUDA_TEST:=$(addprefix $(BINDIR)/test_,$(EXE_CUDA))
EXE_SERIAL_TEST:=$(addprefix $(BINDIR)/test_,$(EXE_SERIAL))
EXE_TEST:=$(EXE_OMP_TEST) $(EXE_MPI_TEST) $(EXE_SERIAL_TEST) $(EXE_CUDA_TEST)

CFLAGS+=-std=c99 -Wall -Wpedantic -O2 -D_XOPEN_SOURCE=600
LDLIBS+=-lm
NVCC:=nvcc
NVCFLAGS+=-Wno-deprecated-gpu-targets
NVLDLIBS+=-lm

.PHONY: clean test openmp mpi cuda all

ALL: $(EXE)

# crea la cartella bin se non esiste
$(BINDIR):
	mkdir -p $(BINDIR)

# regola generica per .cu
$(BINDIR)/% : %.cu | $(BINDIR)
	$(NVCC) $(NVCFLAGS) $< -o $@ $(NVLDLIBS)

# regola generica per .c
$(BINDIR)/% : %.c | $(BINDIR)
	$(CC) $(CFLAGS) $< -o $@ $(LDLIBS)

# OpenMP
$(EXE_OMP_BIN): CFLAGS+=-fopenmp
openmp: $(EXE_OMP_BIN)

# MPI
$(EXE_MPI_BIN): CC=mpicc
mpi: $(EXE_MPI_BIN)

# CUDA
cuda: $(EXE_CUDA_BIN)


# --- Target test ---

# Compila gli eseguibili di con il flag -DTESTING
# test per .cu
$(BINDIR)/test_% : %.cu | $(BINDIR)
	$(NVCC) $(NVCFLAGS) -DTESTING $< -o $@ $(NVLDLIBS)

# test per .c
$(BINDIR)/test_% : %.c | $(BINDIR)
	$(CC) $(CFLAGS) -DTESTING $< -o $@ $(LDLIBS)

# OpenMP di test
$(EXE_OMP_TEST): CFLAGS+=-fopenmp
# MPI di test
$(EXE_MPI_TEST): CC=mpicc

test: $(EXE_TEST)

# clean
clean:
	\rm -f $(BINDIR)/* *.o *~
