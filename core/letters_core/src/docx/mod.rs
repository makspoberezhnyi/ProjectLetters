use crate::document::{BlockElement, Document, HeadingLevel, TextRun};
use crate::error::{LettersError, Result};
use std::io::{Cursor, Read, Write};
use zip::write::SimpleFileOptions;
use zip::{ZipArchive, ZipWriter};

pub struct DocxEngine;

impl DocxEngine {
    /// Export a Document into a standard .docx binary (ZIP containing OpenXML parts)
    pub fn export_docx(doc: &Document) -> Result<Vec<u8>> {
        let mut buffer = Cursor::new(Vec::new());
        {
            let mut zip = ZipWriter::new(&mut buffer);
            let options = SimpleFileOptions::default()
                .compression_method(zip::CompressionMethod::Deflated);

            // 1. [Content_Types].xml
            zip.start_file("[Content_Types].xml", options)?;
            zip.write_all(Self::content_types_xml().as_bytes())?;

            // 2. _rels/.rels
            zip.start_file("_rels/.rels", options)?;
            zip.write_all(Self::root_rels_xml().as_bytes())?;

            // 3. word/_rels/document.xml.rels
            zip.start_file("word/_rels/document.xml.rels", options)?;
            zip.write_all(Self::doc_rels_xml().as_bytes())?;

            // 4. word/styles.xml
            zip.start_file("word/styles.xml", options)?;
            zip.write_all(Self::styles_xml().as_bytes())?;

            // 5. word/document.xml
            zip.start_file("word/document.xml", options)?;
            let doc_xml = Self::build_document_xml(doc);
            zip.write_all(doc_xml.as_bytes())?;

            zip.finish()?;
        }

        Ok(buffer.into_inner())
    }

    /// Read an existing .docx file and extract body paragraphs as a Document model
    pub fn import_docx(bytes: &[u8]) -> Result<Document> {
        let cursor = Cursor::new(bytes);
        let mut archive = ZipArchive::new(cursor)?;

        let mut doc_xml_str = String::new();
        {
            let mut file = archive
                .by_name("word/document.xml")
                .map_err(|e| LettersError::InvalidDocument(format!("Missing word/document.xml: {}", e)))?;
            file.read_to_string(&mut doc_xml_str)?;
        }

        Self::parse_document_xml(&doc_xml_str)
    }

    fn content_types_xml() -> &'static str {
        r#"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>"#
    }

    fn root_rels_xml() -> &'static str {
        r#"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>"#
    }

    fn doc_rels_xml() -> &'static str {
        r#"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>"#
    }

    fn styles_xml() -> &'static str {
        r#"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr>
        <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/>
        <w:sz w:val="24"/>
      </w:rPr>
    </w:rPrDefault>
  </w:docDefaults>
