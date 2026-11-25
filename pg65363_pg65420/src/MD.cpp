/*
 MD.cpp - OpenMP parallelized and optimized molecular dynamics simulation
 Based on FoleyLab/Molecular Dynamics (GPLv3)
*/
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include <omp.h>

// Number of particles
int N;

// Lennard-Jones parameters in natural units
double sigma = 1.;
double epsilon = 1.;
double m = 1.;
double kB = 1.;

double NA = 6.022140857e23;
double kBSI = 1.38064852e-23;  // m^2*kg/(s^2*K)

// Size of box in natural units
double L;

// Initial Temperature in Natural Units
double Tinit;

const int MAXPART = 5001;
// Padding to multiple of 8 doubles (64 bytes = 1 cache line / SVE vector)
const int STRIDE = ((MAXPART + 7) / 8) * 8;

// Structure of Arrays (SoA) aligned to 64 bytes for SIMD vectorization
alignas(64) double rx[STRIDE], ry[STRIDE], rz[STRIDE];
alignas(64) double vx[STRIDE], vy[STRIDE], vz[STRIDE];
alignas(64) double ax[STRIDE], ay[STRIDE], az[STRIDE];

// Thread-private acceleration buffers (allocated once)
static double *ax_priv = nullptr;
static double *ay_priv = nullptr;
static double *az_priv = nullptr;
static int alloc_threads = 0;

// Cached potential energy computed simultaneously with accelerations
static double current_PE = 0.0;

// atom type
char atype[10];

// Function prototypes
void initialize();
double VelocityVerlet(double dt, int iter, FILE *fp);
void computeAccelerations();
double gaussdist();
void initializeVelocities();
double Potential();
double MeanSquaredVelocity();
double Kinetic();

static void ensureThreadBuffers() {
    int max_t = omp_get_max_threads();
    if (max_t > alloc_threads) {
        free(ax_priv);
        free(ay_priv);
        free(az_priv);
        size_t bytes = (size_t)max_t * (size_t)STRIDE * sizeof(double);
        ax_priv = (double *)aligned_alloc(64, bytes);
        ay_priv = (double *)aligned_alloc(64, bytes);
        az_priv = (double *)aligned_alloc(64, bytes);
        if (!ax_priv || !ay_priv || !az_priv) {
            fprintf(stderr, "Error allocating thread-private buffers\n");
            exit(1);
        }
        alloc_threads = max_t;
    }
}

