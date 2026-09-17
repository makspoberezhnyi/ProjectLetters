use crate::citation::{CitationReference, SourceTable};
use crate::table::DynamicTable;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct TextRun {
    pub text: String,
    pub bold: bool,
    pub italic: bool,
    pub underline: bool,
    pub strike: bool,
    pub citation: Option<CitationReference>,
    pub variable_ref: Option<String>,
}

impl TextRun {
    pub fn plain(text: impl Into<String>) -> Self {
        Self {
            text: text.into(),
            bold: false,
            italic: false,
            underline: false,
            strike: false,
            citation: None,
            variable_ref: None,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum HeadingLevel {
    Title,
    Subtitle,
    Heading1,
    Heading2,
    Heading3,
    Heading4,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum BlockElement {
    Paragraph {
        runs: Vec<TextRun>,
        alignment: Option<String>,
    },
    Heading {
        level: HeadingLevel,
        runs: Vec<TextRun>,
    },
    BulletItem {
        runs: Vec<TextRun>,
        indent_level: usize,
    },
    NumberedItem {
        runs: Vec<TextRun>,
        number: usize,
    },
    Blockquote {
        runs: Vec<TextRun>,
    },
    Table(DynamicTable),
    PageBreak,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct Document {
    pub title: String,
    pub blocks: Vec<BlockElement>,
    pub sources: SourceTable,
}

impl Document {
    pub fn new(title: impl Into<String>) -> Self {
        Self {
            title: title.into(),
            blocks: Vec::new(),
            sources: SourceTable::new(),
        }
    }

    pub fn add_paragraph(&mut self, text: impl Into<String>) {
        self.blocks.push(BlockElement::Paragraph {
            runs: vec![TextRun::plain(text)],
            alignment: None,
        });
    }

    pub fn add_heading(&mut self, level: HeadingLevel, text: impl Into<String>) {
        self.blocks.push(BlockElement::Heading {
            level,
            runs: vec![TextRun::plain(text)],
        });
    }

    /// Extract all plain text from the document
    pub fn plain_text(&self) -> String {
        let mut out = String::new();
        for block in &self.blocks {
            match block {
                BlockElement::Paragraph { runs, .. }
                | BlockElement::Heading { runs, .. }
                | BlockElement::BulletItem { runs, .. }
                | BlockElement::NumberedItem { runs, .. }
                | BlockElement::Blockquote { runs } => {
                    for run in runs {
                        out.push_str(&run.text);
                    }
                    out.push('\n');
                }
                BlockElement::Table(t) => {
                    for row in &t.cells {
                        for cell in row {
                            if let Some(ev) = &cell.evaluated_value {
                                out.push_str(ev);
                            }
                            out.push('\t');
                        }
                        out.push('\n');
                    }
                }
                BlockElement::PageBreak => {
                    out.push_str("\n--- Page Break ---\n");
                }
            }
        }
        out
    }

    /// Parse markdown or plain text into a structured Document AST
    pub fn from_markdown_or_text(title: &str, text: &str) -> Self {
        let mut doc = Document::new(title);

        for line in text.lines() {
            let trimmed = line.trim();
            if trimmed.is_empty() {
                continue;
            }

            if let Some(rest) = trimmed.strip_prefix("#### ") {
                doc.blocks.push(BlockElement::Heading {
                    level: HeadingLevel::Heading4,
                    runs: Self::parse_inline_runs(rest),
                });
            } else if let Some(rest) = trimmed.strip_prefix("### ") {
                doc.blocks.push(BlockElement::Heading {
                    level: HeadingLevel::Heading3,
                    runs: Self::parse_inline_runs(rest),
                });
            } else if let Some(rest) = trimmed.strip_prefix("## ") {
                doc.blocks.push(BlockElement::Heading {
                    level: HeadingLevel::Heading2,
                    runs: Self::parse_inline_runs(rest),
                });
            } else if let Some(rest) = trimmed.strip_prefix("# ") {
                doc.blocks.push(BlockElement::Heading {
                    level: HeadingLevel::Heading1,
                    runs: Self::parse_inline_runs(rest),
                });
            } else if let Some(rest) = trimmed.strip_prefix("* ") {
                doc.blocks.push(BlockElement::BulletItem {
                    runs: Self::parse_inline_runs(rest),
                    indent_level: 0,
                });
            } else if let Some(rest) = trimmed.strip_prefix("- ") {
                doc.blocks.push(BlockElement::BulletItem {
                    runs: Self::parse_inline_runs(rest),
                    indent_level: 0,
                });
            } else if let Some(rest) = trimmed.strip_prefix("> ") {
                doc.blocks.push(BlockElement::Blockquote {
                    runs: Self::parse_inline_runs(rest),
                });
            } else if trimmed == "---" || trimmed == "***" {
                doc.blocks.push(BlockElement::PageBreak);
            } else {
                // Check numbered list like "1. ", "2. "
                let mut is_numbered = false;
                if let Some(dot_idx) = trimmed.find(". ") {
                    if let Ok(num) = trimmed[..dot_idx].parse::<usize>() {
                        let rest = &trimmed[dot_idx + 2..];
                        doc.blocks.push(BlockElement::NumberedItem {
                            runs: Self::parse_inline_runs(rest),
                            number: num,
                        });
                        is_numbered = true;
                    }
                }

                if !is_numbered {
                    doc.blocks.push(BlockElement::Paragraph {
                        runs: Self::parse_inline_runs(trimmed),
                        alignment: None,
                    });
                }
            }
        }

        doc
    }

    /// Parse inline formatting (bold **, italic *)
    pub fn parse_inline_runs(text: &str) -> Vec<TextRun> {
        let mut runs = Vec::new();
        let mut current = String::new();
        let chars: Vec<char> = text.chars().collect();
        let len = chars.len();
        let mut i = 0;

        while i < len {
            if i + 1 < len && chars[i] == '*' && chars[i + 1] == '*' {
                // Bold marker
                if !current.is_empty() {
                    runs.push(TextRun::plain(std::mem::take(&mut current)));
                }
                i += 2;
                let mut bold_text = String::new();
                while i < len {
                    if i + 1 < len && chars[i] == '*' && chars[i + 1] == '*' {
                        i += 2;
                        break;
                    }
                    bold_text.push(chars[i]);
                    i += 1;
                }
                let mut r = TextRun::plain(bold_text);
                r.bold = true;
                runs.push(r);
            } else if chars[i] == '*' {
                // Italic marker
                if !current.is_empty() {
                    runs.push(TextRun::plain(std::mem::take(&mut current)));
                }
                i += 1;
                let mut italic_text = String::new();
                while i < len {
                    if chars[i] == '*' {
                        i += 1;
                        break;
                    }
                    italic_text.push(chars[i]);
                    i += 1;
                }
                let mut r = TextRun::plain(italic_text);
                r.italic = true;
                runs.push(r);
            } else {
                current.push(chars[i]);
                i += 1;
            }
        }

        if !current.is_empty() {
            runs.push(TextRun::plain(current));
        }

        if runs.is_empty() {
            runs.push(TextRun::plain(text));
        }

        runs
    }

    /// Collect all referenced citation IDs in the document
    pub fn collect_citation_ids(&self) -> Vec<String> {
        let mut ids = Vec::new();
        for block in &self.blocks {
            if let BlockElement::Paragraph { runs, .. }
            | BlockElement::Heading { runs, .. }
            | BlockElement::BulletItem { runs, .. }
            | BlockElement::NumberedItem { runs, .. }
            | BlockElement::Blockquote { runs } = block
            {
                for run in runs {
                    if let Some(cit) = &run.citation {
                        if !ids.contains(&cit.source_id) {
                            ids.push(cit.source_id.clone());
                        }
                    }
                }
            }
        }
        ids
    }
}
