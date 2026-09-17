#include "letters_core.h"
#include <stdlib.h>
#include <string.h>

// Weak or fallback implementations if dylib is loaded dynamically or statically linked
__attribute__((weak)) void letters_free_string(char *ptr) {
    if (ptr) free(ptr);
}

__attribute__((weak)) void letters_free_bytes(uint8_t *ptr, size_t len) {
    (void)len;
    if (ptr) free(ptr);
}

__attribute__((weak)) char *letters_lint_text(const char *profile_name, const char *text) {
    (void)profile_name;
    (void)text;
    const char *empty = "[]";
    char *res = (char *)malloc(strlen(empty) + 1);
    strcpy(res, empty);
    return res;
}

__attribute__((weak)) char *letters_render_citation(const char *source_json, const char *ref_json, const char *style_name) {
    (void)source_json;
    (void)ref_json;
    (void)style_name;
    const char *fallback = "[Citation]";
    char *res = (char *)malloc(strlen(fallback) + 1);
    strcpy(res, fallback);
    return res;
}

__attribute__((weak)) uint8_t *letters_export_docx_from_markdown(const char *title, const char *text, size_t *out_len) {
    (void)title;
    (void)text;
    if (out_len) *out_len = 0;
    return NULL;
}

__attribute__((weak)) uint8_t *letters_export_docx_from_json(const char *doc_json, size_t *out_len) {
    (void)doc_json;
    if (out_len) *out_len = 0;
    return NULL;
}
