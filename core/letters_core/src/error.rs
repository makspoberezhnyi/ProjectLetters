use thiserror::Error;

#[derive(Error, Debug)]
pub enum LettersError {
    #[error("DOCX IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("ZIP package error: {0}")]
    Zip(#[from] zip::result::ZipError),

    #[error("XML parsing error: {0}")]
    Xml(#[from] quick_xml::Error),

    #[error("JSON serialization error: {0}")]
    Json(#[from] serde_json::Error),

    #[error("Formula evaluation error: {0}")]
    Formula(String),

    #[error("Invalid document structure: {0}")]
    InvalidDocument(String),

    #[error("Citation error: {0}")]
    Citation(String),
}

pub type Result<T> = std::result::Result<T, LettersError>;
