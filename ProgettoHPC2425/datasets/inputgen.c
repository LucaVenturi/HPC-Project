/****************************************************************************
 *
 * inputgen.c
 *
 * Worst-case input generator for skyline
 *
 * Copyright (C) 2024 Moreno Marzolla
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * --------------------------------------------------------------------------
 *
 * Questo file genera il caso pessimo per l'algoritmo skyline, ossia un
 * insieme di N punti in D dimensioni che fanno tutti parte dello skyline.
 *
 * Per compilare:
 *
 *      gcc -std=c99 -Wall -Wpedantic inputgen.c -o inputgen
 *
 * Per eseguire:
 *
 *      ./inputgen [N [D]] > output
 *
 * Esempio:
 *
 *      ./inputgen 10000 10 > worst.in
 *
 ****************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/**
 * Returns a random number in the range [a, b]
 */
float randab(float a, float b)
{
    return a + (rand() / (float) RAND_MAX)*(b-a);
}

/*
 * This program generates a worst-case input for the skyline
 * operation, i.e., a dataset where every point belongs to the
 * skyline. In 2D this dataset appears like this:
 *
 * ^
 * |.
 * |  .
 * |    .
 * |      .
 * |        .
 * +----------->
 *
 */
int main( int argc, char *argv[] )
{
    int n = 1000;
    int d = 2;
    int i;

    if ( argc > 3 ) {
        fprintf(stderr, "Usage: %s [N [D]]\n", argv[0]);
        return EXIT_FAILURE;
    }

    if (argc > 1) {
         n = atoi(argv[1]);
    }

    if (argc > 2) {
        d = atoi(argv[2]);
    }

    printf("%d\n%d\n", d, n);
    for (i=0; i<n; i++) {
        /* generate d random numbers whose sum is ub */
        float ub = 1000.0; /* upper bound */
        int k;
        for (k=0; k<d; k++) {
            const float v = (k == d-1 ? ub : randab(0.0, ub));
            printf("%f ", v);
            ub -= v;
        }
        printf("\n");
    }
    return EXIT_SUCCESS;
}
