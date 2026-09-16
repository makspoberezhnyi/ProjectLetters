use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StyleRule {
    pub id: String,
    pub name: String,
    pub description: String,
    pub rule_type: StyleRuleType,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum StyleRuleType {
    BannedPhrase { phrase: String, suggestion: Option<String> },
    MaxSentenceLength(usize),
    AvoidPassiveVoice,
    PreferredSpelling { original: String, preferred: String },
    CustomRegex { pattern: String, explanation: String },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StyleProfile {
    pub id: String,
    pub name: String,
    pub description: String,
    pub rules: Vec<StyleRule>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StyleLintMatch {
    pub rule_id: String,
    pub message: String,
    pub span_start: usize,
    pub span_end: usize,
    pub suggestion: Option<String>,
}

impl StyleProfile {
    pub fn new(id: impl Into<String>, name: impl Into<String>) -> Self {
        Self {
            id: id.into(),
            name: name.into(),
            description: String::new(),
            rules: Vec::new(),
        }
    }

    pub fn academic_default() -> Self {
        let mut profile = Self::new("academic_default", "Academic Standard");
        profile.rules.push(StyleRule {
            id: "no_informal_first_person".into(),
            name: "Avoid informal first person".into(),
            description: "Avoid casual first-person pronouns in formal sections".into(),
            rule_type: StyleRuleType::BannedPhrase {
                phrase: "as we all know".into(),
                suggestion: Some("evidence indicates".into()),
            },
        });
        profile.rules.push(StyleRule {
            id: "sentence_length".into(),
            name: "Sentence length check".into(),
            description: "Warn on overly long sentences".into(),
            rule_type: StyleRuleType::MaxSentenceLength(45),
        });
        profile
    }

    pub fn legal_default() -> Self {
        let mut profile = Self::new("legal_default", "Legal Drafting");
        profile.rules.push(StyleRule {
            id: "avoid_shall".into(),
            name: "Ambiguous 'shall'".into(),
            description: "Consider replacing ambiguous 'shall' with 'must' or 'will'".into(),
            rule_type: StyleRuleType::BannedPhrase {
                phrase: " shall ".into(),
                suggestion: Some(" must ".into()),
            },
        });
        profile
    }

    pub fn lint_text(&self, text: &str) -> Vec<StyleLintMatch> {
        let mut results = Vec::new();

        for rule in &self.rules {
            match &rule.rule_type {
                StyleRuleType::BannedPhrase { phrase, suggestion } => {
                    let lower_text = text.to_lowercase();
                    let lower_phrase = phrase.to_lowercase();
                    let mut start = 0;
                    while let Some(pos) = lower_text[start..].find(&lower_phrase) {
                        let actual_start = start + pos;
                        let actual_end = actual_start + phrase.len();
                        results.push(StyleLintMatch {
                            rule_id: rule.id.clone(),
                            message: format!("Found banned phrase '{}'", phrase),
                            span_start: actual_start,
                            span_end: actual_end,
                            suggestion: suggestion.clone(),
                        });
                        start = actual_end;
                    }
                }
                StyleRuleType::PreferredSpelling { original, preferred } => {
                    let mut start = 0;
                    while let Some(pos) = text[start..].find(original) {
                        let actual_start = start + pos;
                        let actual_end = actual_start + original.len();
                        results.push(StyleLintMatch {
                            rule_id: rule.id.clone(),
                            message: format!("Use preferred spelling '{}' instead of '{}'", preferred, original),
                            span_start: actual_start,
                            span_end: actual_end,
                            suggestion: Some(preferred.clone()),
                        });
                        start = actual_end;
                    }
                }
                StyleRuleType::MaxSentenceLength(max_words) => {
                    let sentences = text.split(&['.', '!', '?'][..]);
                    let mut char_offset = 0;
                    for sentence in sentences {
                        let word_count = sentence.split_whitespace().count();
                        if word_count > *max_words {
                            results.push(StyleLintMatch {
                                rule_id: rule.id.clone(),
                                message: format!("Sentence exceeds {} words (contains {} words)", max_words, word_count),
                                span_start: char_offset,
                                span_end: char_offset + sentence.len(),
                                suggestion: Some("Consider splitting this into multiple sentences".into()),
                            });
                        }
                        char_offset += sentence.len() + 1;
                    }
                }
                _ => {}
            }
        }

        results
    }
}