int main()
{
    int i;
    double dt, Vol, Temp, Press, Pavg, Tavg, rho;
    double VolFac, TempFac, PressFac, timefac;
    double KE, PE, mvs, gc, Z;
    char prefix[1000], tfn[1000], ofn[1000], afn[1000];
    FILE *tfp, *ofp, *afp;

    printf("\n  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n");
    printf("                  WELCOME TO WILLY P CHEM MD!\n");
    printf("  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n");
    printf("\n  ENTER A TITLE FOR YOUR CALCULATION!\n");
    scanf("%s", prefix);
    strcpy(tfn, prefix);
    strcat(tfn, "_traj.xyz");
    strcpy(ofn, prefix);
    strcat(ofn, "_output.txt");
    strcpy(afn, prefix);
    strcat(afn, "_average.txt");

    printf("\n  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n");
    printf("                  TITLE ENTERED AS '%s'\n", prefix);
    printf("  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n");

    printf("\n  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n");
    printf("  WHICH NOBLE GAS WOULD YOU LIKE TO SIMULATE? (DEFAULT IS ARGON)\n");
    printf("\n  FOR HELIUM,  TYPE 'He' THEN PRESS 'return' TO CONTINUE\n");
    printf("  FOR NEON,    TYPE 'Ne' THEN PRESS 'return' TO CONTINUE\n");
    printf("  FOR ARGON,   TYPE 'Ar' THEN PRESS 'return' TO CONTINUE\n");
    printf("  FOR KRYPTON, TYPE 'Kr' THEN PRESS 'return' TO CONTINUE\n");
    printf("  FOR XENON,   TYPE 'Xe' THEN PRESS 'return' TO CONTINUE\n");
    printf("  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n");
    scanf("%s", atype);

    if (strcmp(atype, "He") == 0) {
        VolFac = 1.8399744000000005e-29;
        PressFac = 8152287.336171632;
        TempFac = 10.864459551225972;
        timefac = 1.7572698825166272e-12;
    } else if (strcmp(atype, "Ne") == 0) {
        VolFac = 2.0570823999999997e-29;
        PressFac = 27223022.27659913;
        TempFac = 40.560648991243625;
        timefac = 2.1192341945685407e-12;
    } else if (strcmp(atype, "Ar") == 0) {
        VolFac = 3.7949992920124995e-29;
        PressFac = 51695201.06691862;
        TempFac = 142.0950000000000;
        timefac = 2.09618e-12;
    } else if (strcmp(atype, "Kr") == 0) {
        VolFac = 4.5882712000000004e-29;
        PressFac = 59935428.40275003;
        TempFac = 199.1817584391428;
        timefac = 8.051563913585078e-13;
    } else if (strcmp(atype, "Xe") == 0) {
        VolFac = 5.4872e-29;
        PressFac = 70527773.72794868;
        TempFac = 280.30305642163006;
        timefac = 9.018957925790732e-13;
    } else {
        VolFac = 3.7949992920124995e-29;
        PressFac = 51695201.06691862;
        TempFac = 142.0950000000000;
        timefac = 2.09618e-12;
        strcpy(atype, "Ar");
    }

    printf("\n  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n");
    printf("\n                     YOU ARE SIMULATING %s GAS! \n", atype);
    printf("\n  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n");
    printf("\n  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n");
    printf("\n  YOU WILL NOW ENTER A FEW SIMULATION PARAMETERS\n");
    printf("  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n");
    printf("\n\n  ENTER THE INTIAL TEMPERATURE OF YOUR GAS IN KELVIN\n");
    scanf("%lf", &Tinit);
    if (Tinit < 0.) {
        printf("\n  !!!!! ABSOLUTE TEMPERATURE MUST BE A POSITIVE NUMBER!  PLEASE TRY AGAIN WITH A POSITIVE TEMPERATURE!!!\n");
        exit(0);
    }
    Tinit /= TempFac;

    printf("\n\n  ENTER THE NUMBER DENSITY IN moles/m^3\n");
    printf("  FOR REFERENCE, NUMBER DENSITY OF AN IDEAL GAS AT STP IS ABOUT 40 moles/m^3\n");
    printf("  NUMBER DENSITY OF LIQUID ARGON AT 1 ATM AND 87 K IS ABOUT 35000 moles/m^3\n");
    scanf("%lf", &rho);

    N = 5000;
    Vol = N / (rho * NA);
    Vol /= VolFac;

    if (N >= MAXPART) {
        printf("\n\n\n  MAXIMUM NUMBER OF PARTICLES IS %i\n\n  PLEASE ADJUST YOUR INPUT FILE ACCORDINGLY \n\n", MAXPART);
        exit(0);
    }
    if (Vol < N) {
        printf("\n\n\n  YOUR DENSITY IS VERY HIGH!\n\n");
        printf("  THE NUMBER OF PARTICLES IS %i AND THE AVAILABLE VOLUME IS %f NATURAL UNITS\n", N, Vol);
        printf("  SIMULATIONS WITH DENSITY GREATER THAN 1 PARTCICLE/(1 Natural Unit of Volume) MAY DIVERGE\n");
        printf("  PLEASE ADJUST YOUR INPUT FILE ACCORDINGLY AND RETRY\n\n");
        exit(0);
    }

    L = pow(Vol, (1. / 3));

    tfp = fopen(tfn, "w");
    ofp = fopen(ofn, "w");
    afp = fopen(afn, "w");

    int NumTime;
    if (strcmp(atype, "He") == 0) {
        dt = 0.2e-14 / timefac;
        NumTime = 50000;
    } else {
        dt = 0.5e-14 / timefac;
        NumTime = 200;
    }

    ensureThreadBuffers();
    initialize();
    computeAccelerations();

    fprintf(tfp, "%i\n", N);

    Pavg = 0;
    Tavg = 0;

    int tenp = floor(NumTime / 10);
    fprintf(ofp, "  time (s)              T(t) (K)              P(t) (Pa)           Kinetic En. (n.u.)     Potential En. (n.u.) Total En. (n.u.)\n");
    printf("  PERCENTAGE OF CALCULATION COMPLETE:\n  [");

    for (i = 0; i < NumTime + 1; i++) {
        if (i == tenp) printf(" 10 |");
        else if (i == 2 * tenp) printf(" 20 |");
        else if (i == 3 * tenp) printf(" 30 |");
        else if (i == 4 * tenp) printf(" 40 |");
        else if (i == 5 * tenp) printf(" 50 |");
        else if (i == 6 * tenp) printf(" 60 |");
        else if (i == 7 * tenp) printf(" 70 |");
        else if (i == 8 * tenp) printf(" 80 |");
        else if (i == 9 * tenp) printf(" 90 |");
        else if (i == 10 * tenp) printf(" 100 ]\n");
        fflush(stdout);

        Press = VelocityVerlet(dt, i + 1, tfp);
        Press *= PressFac;

        mvs = MeanSquaredVelocity();
        KE = Kinetic();
        PE = Potential();

        Temp = m * mvs / (3 * kB) * TempFac;
        gc = NA * Press * (Vol * VolFac) / (N * Temp);
        Z = Press * (Vol * VolFac) / (N * kBSI * Temp);

        Tavg += Temp;
        Pavg += Press;

        fprintf(ofp, "  %8.4e  %20.8f  %20.8f %20.8f  %20.8f  %20.8f \n", i * dt * timefac, Temp, Press, KE, PE, KE + PE);
    }

    Pavg /= NumTime;
    Tavg /= NumTime;
    Z = Pavg * (Vol * VolFac) / (N * kBSI * Tavg);
    gc = NA * Pavg * (Vol * VolFac) / (N * Tavg);
    fprintf(afp, "  Total Time (s)      T (K)               P (Pa)      PV/nT (J/(mol K))         Z           V (m^3)              N\n");
    fprintf(afp, " --------------   -----------        ---------------   --------------   ---------------   ------------   -----------\n");
    fprintf(afp, "  %8.4e  %15.5f       %15.5f     %10.5f       %10.5f        %10.5e         %i\n", i * dt * timefac, Tavg, Pavg, gc, Z, Vol * VolFac, N);

    printf("\n  TO ANIMATE YOUR SIMULATION, OPEN THE FILE \n  '%s' WITH VMD AFTER THE SIMULATION COMPLETES\n", tfn);
    printf("\n  TO ANALYZE INSTANTANEOUS DATA ABOUT YOUR MOLECULE, OPEN THE FILE \n  '%s' WITH YOUR FAVORITE TEXT EDITOR OR IMPORT THE DATA INTO EXCEL\n", ofn);
    printf("\n  THE FOLLOWING THERMODYNAMIC AVERAGES WILL BE COMPUTED AND WRITTEN TO THE FILE  \n  '%s':\n", afn);
    printf("\n  AVERAGE TEMPERATURE (K):                 %15.5f\n", Tavg);
    printf("\n  AVERAGE PRESSURE  (Pa):                  %15.5f\n", Pavg);
    printf("\n  PV/nT (J * mol^-1 K^-1):                 %15.5f\n", gc);
    printf("\n  PERCENT ERROR of pV/nT AND GAS CONSTANT: %15.5f\n", 100 * fabs(gc - 8.3144598) / 8.3144598);
    printf("\n  THE COMPRESSIBILITY (unitless):          %15.5f \n", Z);
    printf("\n  TOTAL VOLUME (m^3):                      %10.5e \n", Vol * VolFac);
    printf("\n  NUMBER OF PARTICLES (unitless):          %i \n", N);

    fclose(tfp);
    fclose(ofp);
    fclose(afp);

    free(ax_priv);
    free(ay_priv);
    free(az_priv);

    return 0;
}

