/****************************************************************************
 * Progetto HPC 2024/25
 * Operatore Skyline CUDA versione extra, 2.
 * Luca Venturi
 * Matricola 0000978350
 *
 * Per compilare da dentro la cartella src:
 *
 *      make
 *          o
 *      make test
 *
 * Per eseguire il programma:
 *
 *      ./bin/cuda-skyline2 < input > output
 *          o
 *      ./bin/test_cuda-skyline2 [Numero ripetizioni] < input > output
 *
 * La versione di test esegue piu' volte il calcolo dello skyline e scrive
 * su stderr il tempo medio di esecuzione della funzione skyline.
 *
 ****************************************************************************/

#if _XOPEN_SOURCE < 600
#define _XOPEN_SOURCE 600
#endif

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

#include "hpc.h"

#include <cuda.h>

/*
    Numero di thread per blocco
    In questa versione si prende 32 perche' la griglia e' bidimensionale,
    quindi il numero di thread per blocco e' BLKDIM*BLKDIM = 1024
*/
#define BLKDIM 32

typedef struct
{
    float *P; /* coordinates P[i][j] of point i               */
    int N;    /* Number of points (rows of matrix P)          */
    int D;    /* Number of dimensions (columns of matrix P)   */
} points_t;

/**
 * Read input from stdin. Input format is:
 *
 * d [other ignored stuff]
 * N
 * p0,0 p0,1 ... p0,d-1
 * p1,0 p1,1 ... p1,d-1
 * ...
 * pn-1,0 pn-1,1 ... pn-1,d-1
 *
 */
void read_input(points_t *points)
{
    char buf[1024];
    int N, D;
    float *P;

    if (1 != scanf("%d", &D))
    {
        fprintf(stderr, "FATAL: can not read the dimension\n");
        exit(EXIT_FAILURE);
    }
    assert(D >= 2);
    if (NULL == fgets(buf, sizeof(buf), stdin))
    { /* ignore rest of the line */
        fprintf(stderr, "FATAL: can not read the first line\n");
        exit(EXIT_FAILURE);
    }
    if (1 != scanf("%d", &N))
    {
        fprintf(stderr, "FATAL: can not read the number of points\n");
        exit(EXIT_FAILURE);
    }
    P = (float *)malloc(D * N * sizeof(*P));
    assert(P);
    for (int i = 0; i < N; i++)
    {
        for (int k = 0; k < D; k++)
        {
            if (1 != scanf("%f", &(P[i * D + k])))
            {
                fprintf(stderr, "FATAL: failed to get coordinate %d of point %d\n", k, i);
                exit(EXIT_FAILURE);
            }
        }
    }
    points->P = P;
    points->N = N;
    points->D = D;
}

void free_points(points_t *points)
{
    free(points->P);
    points->P = NULL;
    points->N = points->D = -1;
}

/* Returns 1 iff |p| dominates |q| */
/* Ora e' una funzione __device__ perché deve essere eseguita sulla GPU  */
__device__ int dominates(const float *p, const float *q, int D)
{
    /* The following loops could be merged, but the keep them separated
       for the sake of readability */
    for (int k = 0; k < D; k++)
    {
        if (p[k] < q[k])
        {
            return 0;
        }
    }
    for (int k = 0; k < D; k++)
    {
        if (p[k] > q[k])
        {
            return 1;
        }
    }
    return 0;
}

/***
 * Kernel per il calcolo dello skyline
 * Ogni thread confronta una coppia di punti (i,j) e, se i
 * domina j, allora s[j] viene settato a 0 (cioe' j non e' nello skyline).
 * Usa atomicCAS per evitare contese sull'array s, 
 * alternativamente si potrebbe usare atomicExch.
 */
__global__ void kernel_skyline(const float *P, int *s, int N, int D)
{
    /* Il thread calcola gli indici i e j dei punti da confrontare */
    const int i = threadIdx.y + blockIdx.y * blockDim.y;
    const int j = threadIdx.x + blockIdx.x * blockDim.x;

    /* Se i domina j, allora s[j] = 0 */
    if (i < N && j < N && s[i] && s[j] && dominates(&(P[i * D]), &(P[j * D]), D))
    {
        atomicCAS(&s[j], 1, 0);
    }
}

/**
 * Compute the skyline of `points`. At the end, `s[i] == 1` iff point
 * `i` belongs to the skyline. The function returns the number `r` of
 * points that belongs to the skyline. The caller is responsible for
 * allocating the array `s` of length at least `points->N`.
 */
