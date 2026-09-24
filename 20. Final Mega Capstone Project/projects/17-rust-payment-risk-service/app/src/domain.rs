use serde::{Deserialize,Serialize};
use thiserror::Error;

#[derive(Debug,Deserialize)]
pub struct PaymentDraft { pub merchant_id:String,pub amount:f64,pub country:String }
#[derive(Debug,Serialize,PartialEq)]
pub struct AssessedPayment { pub merchant_id:String,pub amount:f64,pub country:String,pub risk_score:i32,pub decision:String }
#[derive(Debug,Error,PartialEq)]
pub enum ValidationError { #[error("INVALID_MERCHANT")] Merchant,#[error("INVALID_AMOUNT")] Amount,#[error("INVALID_COUNTRY")] Country }

pub fn assess(value:PaymentDraft)->Result<AssessedPayment,ValidationError>{
    let merchant=value.merchant_id.trim().to_uppercase();
    let country=value.country.trim().to_uppercase();
    if merchant.len()<4||merchant.len()>64||!merchant.chars().all(|c|c.is_ascii_alphanumeric()||c=='-'){return Err(ValidationError::Merchant)}
    if !value.amount.is_finite()||value.amount<=0.0||value.amount>1_000_000.0{return Err(ValidationError::Amount)}
    if country.len()!=2||!country.chars().all(|c|c.is_ascii_uppercase()){return Err(ValidationError::Country)}
    let mut score=0;if value.amount>=10_000.0{score+=55}if matches!(country.as_str(),"IR"|"KP"|"SY"){score+=45}
    let decision=if score>=80{"review"}else if score>=55{"step_up"}else{"approve"}.to_string();
    Ok(AssessedPayment{merchant_id:merchant,amount:value.amount,country,risk_score:score,decision})
}
