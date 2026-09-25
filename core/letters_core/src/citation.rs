use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum SourceType {
    JournalArticle,
    Book,
    BookChapter,
    LegalCase,
    Statute,
    NewsArticle,
    Website,
    Interview,
    Report,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Source {
    pub id: String,
    pub source_type: SourceType,
    pub authors: Vec<String>,
    pub year: Option<u32>,
    pub title: String,
    pub publication: Option<String>,
    pub volume: Option<String>,
    pub issue: Option<String>,
    pub pages: Option<String>,
    pub doi: Option<String>,
    pub url: Option<String>,
    pub publisher: Option<String>,
    pub court: Option<String>,
    pub reporter: Option<String>,
    pub access_date: Option<String>,
    pub interview_date: Option<String>,
    pub notes: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "lowercase")]
pub enum CitationStyle {
    Apa7,
    Mla9,
    ChicagoAuthorDate,
    ChicagoNotes,
    Bluebook,
    PlainAttribution,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CitationReference {
    pub source_id: String,
    pub pin_point: Option<String>, // e.g. "p. 42", "para. 12", "§ 102"
    pub prefix: Option<String>,    // e.g. "see also"
    pub suffix: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default, PartialEq)]
pub struct SourceTable {
    pub sources: HashMap<String, Source>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum ValidationIssueKind {
    MissingFields(Vec<String>),
    UncitedSource,
    OrphanCitation(String),
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ValidationIssue {
    pub source_id: Option<String>,
    pub message: String,
    pub issue_type: ValidationIssueKind,
}

impl SourceTable {
    pub fn new() -> Self {
        Self {
            sources: HashMap::new(),
        }
    }

    pub fn add_source(&mut self, source: Source) {
        self.sources.insert(source.id.clone(), source);
    }

    pub fn get_source(&self, id: &str) -> Option<&Source> {
        self.sources.get(id)
    }

    pub fn remove_source(&mut self, id: &str) -> Option<Source> {
        self.sources.remove(id)
    }

    pub fn author_surname(name: &str) -> &str {
        if let Some((last, _)) = name.split_once(',') {
            last.trim()
        } else if let Some(last) = name.split_whitespace().last() {
            last
        } else {
            name
        }
    }

    /// Render inline citation based on active style
    pub fn render_inline(&self, reference: &CitationReference, style: &CitationStyle) -> Result<String, crate::error::LettersError> {
        let source = match self.get_source(&reference.source_id) {
            Some(s) => s,
            None => return Err(crate::error::LettersError::Citation(format!("Source '{}' not found", reference.source_id))),
        };

        let author_lead = source
            .authors
            .first()
            .map(|s| Self::author_surname(s))
            .unwrap_or("Unknown");
        let year_str = source
            .year
            .map(|y| y.to_string())
            .unwrap_or_else(|| "n.d.".to_string());

        let mut body = match style {
            CitationStyle::Apa7 => {
                if source.authors.len() > 2 {
                    format!("({} et al., {})", author_lead, year_str)
                } else if source.authors.len() == 2 {
                    let first = Self::author_surname(&source.authors[0]);
                    let second = Self::author_surname(&source.authors[1]);
                    format!("({} & {}, {})", first, second, year_str)
                } else {
                    format!("({}, {})", author_lead, year_str)
                }
            }
            CitationStyle::Mla9 => {
                let pin = reference.pin_point.as_deref().unwrap_or("");
                if pin.is_empty() {
                    format!("({})", author_lead)
                } else {
                    format!("({} {})", author_lead, pin)
                }
            }
            CitationStyle::ChicagoAuthorDate => {
                format!("({}, {})", author_lead, year_str)
            }
            CitationStyle::ChicagoNotes => {
                format!("{}. \"{}\" ({})", author_lead, source.title, year_str)
            }
            CitationStyle::Bluebook => {
                if source.source_type == SourceType::LegalCase {
                    let reporter = source.reporter.as_deref().unwrap_or("");
                    let court = source.court.as_deref().unwrap_or("");
                    format!("{} {} ({}{})", source.title, reporter, court, year_str)
                } else {
                    format!("{}, {}", author_lead, source.title)
                }
            }
            CitationStyle::PlainAttribution => {
                format!("(Source: {}, {})", author_lead, source.title)
            }
        };

        if let Some(pin) = &reference.pin_point {
            if *style == CitationStyle::Apa7 || *style == CitationStyle::ChicagoAuthorDate {
                body = body.trim_end_matches(')').to_string();
                body = format!("{}, {})", body, pin);
            }
        }

        if let Some(prefix) = &reference.prefix {
            body = format!("{} {}", prefix, body);
        }

        Ok(body)
    }

    /// Render full bibliography entry
    pub fn render_bibliography_entry(&self, source: &Source, style: &CitationStyle) -> String {
        let raw_authors_str = if source.authors.is_empty() {
            "Unknown".to_string()
        } else {
            source.authors.join(", ")
        };
        let authors_str = raw_authors_str.trim_end_matches('.');

        let year_str = source
            .year
            .map(|y| y.to_string())
            .unwrap_or_else(|| "n.d.".to_string());

        match style {
            CitationStyle::Apa7 => {
                let pub_info = source.publication.as_deref().unwrap_or("");
                let doi_info = source
                    .doi
                    .as_ref()
                    .map(|d| format!(" https://doi.org/{}", d))
                    .unwrap_or_default();
                format!("{}. ({}). {}. {}.{}", authors_str, year_str, source.title, pub_info, doi_info)
            }
            CitationStyle::Mla9 => {
                let container = source.publication.as_deref().unwrap_or("");
                format!("{}. \"{}\". {}, {}.", authors_str, source.title, container, year_str)
            }
            CitationStyle::ChicagoAuthorDate => {
                format!("{}. {}. {}. {}", authors_str, year_str, source.title, source.publication.as_deref().unwrap_or(""))
            }
            CitationStyle::ChicagoNotes => {
                format!("{}. {}. {}.", authors_str, source.title, source.publication.as_deref().unwrap_or(""))
            }
            CitationStyle::Bluebook => {
                if source.source_type == SourceType::LegalCase {
                    format!("{}, {} ({})", source.title, source.reporter.as_deref().unwrap_or(""), year_str)
                } else {
                    format!("{}. {}. {}", authors_str, source.title, source.publication.as_deref().unwrap_or(""))
                }
            }
            CitationStyle::PlainAttribution => {
                format!("{} — \"{}\" ({})", authors_str, source.title, year_str)
            }
        }
    }

    /// Validates sources against document references
    pub fn validate(&self, referenced_ids: &[String]) -> Vec<ValidationIssue> {
        let mut issues = Vec::new();

        // 1. Check for orphan citations (citations pointing to non-existent sources)
        for ref_id in referenced_ids {
            if !self.sources.contains_key(ref_id) {
                issues.push(ValidationIssue {
                    source_id: Some(ref_id.clone()),
                    message: format!("Citation points to missing source '{}'", ref_id),
                    issue_type: ValidationIssueKind::OrphanCitation(ref_id.clone()),
                });
            }
        }

        // 2. Check for uncited sources and missing required fields
        for (id, source) in &self.sources {
            if !referenced_ids.contains(id) {
                issues.push(ValidationIssue {
                    source_id: Some(id.clone()),
                    message: format!("Source '{}' is defined in bibliography but never cited in text", source.title),
                    issue_type: ValidationIssueKind::UncitedSource,
                });
            }

            let mut missing = Vec::new();
            if source.authors.is_empty() {
                missing.push("authors".to_string());
            }
            if source.year.is_none() {
                missing.push("year".to_string());
            }
            if source.title.trim().is_empty() {
                missing.push("title".to_string());
            }

            if !missing.is_empty() {
                issues.push(ValidationIssue {
                    source_id: Some(id.clone()),
                    message: format!("Source '{}' is missing required fields: {}", id, missing.join(", ")),
                    issue_type: ValidationIssueKind::MissingFields(missing),
                });
            }
        }

        issues
    }
}
