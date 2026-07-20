#ifndef BBCAT_BRIDGE_H
#define BBCAT_BRIDGE_H

#include <stddef.h>
#include <stdint.h>

typedef struct BbcatDocument BbcatDocument;

typedef struct {
    uint8_t *data;
    size_t length;
    uint64_t duration_ns;
} BbcatFrame;

BbcatDocument *bbcat_document_open(const char *path);
void bbcat_document_free(BbcatDocument *document);
size_t bbcat_document_frame_count(const BbcatDocument *document);
char *bbcat_document_display_title(const BbcatDocument *document, const char *fallback);
int32_t bbcat_document_render_frame(
    const BbcatDocument *document,
    size_t index,
    size_t scale,
    BbcatFrame *frame
);
int32_t bbcat_document_render_thumbnail(
    const BbcatDocument *document,
    size_t maximum_pixel_size,
    BbcatFrame *frame
);
char *bbcat_take_last_error(void);
void bbcat_string_free(char *string);
void bbcat_bytes_free(uint8_t *data, size_t length);

#endif
