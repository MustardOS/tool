#include <sys/stat.h>
#include <dirent.h>
#include <fcntl.h>
#include <unistd.h>
#include <limits.h>
#include <stdio.h>
#include <string.h>

static int is_writable_attr(const char *path) {
    int fd = open(path, O_WRONLY | O_NONBLOCK | O_CLOEXEC);
    if (fd < 0) return 0;
    close(fd);
    return 1;
}

static int is_parameters_dir(const char *path) {
    const char *slash = strrchr(path, '/');
    return (slash && strcmp(slash + 1, "parameters") == 0);
}

static void pretty_print(const char *fullpath) {
    const char *p = strstr(fullpath, "/module/");

    if (p) {
        p += 8;
        const char *end = strchr(p, '/');
        if (end) {
            size_t len = (size_t) (end - p);
            if (len > NAME_MAX) len = NAME_MAX;
        }
    }

    printf("%s\n", fullpath);
}

static void scan_parameters_dir(const char *dirpath) {
    DIR *d = opendir(dirpath);
    if (!d) return;

    struct dirent *de;
    char path[PATH_MAX];

    while ((de = readdir(d)) != NULL) {
        if (de->d_name[0] == '.') continue;

        int n = snprintf(path, sizeof(path), "%s/%s", dirpath, de->d_name);
        if (n <= 0 || (size_t) n >= sizeof(path)) continue;

        struct stat st;
        if (lstat(path, &st) != 0) continue;
        if (!S_ISREG(st.st_mode)) continue;

        if (is_writable_attr(path)) pretty_print(path);
    }
    closedir(d);
}

static void walk(const char *root) {
    DIR *d = opendir(root);
    if (!d) return;

    struct dirent *de;
    char path[PATH_MAX];

    while ((de = readdir(d)) != NULL) {
        if (de->d_name[0] == '.') continue;

        int n = snprintf(path, sizeof(path), "%s/%s", root, de->d_name);
        if (n <= 0 || (size_t) n >= sizeof(path)) continue;

        struct stat st;
        if (lstat(path, &st) != 0) continue;

        if (S_ISDIR(st.st_mode)) {
            if (is_parameters_dir(path)) {
                scan_parameters_dir(path);
                continue;
            }
            walk(path);
        }
    }
    closedir(d);
}

int main(int argc, char **argv) {
    const char *root = (argc >= 2) ? argv[1] : "/sys/module";
    walk(root);
    return 0;
}
