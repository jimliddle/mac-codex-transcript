#include <arpa/inet.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void fail(const char *message, const char *path) {
    fprintf(stderr, "%s: %s\n", message, path);
    exit(1);
}

static long file_size(const char *path) {
    FILE *file = fopen(path, "rb");
    if (!file) fail("Could not open", path);
    if (fseek(file, 0, SEEK_END) != 0) fail("Could not seek", path);
    long size = ftell(file);
    fclose(file);
    if (size < 0) fail("Could not measure", path);
    return size;
}

static void write_u32(FILE *file, uint32_t value) {
    uint32_t big_endian = htonl(value);
    if (fwrite(&big_endian, sizeof(big_endian), 1, file) != 1) {
        fail("Could not write", "output");
    }
}

int main(int argc, char **argv) {
    if (argc < 4 || argc % 2 != 0) {
        fprintf(stderr, "Usage: %s output.icns TYPE input.png [TYPE input.png ...]\n", argv[0]);
        return 2;
    }

    uint64_t total = 8;
    for (int index = 2; index < argc; index += 2) {
        if (strlen(argv[index]) != 4) fail("Chunk type must be four characters", argv[index]);
        total += 8 + (uint64_t)file_size(argv[index + 1]);
    }
    if (total > UINT32_MAX) fail("Icon is too large", argv[1]);

    FILE *output = fopen(argv[1], "wb");
    if (!output) fail("Could not create", argv[1]);
    fwrite("icns", 4, 1, output);
    write_u32(output, (uint32_t)total);

    unsigned char buffer[64 * 1024];
    for (int index = 2; index < argc; index += 2) {
        const char *type = argv[index];
        const char *path = argv[index + 1];
        long size = file_size(path);
        FILE *input = fopen(path, "rb");
        if (!input) fail("Could not open", path);

        fwrite(type, 4, 1, output);
        write_u32(output, (uint32_t)size + 8);
        size_t count;
        while ((count = fread(buffer, 1, sizeof(buffer), input)) > 0) {
            if (fwrite(buffer, 1, count, output) != count) fail("Could not write", argv[1]);
        }
        fclose(input);
    }

    fclose(output);
    return 0;
}
