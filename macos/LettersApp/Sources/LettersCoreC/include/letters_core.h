#ifndef LETTERS_CORE_H
#define LETTERS_CORE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

void letters_free_string(char *ptr);
void letters_free_bytes(uint8_t *ptr, size_t len);
char *letters_lint_text(const char *profile_name, const char *text);
char *letters_render_citation(const char *source_json, const char *ref_json, const char *style_name);
uint8_t *letters_export_docx_from_markdown(const char *title, const char *text, size_t *out_len);
uint8_t *letters_export_docx_from_json(const char *doc_json, size_t *out_len);

#ifdef __cplusplus
}
#endif

#endif /* LETTERS_CORE_H */
