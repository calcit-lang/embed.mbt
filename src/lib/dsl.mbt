///|
enum CalcitValue {
  Nil
  Number(Double)
  String(String)
  Boolean(Bool)
  Json(Json)
  Function(String?, Array[String], Array[@cirru.Cirru])
} derive(ToJson, @json.FromJson, Eq, Show)

///|
type! CalcitEvalError String

///| interpret_cirru parses Cirru code and returns a CalcitValue.
pub fn interpret_cirru(
  code : String,
  context? : Map[String, CalcitValue]
) -> CalcitValue!CalcitEvalError {
  let context = context.or({})
  let tree = match @cirru.parse?(code) {
    Err(err) => raise CalcitEvalError("Cirru parse error: \{err.to_string()}")
    Ok(tree) => tree
  }
  let mut ret = CalcitValue::Nil
  for line in tree {
    ret = interpret_line!(line, context)
  }
  ret
}

///|
pub fn interpret_line(
  line : @cirru.Cirru,
  context : Map[String, CalcitValue]
) -> CalcitValue!CalcitEvalError {
  match line {
    List(xs) =>
      match xs {
        [Leaf("if"), .. xs] => ...
        _ =>
          raise CalcitEvalError("Unsupported line format: " + line.to_string())
      }
    Leaf(token) => interpret_token!(token.to_string(), context)
  }
}

///|
fn interpret_token(
  token : String,
  context : Map[String, CalcitValue]
) -> CalcitValue!CalcitEvalError {
  match token {
    "" => raise CalcitEvalError("Empty token encountered")
    ['|', .. xs] => CalcitValue::String(xs.to_string())
    "true" => CalcitValue::Boolean(true)
    "false" => CalcitValue::Boolean(false)
    "nil" => CalcitValue::Nil
    x => {
      if context.get(x) is Some(value) {
        return value
      }
      if @strconv.parse_int?(x) is Ok(i) {
        return CalcitValue::Number(i.to_double())
      }
      if @strconv.parse_double?(x) is Ok(f) {
        return CalcitValue::Number(f)
      }
      raise CalcitEvalError("Unknown token: " + x)
    }
  }
}
