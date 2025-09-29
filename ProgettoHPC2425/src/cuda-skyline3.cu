/****************************************************************************
 * Per compilare:
 *  
 *      make
 *      o
 *      make cuda
 *
 * Per eseguire il programma:
 *
 *      ./bin/cuda-skyline1 < input > output
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
    In questa versione si prende il massimo numero di thread per blocco
    perchè la griglia è monodimensionale.
*/
#define BLKDIM 1024

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
/* Ora è una funzione __device__ in quanto viene eseguita sulla GPU. */
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
 * Kernel per l'inizializzazione dell'array s
 * s: puntatore all'array di interi che indicano se il punto i-esimo è nello skyline allocato sulla GPU
 * N: numero di punti
 */
__global__ void kernel_init(int *s, int N)
{
    /* Il thread ottiene il suo indice */
    const int i = threadIdx.x + blockIdx.x * blockDim.x;

    if (i < N) {
        s[i] = 1; /* Inizializza l'array s: tutti i punti sono inizialmente nello skyline */
    }
}

/***
 * Kernel per il calcolo dello skyline sulla GPU
 * P: puntatore all'array delle coordinate dei punti allocato sulla GPU
 * s: puntatore all'array di interi che indicano se il punto i-esimo è nello skyline allocato sulla GPU
 * N: numero di punti
 * D: numero di dimensioni
 * Ogni thread confronta il punto i-esimo con tutti gli altri punti e rimuove dallo skyline
 * i punti dominati dal punto i-esimo.
 */
__global__ void kernel_skyline(const float *P, int *s, int N, int D)
{
    /* Il thread ottiene il suo indice */
    const int i = threadIdx.x + blockIdx.x * blockDim.x;

    /* Se il thread è associato ad un punto valido e tale punto è ancora nello skyline */
    if ( i < N && s[i] )
    {
        /* Confronta il punto i-esimo con tutti gli altri punti */
        for (int j = 0; j < N; j++)
        {
            /* Se il punto j-esimo è ancora nello skyline e il punto i-esimo lo domina, allora il punto j-esimo viene
            rimosso dallo skyline */
            if (s[j] && dominates(&(P[i * D]), &(P[j * D]), D))
            {
                atomicExch(&s[j], 0);
            }
        }
    }
}

/***
 * Kernel per il conteggio dei punti nello skyline
 * s: puntatore all'array di interi che indicano se il punto i-esimo è nello skyline allocato sulla GPU
 * N: numero di punti
 * r: puntatore alla variabile che conterrà il numero di punti nello skyline
 */
__global__ void kernel_count(int *s, int N, int *r)
{
    /* Il thread ottiene il suo indice */
    const int i = threadIdx.x + blockIdx.x * blockDim.x;
    __shared__ int shared_count_r[BLKDIM];

    /* Conta il numero di punti nello skyline */
    shared_count_r[threadIdx.x] = i < N && s[i] ? 1 : 0;
    __syncthreads();

    /* Riduzione per sommare i valori nell'array shared_count_r */
    for (int offset = blockDim.x / 2; offset > 0; offset /= 2)
    {
        if (threadIdx.x < offset)
        {
            shared_count_r[threadIdx.x] += shared_count_r[threadIdx.x + offset];
        }
        __syncthreads();
    }

    /* Il thread 0 del blocco aggiorna il contatore globale */
    if (threadIdx.x == 0)
    {
        atomicAdd(r, shared_count_r[0]);
    }
}

/**
 * Prepara i dati e lancia i kernel per il calcolo dello skyline.
 * Restituisce il numero di punti nello skyline e scrive nell'array `s`
 * quali punti appartengono allo skyline (`s[i] == 1` if point `i` belongs to the skyline).
 */
int skyline(const points_t *points, int *s)
{
    const int D = points->D;
    const int N = points->N;
    const float *P = points->P;
    int r = 0;

    /* Calcola il numero di blocchi necessari
    Per questa versione si prende BLMDIM massimo e si calcola il numero di blocchi conseguentemente.
    */
    const int NBLOCKS = (N + BLKDIM - 1) / BLKDIM;

    /* Puntatori ai dati allocati sulla GPU */
    float* d_P;
    int* d_s;
    int* d_r;

    /* Calcola le dimensioni in byte degli array */
    const size_t P_SIZE = sizeof(float) * N * D;
    const size_t S_SIZE = sizeof(int) * N;
    const size_t R_SIZE = sizeof(int);

    /* Alloca gli array sulla GPU*/
    cudaSafeCall( cudaMalloc(&d_P, P_SIZE) );
    cudaSafeCall( cudaMalloc(&d_s, S_SIZE) );
    cudaSafeCall( cudaMalloc(&d_r, sizeof(int)) );

    /* Copia gli array sulla GPU */
    cudaSafeCall( cudaMemcpy(d_P, P, P_SIZE, cudaMemcpyHostToDevice) );
    cudaSafeCall( cudaMemcpy(d_r, &r, R_SIZE, cudaMemcpyHostToDevice) );

    /* Kernel 1: Inizializzazione dell'array s */
    kernel_init<<<NBLOCKS, BLKDIM>>>(d_s, N);
    cudaSafeCall( cudaDeviceSynchronize() );  /* Sincronizza tutti i blocchi */

    /* Kernel 2: Calcolo dello skyline */
    kernel_skyline<<<NBLOCKS, BLKDIM>>>(d_P, d_s, N, D);
    cudaSafeCall( cudaDeviceSynchronize() );  /* Sincronizza tutti i blocchi */

    /* Kernel 3: Conteggio dei punti nello skyline */
    kernel_count<<<NBLOCKS, BLKDIM>>>(d_s, N, d_r);
    cudaSafeCall( cudaDeviceSynchronize() );  /* Sincronizza tutti i blocchi */

    /* Copia i risultati dalla GPU alla CPU */
    cudaSafeCall( cudaMemcpy(s, d_s, S_SIZE, cudaMemcpyDeviceToHost) );
    cudaSafeCall( cudaMemcpy(&r, d_r, R_SIZE, cudaMemcpyDeviceToHost) );

    /* Libera la memoria allocata sulla GPU */
    cudaSafeCall( cudaFree(d_P) );
    cudaSafeCall( cudaFree(d_s) );
    cudaSafeCall( cudaFree(d_r) );

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

int main(int argc, char* argv[])
{
    points_t points;

    int repetitions = 1;  // default

    if (argc > 1) {
        repetitions = atoi(argv[1]);
        if (repetitions <= 0) repetitions = 1;
    }

    read_input(&points);
    int *s = (int*)malloc(points.N * sizeof(*s));
    assert(s);

    int r;
    double *elapsed = (double*)malloc(sizeof(double) * repetitions);

    for (int i = 0; i < repetitions; i++) {
        const double tstart = hpc_gettime();
        r = skyline(&points, s);
        elapsed[i] = hpc_gettime() - tstart;
    }

    // calcola la media
    double avg = 0;
    for (int i = 0; i < repetitions; i++) avg += elapsed[i];
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