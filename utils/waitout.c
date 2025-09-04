#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sys/inotify.h>
#include <fcntl.h>
#include <stdlib.h>
#include <poll.h>
#include <time.h>

#define BUF_LEN (sizeof(struct inotify_event) + NAME_MAX + 1)

static int get_remaining_timeout(struct timespec start, int timeout_sec) {
    struct timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);

    time_t elapsed_sec = now.tv_sec - start.tv_sec;
    long elapsed_n_sec = now.tv_nsec - start.tv_nsec;

    if (elapsed_n_sec < 0) {
        elapsed_sec--;
        elapsed_n_sec += 1000000000;
    }

    int remaining = (timeout_sec * 1000) - (elapsed_sec * 1000 + elapsed_n_sec / 1000000);
    return remaining > 0 ? remaining : 0;
}

int main(int argc, char *argv[]) {
    int timeout_sec = -1;
    int purge = 0;
    const char *target = NULL;

    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "-t") && i + 1 < argc) {
            timeout_sec = atoi(argv[++i]);
        } else if (!strcmp(argv[i], "-p")) {
            purge = 1;
        } else {
            target = argv[i];
        }
    }

    if (!target) {
        dprintf(STDERR_FILENO, "Usage: %s [-t seconds] [-p] /path/to/target\n", argv[0]);
        return 1;
    }

    const char *slash = strrchr(target, '/');
    if (!slash || !*(slash + 1)) {
        dprintf(STDERR_FILENO, "Invalid file path: %s\n", target);
        return 1;
    }

    char dir[PATH_MAX];
    snprintf(dir, sizeof(dir), "%.*s", (int) (slash - target), target);

    char file[NAME_MAX + 1];
    snprintf(file, sizeof(file), "%s", slash + 1);

    if (purge) remove(target);

    if (access(target, F_OK) == 0) return 0;

    int fd = inotify_init1(IN_NONBLOCK | IN_CLOEXEC);
    if (fd < 0) {
        perror("inotify_init1");
        return 1;
    }

    int wd = inotify_add_watch(fd, dir, IN_CREATE | IN_MOVED_TO);
    if (wd < 0) {
        perror("inotify_add_watch");
        close(fd);
        return 1;
    }

    struct pollfd pfd = {.fd = fd, .events = POLLIN};
    char buf[BUF_LEN];

    struct timespec start;
    if (timeout_sec >= 0) clock_gettime(CLOCK_MONOTONIC, &start);

    while (1) {
        int poll_timeout = -1;
        if (timeout_sec >= 0) {
            poll_timeout = get_remaining_timeout(start, timeout_sec);
            if (poll_timeout == 0) {
                close(fd);
                return 2;
            }
        }

        int ret = poll(&pfd, 1, poll_timeout);
        if (ret < 0) {
            if (errno == EINTR) continue;
            perror("poll");
            break;
        } else if (ret == 0) continue;

        ssize_t len = read(fd, buf, sizeof(buf));
        if (len < 0) {
            if (errno == EAGAIN || errno == EINTR) continue;
            perror("read");
            break;
        }

        for (char *ptr = buf;
             ptr < buf + len; ptr += sizeof(struct inotify_event) + ((struct inotify_event *) ptr)->len) {
            struct inotify_event *event = (struct inotify_event *) ptr;
            if ((event->mask & (IN_CREATE | IN_MOVED_TO)) && strcmp(event->name, file) == 0) {
                close(fd);
                return 0;
            }
        }
    }

    close(fd);
    return 1;
}