</w:styles>"#
    }

    fn build_document_xml(doc: &Document) -> String {
        let mut out = String::new();
        out.push_str(r#"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>"#);
        out.push_str(r#"<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">"#);
        out.push_str("<w:body>");

        for block in &doc.blocks {
            match block {
                BlockElement::Paragraph { runs, alignment } => {
                    out.push_str("<w:p>");
                    if let Some(align) = alignment {
                        out.push_str(&format!(r#"<w:pPr><w:jc w:val="{}"/></w:pPr>"#, align));
                    }
                    for run in runs {
                        out.push_str(&Self::build_run_xml(run));
                    }
                    out.push_str("</w:p>");
                }
                BlockElement::Heading { level, runs } => {
                    let style_id = match level {
                        HeadingLevel::Title => "Title",
                        HeadingLevel::Subtitle => "Subtitle",
                        HeadingLevel::Heading1 => "Heading1",
                        HeadingLevel::Heading2 => "Heading2",
                        HeadingLevel::Heading3 => "Heading3",
                        HeadingLevel::Heading4 => "Heading4",
                    };
                    out.push_str(&format!(r#"<w:p><w:pPr><w:pStyle w:val="{}"/></w:pPr>"#, style_id));
                    for run in runs {
                        out.push_str(&Self::build_run_xml(run));
                    }
                    out.push_str("</w:p>");
                }
                BlockElement::BulletItem { runs, .. } => {
                    out.push_str(r#"<w:p><w:pPr><w:pStyle w:val="ListBullet"/></w:pPr>"#);
                    for run in runs {
                        out.push_str(&Self::build_run_xml(run));
                    }
                    out.push_str("</w:p>");
                }
                BlockElement::NumberedItem { runs, .. } => {
                    out.push_str(r#"<w:p><w:pPr><w:pStyle w:val="ListNumber"/></w:pPr>"#);
                    for run in runs {
                        out.push_str(&Self::build_run_xml(run));
                    }
                    out.push_str("</w:p>");
                }
                BlockElement::Blockquote { runs } => {
                    out.push_str(r#"<w:p><w:pPr><w:pStyle w:val="Quote"/></w:pPr>"#);
                    for run in runs {
                        out.push_str(&Self::build_run_xml(run));
                    }
                    out.push_str("</w:p>");
                }
                BlockElement::Table(t) => {
                    out.push_str("<w:tbl>");
                    for row in &t.cells {
                        out.push_str("<w:tr>");
                        for cell in row {
                            out.push_str("<w:tc><w:p>");
                            let text = cell.evaluated_value.as_deref().unwrap_or("");
                            let run = TextRun::plain(text);
                            out.push_str(&Self::build_run_xml(&run));
                            out.push_str("</w:p></w:tc>");
                        }
                        out.push_str("</w:tr>");
                    }
                    out.push_str("</w:tbl>");
                }
                BlockElement::PageBreak => {
                    out.push_str(r#"<w:p><w:r><w:br w:type="page"/></w:r></w:p>"#);
                }
            }
        }

        out.push_str("</w:body></w:document>");
        out
    }

    fn build_run_xml(run: &TextRun) -> String {
        let mut out = String::new();
        out.push_str("<w:r>");
        if run.bold || run.italic || run.underline || run.strike {
            out.push_str("<w:rPr>");
            if run.bold {
                out.push_str("<w:b/>");
            }
            if run.italic {
                out.push_str("<w:i/>");
            }
            if run.underline {
                out.push_str(r#"<w:u w:val="single"/>"#);
            }
            if run.strike {
                out.push_str("<w:strike/>");
            }
            out.push_str("</w:rPr>");
        }
        let escaped = quick_xml::escape::escape(&run.text);
        out.push_str(&format!(r#"<w:t xml:space="preserve">{}</w:t>"#, escaped));
        out.push_str("</w:r>");
        out
    }

    fn parse_document_xml(xml: &str) -> Result<Document> {
        let mut doc = Document::new("Imported Document");
        let mut reader = quick_xml::Reader::from_str(xml);
        reader.config_mut().trim_text(false);

        let mut in_p = false;
        let mut in_r = false;
        let mut in_t = false;
        let mut current_bold = false;
        let mut current_italic = false;
        let mut current_runs = Vec::new();
        let mut buf = Vec::new();

        loop {
            match reader.read_event_into(&mut buf) {
                Ok(quick_xml::events::Event::Start(e)) => match e.name().as_ref() {
                    b"w:p" => {
                        in_p = true;
                        current_runs.clear();
                    }
                    b"w:r" => {
                        in_r = true;
                        current_bold = false;
                        current_italic = false;
                    }
                    b"w:b" => {
                        if in_r {
                            current_bold = true;
                        }
                    }
                    b"w:i" => {
                        if in_r {
                            current_italic = true;
                        }
                    }
                    b"w:t" => {
                        in_t = true;
                    }
                    _ => {}
                },
                Ok(quick_xml::events::Event::Empty(e)) => match e.name().as_ref() {
                    b"w:b" => {
                        if in_r {
                            current_bold = true;
                        }
                    }
                    b"w:i" => {
                        if in_r {
                            current_italic = true;
                        }
                    }
                    _ => {}
                },
                Ok(quick_xml::events::Event::Text(e)) => {
                    if in_t {
                        let text = e.unescape().map_err(LettersError::Xml)?.to_string();
                        current_runs.push(TextRun {
                            text,
                            bold: current_bold,
                            italic: current_italic,
                            underline: false,
                            strike: false,
                            citation: None,
                            variable_ref: None,
                        });
                    }
                }
                Ok(quick_xml::events::Event::End(e)) => match e.name().as_ref() {
                    b"w:t" => {
                        in_t = false;
                    }
                    b"w:r" => {
                        in_r = false;
                    }
                    b"w:p" => {
                        if in_p && !current_runs.is_empty() {
                            doc.blocks.push(BlockElement::Paragraph {
                                runs: current_runs.clone(),
                                alignment: None,
                            });
                        }
                        in_p = false;
                    }
                    _ => {}
                },
                Ok(quick_xml::events::Event::Eof) => break,
                Err(e) => return Err(LettersError::Xml(e)),
                _ => {}
            }
            buf.clear();
        }

        Ok(doc)
    }
}