void initialize() {
    int n = int(ceil(pow(N, 1.0 / 3)));
    double pos = L / n;
    int p = 0;

    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) {
            for (int k = 0; k < n; k++) {
                if (p < N) {
                    rx[p] = (i + 0.5) * pos;
                    ry[p] = (j + 0.5) * pos;
                    rz[p] = (k + 0.5) * pos;
                }
                p++;
            }
        }
    }
    initializeVelocities();
}

double MeanSquaredVelocity() {
    double vx2 = 0.0, vy2 = 0.0, vz2 = 0.0;
    for (int i = 0; i < N; i++) {
        vx2 += vx[i] * vx[i];
        vy2 += vy[i] * vy[i];
        vz2 += vz[i] * vz[i];
    }
    return (vx2 + vy2 + vz2) / N;
}

double Kinetic() {
    double kin = 0.0;
    for (int i = 0; i < N; i++) {
        double v2 = vx[i] * vx[i] + vy[i] * vy[i] + vz[i] * vz[i];
        kin += m * v2 * 0.5;
    }
    return kin;
}

// Potential energy is computed simultaneously inside computeAccelerations()
// since positions r are unchanged between computeAccelerations() and Potential()
double Potential() {
    return current_PE;
}

// Computes accelerations (F = -dV/dr, m = 1) and potential energy simultaneously
void computeAccelerations() {
    double pot_sum = 0.0;
    int nthreads = 1;

    #pragma omp parallel reduction(+:pot_sum)
    {
        int tid = omp_get_thread_num();
        #pragma omp single
        {
            nthreads = omp_get_num_threads();
        }

        double * __restrict__ lax = ax_priv + (size_t)tid * STRIDE;
        double * __restrict__ lay = ay_priv + (size_t)tid * STRIDE;
        double * __restrict__ laz = az_priv + (size_t)tid * STRIDE;

        for (int i = 0; i < N; i++) {
            lax[i] = 0.0;
            lay[i] = 0.0;
            laz[i] = 0.0;
        }

        #pragma omp for schedule(static, 1)
        for (int i = 0; i < N - 1; i++) {
            const double xi = rx[i];
            const double yi = ry[i];
            const double zi = rz[i];
            double axi = 0.0;
            double ayi = 0.0;
            double azi = 0.0;

            #pragma omp simd reduction(+:axi, ayi, azi, pot_sum)
            for (int j = i + 1; j < N; j++) {
                double dx = xi - rx[j];
                double dy = yi - ry[j];
                double dz = zi - rz[j];
                double rSqd = dx * dx + dy * dy + dz * dz;

                double inv_r2 = 1.0 / rSqd;
                double inv_r6 = inv_r2 * inv_r2 * inv_r2;

                // Lennard-Jones force factor: 24 * (2 * r^-14 - r^-8)
                double f = 24.0 * inv_r2 * inv_r6 * (2.0 * inv_r6 - 1.0);
                // Lennard-Jones potential term: (r^-12 - r^-6)
                pot_sum += inv_r6 * (inv_r6 - 1.0);

                double fx = dx * f;
                double fy = dy * f;
                double fz = dz * f;

                axi += fx;
                ayi += fy;
                azi += fz;

                lax[j] -= fx;
                lay[j] -= fy;
                laz[j] -= fz;
            }

            lax[i] += axi;
            lay[i] += ayi;
            laz[i] += azi;
        }

        // Parallel reduction of thread-private arrays into global a
        #pragma omp for schedule(static)
        for (int i = 0; i < N; i++) {
            double sx = 0.0, sy = 0.0, sz = 0.0;
            for (int t = 0; t < nthreads; t++) {
                sx += ax_priv[(size_t)t * STRIDE + i];
                sy += ay_priv[(size_t)t * STRIDE + i];
                sz += az_priv[(size_t)t * STRIDE + i];
            }
            ax[i] = sx;
            ay[i] = sy;
            az[i] = sz;
        }
    }

    // Factor 8.0 = 2 * 4.0 to match original Potential() double-counting (i != j)
    current_PE = 8.0 * epsilon * pot_sum;
}

