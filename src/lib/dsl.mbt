///|
enum CalcitValue {
  Nil
  Number(Double)
  String(String)
  Boolean(Bool)
  Json(Json)
  Function(String?, Array[String], Array[@cirru.Cirru])
  Quote(@cirru.Cirru)
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
    ret = interpret_expr!(line, context)
  }
  ret
}

///|
pub fn interpret_expr(
  line : @cirru.Cirru,
  context : Map[String, CalcitValue]
) -> CalcitValue!CalcitEvalError {
  match line {
    List(xs) =>
      match xs {
        // if
        [Leaf("if"), cond, then_branch, else_branch] => {
          let cond_value = interpret_expr!(cond, context)
          if cond_value is Boolean(b) {
            if b {
              interpret_expr!(then_branch, context)
            } else {
              interpret_expr!(else_branch, context)
            }
          } else {
            raise CalcitEvalError(
              "Condition must be a boolean: " + cond_value.to_string(),
            )
          }
        }
        [Leaf("if"), cond, then_branch] => {
          let cond_value = interpret_expr!(cond, context)
          if cond_value is Boolean(b) {
            if b {
              interpret_expr!(then_branch, context)
            } else {
              CalcitValue::Nil
            }
          } else {
            raise CalcitEvalError(
              "Condition must be a boolean: " + cond_value.to_string(),
            )
          }
        }
        [Leaf("if"), ..] => raise CalcitEvalError("If takes 1 or 2 arguments")
        // def
        [Leaf("def"), Leaf(name), value] => {
          let value = interpret_expr!(value, context)
          context.set(name, value)
          value
        }
        [Leaf("def"), ..] =>
          raise CalcitEvalError("Def must have a name and a value")
        // quote
        [Leaf("quote"), expr] => CalcitValue::Quote(expr)
        [Leaf("quote"), ..] =>
          raise CalcitEvalError("Quote must have one argument")
        // function
        [Leaf("fn"), Leaf(name), List(args), .. body] => {
          let arg_names : Array[String] = []
          for arg in args {
            match arg {
              Leaf(arg_name) => arg_names.push(arg_name)
              _ => raise CalcitEvalError("Function arguments must be names")
            }
          }
          CalcitValue::Function(Some(name), arg_names, body.to_array())
        }
        [Leaf("fn"), List(args), .. body] => {
          let arg_names : Array[String] = []
          for arg in args {
            match arg {
              Leaf(arg_name) => arg_names.push(arg_name)
              _ => raise CalcitEvalError("Function arguments must be names")
            }
          }
          CalcitValue::Function(None, arg_names, body.to_array())
        }
        [Leaf(f), .. xs] => {
          let f_value = interpret_token!(f, context)
          if f_value is Function(name, args, body) {
            if xs.length() != args.length() {
              let f0 = name.or("\\")
              raise CalcitEvalError(
                "Function \{name.or(f0)} expects \{args.length()} arguments, got \{xs.length()}",
              )
            }
            let new_context : Map[String, CalcitValue] = {}
            for k, value in context {
              new_context.set(k, value)
            }
            for idx, value in args {
              new_context.set(value, interpret_expr!(xs[idx], context))
            }
            let mut result = CalcitValue::Nil
            for expr in body {
              result = interpret_expr!(expr, new_context)
            }
            result
          } else {
            raise CalcitEvalError("Not a function: " + f_value.to_string())
          }
        }
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
