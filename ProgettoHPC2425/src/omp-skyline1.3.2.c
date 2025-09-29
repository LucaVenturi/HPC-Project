/****************************************************************************
 * Progetto HPC 2024/25
 * Operatore Skyline CUDA versione 2
 * Luca Venturi 
 * Matricola 0000978350
 * 
 * Per compilare:
 *  
 *      make
 *          o
 *      make test
 *
 * Per eseguire il programma:
 *
 *      ./bin/cuda-skyline1 < input > output
 *          o
 *      ./bin/test_cuda-skyline1 [Numero ripetizioni] < input > output
 * 
 * La versione di test esegue più volte il calcolo dello skyline e scrive
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

typedef struct {
    float *P;   /* coordinates P[i][j] of point i               */
    int N;      /* Number of points (rows of matrix P)          */
    int D;      /* Number of dimensions (columns of matrix P)   */
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
void read_input( points_t *points )
{
    char buf[1024];
    int N, D;
    float *P;

    if (1 != scanf("%d", &D)) {
        fprintf(stderr, "FATAL: can not read the dimension\n");
        exit(EXIT_FAILURE);
    }
    assert(D >= 2);
    if (NULL == fgets(buf, sizeof(buf), stdin)) { /* ignore rest of the line */
        fprintf(stderr, "FATAL: can not read the first line\n");
        exit(EXIT_FAILURE);
    }
    if (1 != scanf("%d", &N)) {
        fprintf(stderr, "FATAL: can not read the number of points\n");
        exit(EXIT_FAILURE);
    }
    P = (float*)malloc( D * N * sizeof(*P) );
    assert(P);
    for (int i=0; i<N; i++) {
        for (int k=0; k<D; k++) {
            if (1 != scanf("%f", &(P[i*D + k]))) {
                fprintf(stderr, "FATAL: failed to get coordinate %d of point %d\n", k, i);
                exit(EXIT_FAILURE);
            }
        }
    }
    points->P = P;
    points->N = N;
    points->D = D;
}

void free_points( points_t* points )
{
    free(points->P);
    points->P = NULL;
    points->N = points->D = -1;
}

/* Returns 1 iff |p| dominates |q| */
int dominates( const float * p, const float * q, int D )
{
    /* The following loops could be merged, but the keep them separated
       for the sake of readability */
    for (int k=0; k<D; k++) {
        if (p[k] < q[k]) {
            return 0;
        }
    }
    for (int k=0; k<D; k++) {
        if (p[k] > q[k]) {
            return 1;
        }
    }
    return 0;
}

/**
 * Compute the skyline of `points`. At the end, `s[i] == 1` iff point
 * `i` belongs to the skyline. The function returns the number `r` of
 * points that belongs to the skyline. The caller is responsible for
 * allocating the array `s` of length at least `points->N`.
 */
int skyline( const points_t *points, int *s )
{
    const int D = points->D;
    const int N = points->N;
    const float *P = points->P;
    int r = N;

    #pragma omp parallel
    {
        #pragma omp for
        for (int i=0; i<N; i++) {
            s[i] = 1;
        }
        // schedule(guided, 32)
        #pragma omp for schedule(dynamic, 64)
        for (int i=0; i<N; i++) {
            if ( s[i] ) {
                for (int j=0; j<N; j++) {
                    if ( s[j] && dominates( &(P[i*D]), &(P[j*D]), D ) ) {
                        #pragma omp critical
                        {
                            if (s[j])
                            {
                                s[j] = 0;
                                r--;
                            }
                        }
                    }
                }
            }
        }
    }

    return r;
}

/**
 * Print the coordinates of points belonging to the skyline `s` to
 * standard ouptut. `s[i] == 1` iff point `i` belongs to the skyline.
 * The output format is the same as the input format, so that this
 * program can process its own output.
 */
void print_skyline( const points_t* points, const int *s, int r )
{
    const int D = points->D;
    const int N = points->N;
    const float *P = points->P;

    printf("%d\n", D);
    printf("%d\n", r);
    for (int i=0; i<N; i++) {
        if ( s[i] ) {
            for (int k=0; k<D; k++) {
                printf("%f ", P[i*D + k]);
            }
            printf("\n");
        }
    }
}

#ifdef TESTING

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

#else

int main( int argc, char* argv[] )
{
    const double tstart0 = hpc_gettime();
    points_t points;

    if (argc != 1) {
        fprintf(stderr, "Usage: %s < input_file > output_file\n", argv[0]);
        return EXIT_FAILURE;
    }

    read_input(&points);
    int *s = (int*)malloc(points.N * sizeof(*s));
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
