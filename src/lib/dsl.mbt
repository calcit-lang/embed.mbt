///|
typealias @cirru.Cirru

///|
enum CalcitValue {
  Nil
  Number(Double)
  String(String)
  Boolean(Bool)
  Json(Json)
  Function(String?, Array[String], Array[Cirru])
  Quote(Cirru)
} derive(ToJson, @json.FromJson, Eq, Show)

///|
type! CalcitEvalError String

///| interpret_cirru parses Cirru code and returns a CalcitValue.
pub fn interpret_cirru(
  code : String,
  context? : Map[String, CalcitValue]
) -> CalcitValue!CalcitEvalError {
  let context = context.or({})
  let tree = match Cirru::parse?(code) {
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
  line : Cirru,
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

        // list & map operations
        [Leaf("list"), ..items] => {
          let mut values : Array[CalcitValue] = []
          for item in items {
            values.push(interpret_expr!(item, context))
          }
          CalcitValue::List(values)
        }
        [Leaf("map"), ..items] if items.length() % 2 == 0 => {
          let mut map_values : Map[String, CalcitValue] = {}
          for i = 0; i < items.length(); i = i + 2 {
            let key_item = items[i]
            let value_item = items[i+1]
            match key_item {
              Leaf(s) => {
                map_values.set(s, interpret_expr!(value_item, context))
              }
              _ => raise CalcitEvalError("Map keys must be strings")
            }
          }
          CalcitValue::Map(map_values)
        }
        [Leaf("map"), ..] => raise CalcitEvalError("Map requires an even number of arguments for key-value pairs")
        [Leaf("get"), target, key_or_index] => {
          let target_value = interpret_expr!(target, context)
          match target_value {
            List(l) => {
              let index_value = interpret_expr!(key_or_index, context)
              match index_value {
                Number(n) => {
                  let idx = n.to_int()
                  if idx >= 0 && idx < l.length() {
                    l[idx]
                  } else {
                    CalcitValue::Nil // Or raise error: "Index out of bounds"
                  }
                }
                _ => raise CalcitEvalError("List index must be a number")
              }
            }
            Map(m) => {
              match key_or_index {
                Leaf(key_str) => m.get(key_str).or(CalcitValue::Nil)
                String(key_str) => m.get(key_str).or(CalcitValue::Nil) // if keys are interpreted as CalcitValue::String
                _ => raise CalcitEvalError("Map key must be a leaf string or a string value")
              }
            }
            _ => raise CalcitEvalError("Get operation target must be a list or map: " + target_value.to_string())
          }
        }
        [Leaf("assoc"), target, key_or_index, value_to_assoc] => {
          let target_value = interpret_expr!(target, context)
          let val = interpret_expr!(value_to_assoc, context)
          match target_value {
            List(l) => {
              let index_value = interpret_expr!(key_or_index, context)
              match index_value {
                Number(n) => {
                  let idx = n.to_int()
                  if idx >= 0 && idx < l.length() {
                    let mut new_l = l.copy()
                    new_l[idx] = val
                    CalcitValue::List(new_l)
                  } else {
                    raise CalcitEvalError("Assoc: Index out of bounds")
                  }
                }
                _ => raise CalcitEvalError("Assoc: List index must be a number")
              }
            }
            Map(m) => {
              match key_or_index {
                Leaf(key_str) => {
                  let mut new_m = m.copy()
                  new_m.set(key_str, val)
                  CalcitValue::Map(new_m)
                }
                // String(key_str) => { ... } // if keys are interpreted as CalcitValue::String
                _ => raise CalcitEvalError("Assoc: Map key must be a leaf string")
              }
            }
            _ => raise CalcitEvalError("Assoc operation target must be a list or map: " + target_value.to_string())
          }
        }
        [Leaf("count"), target] => {
          let target_value = interpret_expr!(target, context)
          match target_value {
            List(l) => CalcitValue::Number(l.length().to_double())
            Map(m) => CalcitValue::Number(m.size().to_double())
            _ => raise CalcitEvalError("Count operation target must be a list or map: " + target_value.to_string())
          }
        }
        [Leaf("conj"), target, ..items_to_add] => {
          let target_value = interpret_expr!(target, context)
          match target_value {
            List(l) => {
              let mut new_l = l.copy()
              for item in items_to_add {
                new_l.push(interpret_expr!(item, context))
              }
              CalcitValue::List(new_l)
            }
            Map(m) => {
              if items_to_add.length() % 2 != 0 {
                raise CalcitEvalError("Conj on map requires an even number of items for key-value pairs")
              }
              let mut new_m = m.copy()
              for i = 0; i < items_to_add.length(); i = i + 2 {
                let key_item = items_to_add[i]
                let value_item = items_to_add[i+1]
                match key_item {
                  Leaf(s) => {
                    new_m.set(s, interpret_expr!(value_item, context))
                  }
                  _ => raise CalcitEvalError("Conj: Map keys must be strings")
                }
              }
              CalcitValue::Map(new_m)
            }
            _ => raise CalcitEvalError("Conj operation target must be a list or map: " + target_value.to_string())
          }
        }
        [Leaf("dissoc"), target, key_to_dissoc] => {
          let target_value = interpret_expr!(target, context)
          match target_value {
            Map(m) => {
              match key_to_dissoc {
                Leaf(key_str) => {
                  let mut new_m = m.copy()
                  new_m.remove(key_str)
                  CalcitValue::Map(new_m)
                }
                _ => raise CalcitEvalError("Dissoc: Map key must be a leaf string")
              }
            }
            _ => raise CalcitEvalError("Dissoc operation target must be a map: " + target_value.to_string())
          }
        }
        [Leaf("first"), target] => {
          let target_value = interpret_expr!(target, context)
          match target_value {
            List(l) => {
              if l.length() > 0 {
                l[0]
              } else {
                CalcitValue::Nil
              }
            }
            _ => raise CalcitEvalError("First operation target must be a list: " + target_value.to_string())
          }
        }
        [Leaf("rest"), target] => {
          let target_value = interpret_expr!(target, context)
          match target_value {
            List(l) => {
              if l.length() > 1 {
                CalcitValue::List(l[1..].to_array())
              } else {
                CalcitValue::List([])
              }
            }
            _ => raise CalcitEvalError("Rest operation target must be a list: " + target_value.to_string())
          }
        }

        // math
        [Leaf("+"), .. xs] if xs.length() > 0 => {
          let mut sum = 0.0
          for x in xs {
            let value = interpret_expr!(x, context)
            if value is Number(n) {
              sum += n
            } else {
              raise CalcitEvalError(
                "Expected a number, got: " + value.to_string(),
              )
            }
          }
          CalcitValue::Number(sum)
        }
        [Leaf("+")] =>
          raise CalcitEvalError("Plus must have at least one argument")
        [Leaf("-"), .. xs] if xs.length() > 0 => {
          let mut result = 0.0
          if xs.length() == 1 {
            let ret = interpret_expr!(xs[0], context)
            if ret is Number(n) {
              result = n
            } else {
              raise CalcitEvalError(
                "Expected a number, got: " + ret.to_string(),
              )
            }
          } else {
            let ret = interpret_expr!(xs[0], context)
            if ret is Number(n) {
              result = n
            } else {
              raise CalcitEvalError(
                "Expected a number, got: " + ret.to_string(),
              )
            }
            for x in xs[1:] {
              let value = interpret_expr!(x, context)
              if value is Number(n) {
                result -= n
              } else {
                raise CalcitEvalError(
                  "Expected a number, got: " + value.to_string(),
                )
              }
            }
          }
          CalcitValue::Number(result)
        }
        [Leaf("-"), ..] =>
          raise CalcitEvalError("Minus must have at least one argument")
        [Leaf("*"), .. xs] if xs.length() > 0 => {
          let mut product = 1.0
          for x in xs {
            let value = interpret_expr!(x, context)
            if value is Number(n) {
              product *= n
            } else {
              raise CalcitEvalError(
                "Expected a number, got: " + value.to_string(),
              )
            }
          }
          CalcitValue::Number(product)
        }
        [Leaf("*")] =>
          raise CalcitEvalError("Multiply must have at least one argument")
        [Leaf("/"), .. xs] if xs.length() > 0 => {
          let mut result = 1.0
          if xs.length() == 1 {
            let ret = interpret_expr!(xs[0], context)
            if ret is Number(n) {
              result = n
            } else {
              raise CalcitEvalError(
                "Expected a number, got: " + ret.to_string(),
              )
            }
          } else {
            let ret = interpret_expr!(xs[0], context)
            if ret is Number(n) {
              result = n
            } else {
              raise CalcitEvalError(
                "Expected a number, got: " + ret.to_string(),
              )
            }
            for x in xs[1:] {
              let value = interpret_expr!(x, context)
              if value is Number(n) {
                if n == 0.0 {
                  raise CalcitEvalError("Division by zero")
                }
                result /= n
              } else {
                raise CalcitEvalError(
                  "Expected a number, got: " + value.to_string(),
                )
              }
            }
          }
          CalcitValue::Number(result)
        }
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
