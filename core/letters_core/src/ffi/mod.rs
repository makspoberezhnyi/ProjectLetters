use crate::citation::{CitationReference, CitationStyle, Source, SourceTable};
use crate::document::Document;
use crate::docx::DocxEngine;
use crate::style::StyleProfile;
use std::ffi::{CStr, CString};
use std::os::raw::c_char;

/// Helper to convert C string pointer to Rust &str
unsafe fn c_str_to_rust<'a>(ptr: *const c_char) -> Option<&'a str> {
    if ptr.is_null() {
        None
    } else {
        CStr::from_ptr(ptr).to_str().ok()
    }
}

/// Helper to return a Rust String as an allocated C string pointer (caller must free with letters_free_string)
fn rust_to_c_str(s: String) -> *mut c_char {
    CString::new(s).unwrap_or_default().into_raw()
}

#[no_mangle]
pub extern "C" fn letters_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            let _ = CString::from_raw(ptr);
        }
    }
}

/// Lint text against a named style profile ("academic", "legal", etc.) and return JSON array of issues
#[no_mangle]
pub unsafe extern "C" fn letters_lint_text(
    profile_name: *const c_char,
    text: *const c_char,
) -> *mut c_char {
    let profile_str = c_str_to_rust(profile_name).unwrap_or("academic");
    let text_str = match c_str_to_rust(text) {
        Some(t) => t,
        None => return rust_to_c_str("[]".to_string()),
    };

    let profile = match profile_str {
        "legal" => StyleProfile::legal_default(),
        _ => StyleProfile::academic_default(),
    };

    let matches = profile.lint_text(text_str);
    let json = serde_json::to_string(&matches).unwrap_or_else(|_| "[]".to_string());
    rust_to_c_str(json)
}

/// Render an inline citation given JSON for a Source, CitationReference, and style ("apa", "mla", "chicago", "bluebook")
#[no_mangle]
pub unsafe extern "C" fn letters_render_citation(
    source_json: *const c_char,
    ref_json: *const c_char,
    style_name: *const c_char,
) -> *mut c_char {
    let source_str = match c_str_to_rust(source_json) {
        Some(s) => s,
        None => return rust_to_c_str("".into()),
    };
    let ref_str = match c_str_to_rust(ref_json) {
        Some(r) => r,
        None => return rust_to_c_str("".into()),
    };
    let style_str = c_str_to_rust(style_name).unwrap_or("apa");

    let source: Source = match serde_json::from_str(source_str) {
        Ok(s) => s,
        Err(_) => return rust_to_c_str("[Invalid Source JSON]".into()),
    };
    let citation_ref: CitationReference = match serde_json::from_str(ref_str) {
        Ok(r) => r,
        Err(_) => return rust_to_c_str("[Invalid Ref JSON]".into()),
    };

    let style = match style_str.to_lowercase().as_str() {
        "mla" => CitationStyle::Mla9,
        "chicago_date" | "chicago" => CitationStyle::ChicagoAuthorDate,
        "chicago_notes" => CitationStyle::ChicagoNotes,
        "bluebook" => CitationStyle::Bluebook,
        "plain" => CitationStyle::PlainAttribution,
        _ => CitationStyle::Apa7,
    };

    let mut table = SourceTable::new();
    table.add_source(source);

    let rendered = table.render_inline(&citation_ref, &style);
    rust_to_c_str(rendered)
}

/// Export a document given its Markdown text directly to DOCX bytes, returns pointer and length
#[no_mangle]
pub unsafe extern "C" fn letters_export_docx_from_markdown(
    title: *const c_char,
    text: *const c_char,
    out_len: *mut usize,
) -> *mut u8 {
    let title_str = c_str_to_rust(title).unwrap_or("Untitled Document");
    let text_str = match c_str_to_rust(text) {
        Some(s) => s,
        None => {
            if !out_len.is_null() {
                *out_len = 0;
            }
            return std::ptr::null_mut();
        }
    };

    let doc = Document::from_markdown_or_text(title_str, text_str);

    match DocxEngine::export_docx(&doc) {
        Ok(bytes) => {
            if !out_len.is_null() {
                *out_len = bytes.len();
            }
            let mut boxed = bytes.into_boxed_slice();
            let ptr = boxed.as_mut_ptr();
            std::mem::forget(boxed);
            ptr
        }
        Err(_) => {
            if !out_len.is_null() {
                *out_len = 0;
            }
            std::ptr::null_mut()
        }
    }
}

/// Export a document given its JSON structure to DOCX bytes, returns pointer and length
#[no_mangle]
pub unsafe extern "C" fn letters_export_docx_from_json(
    doc_json: *const c_char,
    out_len: *mut usize,
) -> *mut u8 {
    let json_str = match c_str_to_rust(doc_json) {
        Some(s) => s,
        None => {
            if !out_len.is_null() {
                *out_len = 0;
            }
            return std::ptr::null_mut();
        }
    };

    let doc: Document = match serde_json::from_str(json_str) {
        Ok(d) => d,
        Err(_) => {
            if !out_len.is_null() {
                *out_len = 0;
            }
            return std::ptr::null_mut();
        }
    };

    match DocxEngine::export_docx(&doc) {
        Ok(bytes) => {
            if !out_len.is_null() {
                *out_len = bytes.len();
            }
            let mut boxed = bytes.into_boxed_slice();
            let ptr = boxed.as_mut_ptr();
            std::mem::forget(boxed);
            ptr
        }
        Err(_) => {
            if !out_len.is_null() {
                *out_len = 0;
            }
            std::ptr::null_mut()
        }
    }
}

#[no_mangle]
pub unsafe extern "C" fn letters_free_bytes(ptr: *mut u8, len: usize) {
    if !ptr.is_null() {
        let _ = Box::from_raw(std::slice::from_raw_parts_mut(ptr, len));
    }
}
