#include <errno.h>
#include <stdint.h>
#include <stdio.h>

uint32_t fnv1a_hash_str(const char *str) {
    uint32_t hash = 2166136261U; // FNV offset basis

    for (const char *p = str; *p; p++) {
        hash ^= (uint8_t) (*p);
        hash *= 16777619; // FNV prime
    }

    return hash;
}

uint32_t fnv1a_hash_file(FILE *file) {
    uint32_t hash = 2166136261U; // FNV offset basis
    unsigned char buf[65535];
    size_t n;

    while ((n = fread(buf, 1, sizeof buf, file)) > 0) {
        for (size_t i = 0; i < n; i++) {
            hash ^= buf[i];
            hash *= 16777619; // FNV prime
        }
    }

    if (ferror(file)) return 0;
    return hash;
}

int main(int argc, char **argv) {
    if (argc > 2) {
        fprintf(stderr, "Usage: %s [file or string]\n", argv[0]);
        return 2;
    }

    if (argc == 1) {
        errno = 0;
        uint32_t h = fnv1a_hash_file(stdin);

        if (ferror(stdin)) {
            perror("fread");
            return 1;
        }

        printf("%08x", h);
        return 0;
    }

    const char *path = argv[1];

    errno = 0;
    FILE *fp = fopen(path, "rb");

    if (!fp) {
        if (errno == ENOENT) {
            uint32_t hash = fnv1a_hash_str(path);
            printf("%08x", hash);
            return 0;
        }

        perror("fopen");
        return 1;
    }

    errno = 0;
    uint32_t hash = fnv1a_hash_file(fp);
    int had_err = ferror(fp);
    fclose(fp);

    if (had_err) {
        perror("fread");
        return 1;
    }

    printf("%08x", hash);
    return 0;
}
