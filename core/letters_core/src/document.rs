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