int skyline(const points_t *points, int *s)
{
    const int D = points->D;
    const int N = points->N;
    const float *P = points->P;
    int r = 0;

    /*
        Crea una griglia bidimensionale di blocchi,
        ciascuno con una matrice di thread BLKDIM x BLKDIM = 1024 thread
        NBLOCKS e' il numero di blocchi necessari per coprire tutti i punti
        con la griglia bidimensionale.
    */
    const int NBLOCKS = (N + BLKDIM - 1) / BLKDIM;
    const dim3 BLOCK(BLKDIM, BLKDIM);
    const dim3 GRID(NBLOCKS, NBLOCKS);

    /* Puntatori ai dati allocati sulla GPU. */
    float *d_P;
    int *d_s;

    /* Calcola le dimensioni in byte dei dati da allocare. */
    const size_t P_SIZE = sizeof(*d_P) * N * D;
    const size_t S_SIZE = sizeof(*d_s) * N;

    /* Alloca i dati sulla GPU */
    cudaSafeCall(cudaMalloc((void **)&d_P, P_SIZE));
    cudaSafeCall(cudaMalloc((void **)&d_s, S_SIZE));

    /* Inizializza l'array s: inizialmente tutti i punti sono nello skyline. */
    for (size_t i = 0; i < N; i++)
    {
        s[i] = 1;
    }

    /* Copia i dati dalla CPU alla GPU */
    cudaSafeCall(cudaMemcpy(d_P, P, P_SIZE, cudaMemcpyHostToDevice));
    cudaSafeCall(cudaMemcpy(d_s, s, S_SIZE, cudaMemcpyHostToDevice));

    /* Lancia il kernel per il calcolo dello skyline con la griglia bidimensionale. */
    kernel_skyline<<<GRID, BLOCK>>>(d_P, d_s, N, D);
    /* Controlla che il kernel sia terminato correttamente. */
    cudaSafeCall(cudaGetLastError());

    /* Copia i risultati dalla GPU alla CPU */
    cudaSafeCall(cudaMemcpy(s, d_s, S_SIZE, cudaMemcpyDeviceToHost));

    /* Conta il numero di punti nello skyline. */
    for (size_t i = 0; i < N; i++)
    {
        r += s[i];
    }

    /* Libera la memoria allocata sulla GPU. */
    cudaSafeCall(cudaFree(d_P));
    cudaSafeCall(cudaFree(d_s));

    return r;
}

/**
 * Print the coordinates of points belonging to the skyline `s` to
 * standard ouptut. `s[i] == 1` iff point `i` belongs to the skyline.
 * The output format is the same as the input format, so that this
 * program can process its own output.
 */
void print_skyline(const points_t *points, const int *s, int r)
{
    const int D = points->D;
    const int N = points->N;
    const float *P = points->P;

    printf("%d\n", D);
    printf("%d\n", r);
    for (int i = 0; i < N; i++)
    {
        if (s[i])
        {
            for (int k = 0; k < D; k++)
            {
                printf("%f ", P[i * D + k]);
            }
            printf("\n");
        }
    }
}

#ifdef TESTING

int main(int argc, char *argv[])
{
    points_t points;

    int repetitions = 1; // default

    if (argc > 1)
    {
        repetitions = atoi(argv[1]);
        if (repetitions <= 0)
            repetitions = 1;
    }

    read_input(&points);
    int *s = (int *)malloc(points.N * sizeof(*s));
    assert(s);

    int r;
    double *elapsed = (double *)malloc(sizeof(double) * repetitions);

    for (int i = 0; i < repetitions; i++)
    {
        const double tstart = hpc_gettime();
        r = skyline(&points, s);
        elapsed[i] = hpc_gettime() - tstart;
    }

    // calcola la media
    double avg = 0;
    for (int i = 0; i < repetitions; i++)
        avg += elapsed[i];
    avg /= repetitions;

    print_skyline(&points, s, r);

    fprintf(stderr, "\n\t%d points\n", points.N);
    fprintf(stderr, "\t%d dimensions\n", points.D);
    fprintf(stderr, "\t%d points in skyline\n\n", r);
    fprintf(stderr, "Average execution time:  %f (s)\n", avg);

    free(elapsed);
    free_points(&points);
    free(s);
    return EXIT_SUCCESS;
}

#else

int main(int argc, char *argv[])
{
    const double tstart0 = hpc_gettime();
    points_t points;

    if (argc != 1)
    {
        fprintf(stderr, "Usage: %s < input_file > output_file\n", argv[0]);
        return EXIT_FAILURE;
    }

    read_input(&points);
    int *s = (int *)malloc(points.N * sizeof(*s));
    assert(s);

    const double tstart = hpc_gettime();
    const int r = skyline(&points, s);
    const double elapsed = hpc_gettime() - tstart;
    print_skyline(&points, s, r);

    fprintf(stderr, "\n\t%d points\n", points.N);
    fprintf(stderr, "\t%d dimensions\n", points.D);
    fprintf(stderr, "\t%d points in skyline\n\n", r);
    fprintf(stderr, "Skyline function execution time (s) %f\n", elapsed);

    free_points(&points);
    free(s);
    const double elapsed0 = hpc_gettime() - tstart0;
    fprintf(stderr, "Total Execution time (s) %f\n", elapsed0);
    return EXIT_SUCCESS;
}

#endif
