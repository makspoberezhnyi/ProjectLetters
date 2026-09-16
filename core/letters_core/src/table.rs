use crate::error::{LettersError, Result};
use evalexpr::{eval_with_context, ContextWithMutableVariables, HashMapContext, Value};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum CellValue {
    Text(String),
    Number(f64),
    Formula(String),
    Empty,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct TableCell {
    pub raw_value: CellValue,
    pub evaluated_value: Option<String>,
    pub variable_tag: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct DynamicTable {
    pub id: String,
    pub rows: usize,
    pub cols: usize,
    pub cells: Vec<Vec<TableCell>>,
}

impl DynamicTable {
    pub fn new(id: impl Into<String>, rows: usize, cols: usize) -> Self {
        let mut cells = Vec::with_capacity(rows);
        for _ in 0..rows {
            let mut row = Vec::with_capacity(cols);
            for _ in 0..cols {
                row.push(TableCell {
                    raw_value: CellValue::Empty,
                    evaluated_value: None,
                    variable_tag: None,
                });
            }
            cells.push(row);
        }

        Self {
            id: id.into(),
            rows,
            cols,
            cells,
        }
    }

    pub fn set_cell(&mut self, row: usize, col: usize, val: CellValue, variable_tag: Option<String>) {
        if row < self.rows && col < self.cols {
            self.cells[row][col] = TableCell {
                raw_value: val,
                evaluated_value: None,
                variable_tag,
            };
        }
    }

    /// Evaluates all formulas in the table and returns a variable map for inline document text references
    pub fn evaluate(&mut self) -> Result<HashMap<String, String>> {
        let mut context = HashMapContext::new();
        let mut var_map = HashMap::new();

        // Pass 1: populate literal numbers and variable tags
        for r in 0..self.rows {
            for c in 0..self.cols {
                let cell = &self.cells[r][c];
                let cell_key = format!("c{}_{}", r, c);
                if let CellValue::Number(num) = cell.raw_value {
                    let _ = context.set_value(cell_key.clone(), Value::from(num));
                    if let Some(tag) = &cell.variable_tag {
                        let _ = context.set_value(tag.clone(), Value::from(num));
                        var_map.insert(tag.clone(), num.to_string());
                    }
                }
            }
        }

        // Pass 2: evaluate formulas
        for r in 0..self.rows {
            for c in 0..self.cols {
                let cell = &mut self.cells[r][c];
                match &cell.raw_value {
                    CellValue::Formula(expr) => {
                        let sanitized_expr = expr.trim_start_matches('=');
                        match eval_with_context(sanitized_expr, &context) {
                            Ok(val) => {
                                let val_str = val.to_string();
                                cell.evaluated_value = Some(val_str.clone());
                                if let Value::Float(f) = val {
                                    let cell_key = format!("c{}_{}", r, c);
                                    let _ = context.set_value(cell_key, Value::from(f));
                                    if let Some(tag) = &cell.variable_tag {
                                        let _ = context.set_value(tag.clone(), Value::from(f));
                                        var_map.insert(tag.clone(), val_str);
                                    }
                                } else if let Value::Int(i) = val {
                                    let cell_key = format!("c{}_{}", r, c);
                                    let _ = context.set_value(cell_key, Value::from(i));
                                    if let Some(tag) = &cell.variable_tag {
                                        let _ = context.set_value(tag.clone(), Value::from(i));
                                        var_map.insert(tag.clone(), val_str);
                                    }
                                }
                            }
                            Err(e) => {
                                return Err(LettersError::Formula(format!(
                                    "Error evaluating cell ({}, {}): {}",
                                    r, c, e
                                )));
                            }
                        }
                    }
                    CellValue::Number(num) => {
                        cell.evaluated_value = Some(num.to_string());
                    }
                    CellValue::Text(t) => {
                        cell.evaluated_value = Some(t.clone());
                        if let Some(tag) = &cell.variable_tag {
                            var_map.insert(tag.clone(), t.clone());
                        }
                    }
                    CellValue::Empty => {
                        cell.evaluated_value = Some(String::new());
                    }
                }
            }
        }

        Ok(var_map)
    }
}
