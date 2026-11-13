/* Open a copy of an MPQ and delete every DBFilesClient\* entry so a HD model
 * pack cannot shadow stock CreatureModelData / CreatureDisplayInfo.
 *
 *   clang -O2 -o strip-mpq-dbc strip-mpq-dbc.c -I/opt/homebrew/include -L/opt/homebrew/lib -lstorm
 *   ./strip-mpq-dbc in.mpq out.mpq
 */
#include <StormLib.h>
#include <ctype.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static int is_dbc(const char *name) {
    char buf[512];
    size_t n = strlen(name);
    if (n >= sizeof(buf))
        return 0;
    for (size_t i = 0; i <= n; i++)
        buf[i] = (char)tolower((unsigned char)name[i]);
    return strncmp(buf, "dbfilesclient\\", 14) == 0
        || strncmp(buf, "dbfilesclient/", 14) == 0;
}

int main(int argc, char **argv) {
    if (argc != 3) {
        fprintf(stderr, "usage: %s <in.mpq> <out.mpq>\n", argv[0]);
        return 2;
    }

    /* Work on a full copy so the download cache stays intact. */
    fprintf(stderr, "copying %s -> %s\n", argv[1], argv[2]);
    char cmd[1024];
    snprintf(cmd, sizeof(cmd), "/bin/cp -f '%s' '%s'", argv[1], argv[2]);
    if (system(cmd) != 0) {
        fprintf(stderr, "copy failed\n");
        return 1;
    }

    HANDLE mpq = NULL;
    if (!SFileOpenArchive(argv[2], 0, 0, &mpq)) {
        fprintf(stderr, "open out: %u\n", SErrGetLastError());
        return 1;
    }

    /* Collect names first — cannot remove while iterating. */
    char names[256][260];
    unsigned nnames = 0;
    SFILE_FIND_DATA fd;
    HANDLE find = SFileFindFirstFile(mpq, "DBFilesClient\\*", &fd, NULL);
    if (find) {
        do {
            if (nnames < 256 && is_dbc(fd.cFileName)) {
                strncpy(names[nnames], fd.cFileName, 259);
                names[nnames][259] = '\0';
                nnames++;
            }
        } while (SFileFindNextFile(find, &fd));
        SFileFindClose(find);
    }

    unsigned removed = 0;
    for (unsigned i = 0; i < nnames; i++) {
        if (SFileRemoveFile(mpq, names[i], 0)) {
            fprintf(stderr, "removed %s\n", names[i]);
            removed++;
        } else {
            fprintf(stderr, "remove fail %s: %u\n", names[i], SErrGetLastError());
        }
    }

    fprintf(stderr, "compacting…\n");
    if (!SFileCompactArchive(mpq, NULL, false))
        fprintf(stderr, "compact warn: %u\n", SErrGetLastError());
    SFileCloseArchive(mpq);
    fprintf(stderr, "removed %u DBFilesClient file(s) -> %s\n", removed, argv[2]);
    return removed ? 0 : 1;
}
