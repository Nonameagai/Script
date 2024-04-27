#include <stdio.h>
#include <string.h>
#include <math.h>

#define PI 3.14159265358979323846
#define MAX_WIDTH 80
#define MAX_HEIGHT 80
#define MAX_FRAME 900

int main() {
    float A = 0, B = 0;
    int i, j, k;
    float s, c;
    float z[MAX_FRAME];
    char b[MAX_FRAME];
    printf("\x1b[2J");
    for (;;) {
        memset(b, 32, MAX_FRAME);
        memset(z, 0, MAX_FRAME * 4);
        for (j = 0; j < 314; j += 7) {
            for (i = 0; i < 314; i += 2) {
                float sinA = sin(A), cosA = cos(A);
                float sinB = sin(B), cosB = cos(B);

                s = sin(i), c = cos(j);
                float h = c + 2;
                float D = 1 / (s * h * sinA + sin(j) * cosA + 5);
                float t = s * h * cosA - sinA * sin(j);

                int x = 20 + 15 * D * (cos(i) * h * cosB - t * sinB);
                int y = 6 + 7 * D * (cos(i) * h * sinB + t * cosB);
                int o = x + MAX_WIDTH * y;
                int N = 8 * ((sin(j) * sinA - s * c * cosA) * cosB - s * c * sinA - sin(j) * cosA - cos(i) * c * sinB);
                if (MAX_HEIGHT > y && y > 0 && x > 0 && x < MAX_WIDTH && D > z[o]) {
                    z[o] = D;
                    b[o] = ".,-~:;=!*#$@"[N > 0 ? N : 0];
                }
            }
        }
        printf("\x1b[H");
        for (k = 0; k < MAX_FRAME; k++) {
            putchar(k % MAX_WIDTH ? b[k] : '\n');
        }
        A += 0.01;
        B += 0.01;
    }
    return 0;
}
