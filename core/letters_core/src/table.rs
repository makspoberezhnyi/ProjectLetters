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
        let mut pending_formulas = Vec::new();

        // Pass 1: Set up literals and record which cells need evaluation
        for r in 0..self.rows {
            for c in 0..self.cols {
                let cell = &self.cells[r][c];
                let cell_key = format!("c{}_{}", r, c);
                match &cell.raw_value {
                    CellValue::Number(num) => {
                        let _ = context.set_value(cell_key.clone(), Value::from(*num));
                        if let Some(tag) = &cell.variable_tag {
                            let _ = context.set_value(tag.clone(), Value::from(*num));
                            var_map.insert(tag.clone(), num.to_string());
                        }
                    }
                    CellValue::Text(t) => {
                        let _ = context.set_value(cell_key.clone(), Value::from(t.as_str()));
                        if let Some(tag) = &cell.variable_tag {
                            let _ = context.set_value(tag.clone(), Value::from(t.as_str()));
                            var_map.insert(tag.clone(), t.clone());
                        }
                    }
                    CellValue::Empty => {} // Do nothing
                    CellValue::Formula(expr) => {
                        pending_formulas.push((r, c, expr.clone()));
                    }
                }
            }
        }

        // Pass 2: Evaluate formulas via fixpoint iteration to resolve dependencies
        let mut progress = true;
        while progress && !pending_formulas.is_empty() {
            progress = false;
            let mut next_pending = Vec::new();

            for (r, c, expr) in pending_formulas {
                let sanitized_expr = expr.trim_start_matches('=');
                match eval_with_context(sanitized_expr, &context) {
                    Ok(val) => {
                        progress = true;
                        let cell_key = format!("c{}_{}", r, c);
                        let val_str = val.to_string();
                        
                        let cell = &mut self.cells[r][c];
                        cell.evaluated_value = Some(val_str.clone());

                        if let Value::Float(f) = val {
                            let _ = context.set_value(cell_key.clone(), Value::from(f));
                            if let Some(tag) = &cell.variable_tag {
                                let _ = context.set_value(tag.clone(), Value::from(f));
                                var_map.insert(tag.clone(), val_str);
                            }
                        } else if let Value::Int(i) = val {
                            let _ = context.set_value(cell_key.clone(), Value::from(i));
                            if let Some(tag) = &cell.variable_tag {
                                let _ = context.set_value(tag.clone(), Value::from(i));
                                var_map.insert(tag.clone(), val_str);
                            }
                        } else {
                            let _ = context.set_value(cell_key.clone(), val.clone());
                            if let Some(tag) = &cell.variable_tag {
                                let _ = context.set_value(tag.clone(), val.clone());
                                var_map.insert(tag.clone(), val_str);
                            }
                        }
                    }
                    Err(_) => {
                        // Variable might not be evaluated yet
                        next_pending.push((r, c, expr));
                    }
                }
            }
            pending_formulas = next_pending;
        }

        if !pending_formulas.is_empty() {
            return Err(LettersError::Formula(format!(
                "Circular dependency or undefined variable in {} cells",
                pending_formulas.len()
            )));
        }

        // Pass 3: Fill evaluated values for literals
        for r in 0..self.rows {
            for c in 0..self.cols {
                let cell = &mut self.cells[r][c];
                match &cell.raw_value {
                    CellValue::Number(num) => cell.evaluated_value = Some(num.to_string()),
                    CellValue::Text(t) => cell.evaluated_value = Some(t.clone()),
                    CellValue::Empty => cell.evaluated_value = Some(String::new()),
                    CellValue::Formula(_) => {} // Handled above
                }
            }
        }

        Ok(var_map)
    }
}
