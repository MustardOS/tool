#include <stdint.h>
#include <stdio.h>
#include <errno.h>

static uint32_t fnv1a_hash(FILE *fp) {
    uint32_t hash = 2166136261U; // FNV offset basis
    unsigned char buf[65535];
    size_t n;

    while ((n = fread(buf, 1, sizeof buf, fp)) > 0) {
        for (size_t i = 0; i < n; i++) {
            hash ^= buf[i];
            hash *= 16777619; // FNV prime
        }
    }

    if (ferror(fp)) return 0;
    return hash;
}

int main(int argc, char **argv) {
    FILE *fp = stdin;

    if (argc > 2) {
        fprintf(stderr, "Usage: %s [file]\n", argv[0]);
        return 2;
    }

    if (argc == 2) {
        fp = fopen(argv[1], "rb");
        if (!fp) {
            perror("fopen");
            return 1;
        }
    }

    uint32_t h = fnv1a_hash(fp);
    if (fp != stdin) fclose(fp);

    if (h == 0 && errno) {
        perror("fread");
        return 1;
    }

    printf("%08x", h);
    return 0;
}