double VelocityVerlet(double dt, int iter, FILE *fp) {
    const double half_dt = 0.5 * dt;
    const double half_dt2 = 0.5 * dt * dt;
    double psum = 0.0;

    for (int i = 0; i < N; i++) {
        rx[i] += vx[i] * dt + ax[i] * half_dt2;
        ry[i] += vy[i] * dt + ay[i] * half_dt2;
        rz[i] += vz[i] * dt + az[i] * half_dt2;

        vx[i] += ax[i] * half_dt;
        vy[i] += ay[i] * half_dt;
        vz[i] += az[i] * half_dt;
    }

    computeAccelerations();

    for (int i = 0; i < N; i++) {
        vx[i] += ax[i] * half_dt;
        vy[i] += ay[i] * half_dt;
        vz[i] += az[i] * half_dt;
    }

    // Elastic walls
    const double inv_dt = 1.0 / dt;
    for (int i = 0; i < N; i++) {
        if (rx[i] < 0.0 || rx[i] >= L) {
            vx[i] = -vx[i];
            psum += 2.0 * m * fabs(vx[i]) * inv_dt;
        }
        if (ry[i] < 0.0 || ry[i] >= L) {
            vy[i] = -vy[i];
            psum += 2.0 * m * fabs(vy[i]) * inv_dt;
        }
        if (rz[i] < 0.0 || rz[i] >= L) {
            vz[i] = -vz[i];
            psum += 2.0 * m * fabs(vz[i]) * inv_dt;
        }
    }

    return psum / (6.0 * L * L);
}

