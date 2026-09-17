pub mod citation;
pub mod document;
pub mod docx;
pub mod error;
pub mod ffi;
pub mod style;
pub mod table;

pub use citation::{CitationReference, CitationStyle, Source, SourceTable, SourceType};
pub use document::{BlockElement, Document, HeadingLevel, TextRun};
pub use docx::DocxEngine;
pub use error::{LettersError, Result};
pub use style::{StyleLintMatch, StyleProfile, StyleRule, StyleRuleType};
pub use table::{CellValue, DynamicTable, TableCell};

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_citation_rendering_and_validation() {
        let mut table = SourceTable::new();
        let source = Source {
            id: "smith2024".into(),
            source_type: SourceType::JournalArticle,
            authors: vec!["Smith, J.".into(), "Doe, A.".into()],
            year: Some(2024),
            title: "Advancements in Document Engineering".into(),
            publication: Some("Journal of Modern Systems".into()),
            volume: Some("12".into()),
            issue: Some("3".into()),
            pages: Some("45-60".into()),
            doi: Some("10.1000/182".into()),
            url: None,
            publisher: None,
            court: None,
            reporter: None,
            access_date: None,
            interview_date: None,
            notes: None,
        };
        table.add_source(source.clone());

        let reference = CitationReference {
            source_id: "smith2024".into(),
            pin_point: Some("p. 48".into()),
            prefix: None,
            suffix: None,
        };

        let apa = table.render_inline(&reference, &CitationStyle::Apa7);
        assert_eq!(apa, "(Smith & Doe, 2024, p. 48)");

        let mla = table.render_inline(&reference, &CitationStyle::Mla9);
        assert_eq!(mla, "(Smith p. 48)");

        let bib_apa = table.render_bibliography_entry(&source, &CitationStyle::Apa7);
        assert!(bib_apa.contains("Smith, J., Doe, A. (2024). Advancements in Document Engineering."));

        let issues = table.validate(&["smith2024".to_string()]);
        assert!(issues.is_empty());

        let orphan_issues = table.validate(&["missing_id".to_string()]);
        assert_eq!(orphan_issues.len(), 2); // 1 orphan citation + 1 uncited source
    }

    #[test]
    fn test_style_linting() {
        let profile = StyleProfile::academic_default();
        let text = "As we all know, this experiment demonstrates significant improvements.";
        let matches = profile.lint_text(text);
        assert_eq!(matches.len(), 1);
        assert_eq!(matches[0].rule_id, "no_informal_first_person");
        assert_eq!(matches[0].suggestion, Some("evidence indicates".into()));
    }

    #[test]
    fn test_table_formula_evaluation() {
        let mut table = DynamicTable::new("revenue_summary", 3, 2);
        table.set_cell(0, 0, CellValue::Number(1500.0), Some("q1_rev".into()));
        table.set_cell(1, 0, CellValue::Number(2500.0), Some("q2_rev".into()));
        table.set_cell(2, 0, CellValue::Formula("=q1_rev + q2_rev".into()), Some("total_rev".into()));

        let var_map = table.evaluate().expect("Formula should evaluate");
        assert_eq!(var_map.get("total_rev"), Some(&"4000".to_string()));
        assert_eq!(table.cells[2][0].evaluated_value, Some("4000".to_string()));
    }

    #[test]
    fn test_docx_export_and_import() {
        let mut doc = Document::new("Quarterly Report");
        doc.add_heading(HeadingLevel::Heading1, "Executive Summary");
        doc.add_paragraph("Letters is a modern native document processor.");

        let bytes = DocxEngine::export_docx(&doc).expect("DOCX export should succeed");
        assert!(!bytes.is_empty());

        let imported = DocxEngine::import_docx(&bytes).expect("DOCX import should succeed");
        assert_eq!(imported.blocks.len(), 2);
        let plain = imported.plain_text();
        assert!(plain.contains("Executive Summary"));
        assert!(plain.contains("Letters is a modern native document processor."));
    }

    #[test]
    fn test_markdown_to_docx() {
        let md = "# Project Letters\nThis is a **bold** paragraph with *italic* text.\n* Bullet item 1\n* Bullet item 2\n1. Numbered item 1";
        let doc = Document::from_markdown_or_text("Test Doc", md);
        assert_eq!(doc.blocks.len(), 5);

        let bytes = DocxEngine::export_docx(&doc).expect("Export markdown doc to docx");
        assert!(!bytes.is_empty());
    }
}