void initializeVelocities() {
    for (int i = 0; i < N; i++) {
        vx[i] = gaussdist();
        vy[i] = gaussdist();
        vz[i] = gaussdist();
    }

    double vCMx = 0.0, vCMy = 0.0, vCMz = 0.0;
    for (int i = 0; i < N; i++) {
        vCMx += m * vx[i];
        vCMy += m * vy[i];
        vCMz += m * vz[i];
    }
    vCMx /= (N * m);
    vCMy /= (N * m);
    vCMz /= (N * m);

    double vSqdSum = 0.0;
    for (int i = 0; i < N; i++) {
        vx[i] -= vCMx;
        vy[i] -= vCMy;
        vz[i] -= vCMz;
        vSqdSum += vx[i] * vx[i] + vy[i] * vy[i] + vz[i] * vz[i];
    }

    double lambda = sqrt(3.0 * (N - 1) * Tinit / vSqdSum);
    for (int i = 0; i < N; i++) {
        vx[i] *= lambda;
        vy[i] *= lambda;
        vz[i] *= lambda;
    }
}

double gaussdist() {
    static bool available = false;
    static double gset;
    double fac, rsq, v1, v2;
    if (!available) {
        do {
            v1 = 2.0 * rand() / double(RAND_MAX) - 1.0;
            v2 = 2.0 * rand() / double(RAND_MAX) - 1.0;
            rsq = v1 * v1 + v2 * v2;
        } while (rsq >= 1.0 || rsq == 0.0);

        fac = sqrt(-2.0 * log(rsq) / rsq);
        gset = v1 * fac;
        available = true;
        return v2 * fac;
    } else {
        available = false;
        return gset;
    }
}