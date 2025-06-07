use src/lib/dsl::{CalcitValue, CalcitEvalError, interpret_cirru}
use moon::test::{assert_eq, assert_true, assert_false}

test "literal number evaluation" {
  let result = interpret_cirru("123", {})
  assert_eq!(result, Ok(CalcitValue::Number(123.0)))
}

test "literal string evaluation" {
  let result = interpret_cirru("\"hello\"", {}) // Assuming strings are defined with quotes
  assert_eq!(result, Ok(CalcitValue::String("hello")))
}

test "literal string evaluation with pipe" {
  let result = interpret_cirru("|hello", {})
  assert_eq!(result, Ok(CalcitValue::String("hello")))
}

test "literal boolean true evaluation" {
  let result = interpret_cirru("true", {})
  assert_eq!(result, Ok(CalcitValue::Boolean(true)))
}

test "literal boolean false evaluation" {
  let result = interpret_cirru("false", {})
  assert_eq!(result, Ok(CalcitValue::Boolean(false)))
}

test "literal nil evaluation" {
  let result = interpret_cirru("nil", {})
  assert_eq!(result, Ok(CalcitValue::Nil))
}

test "function definition and call" {
  let code = "
  (def add (fn (a b) (+ a b)))
  (add 1 2)
  "
  let result = interpret_cirru(code, {})
  assert_eq!(result, Ok(CalcitValue::Number(3.0)))
}

test "function definition and call with more complex body" {
  let code = "
  (def calc (fn (a b c) (+ a (* b c))))
  (calc 2 3 4)
  "
  let result = interpret_cirru(code, {})
  assert_eq!(result, Ok(CalcitValue::Number(14.0)))
}

test "function call with wrong number of arguments - too few" {
  let code = "
  (def add (fn (a b) (+ a b)))
  (add 1)
  "
  let result = interpret_cirru(code, {})
  assert_true!(result.is_err())
  match result {
    Err(CalcitEvalError(msg)) => {
      // The error message might vary slightly based on exact implementation
      assert_true!(msg.contains("expects 2 arguments, got 1"))
    }
    Ok(_) => assert_true!(false)
  }
}

test "function call with wrong number of arguments - too many" {
  let code = "
  (def add (fn (a b) (+ a b)))
  (add 1 2 3)
  "
  let result = interpret_cirru(code, {})
  assert_true!(result.is_err())
  match result {
    Err(CalcitEvalError(msg)) => {
      assert_true!(msg.contains("expects 2 arguments, got 3"))
    }
    Ok(_) => assert_true!(false)
  }
}

// TODO: Test for anonymous function calls if supported: interpret_cirru("((fn (a b) (+ a b)) 1 2)", {})

test "list creation" {
  let result = interpret_cirru("(list 1 |two true nil)", {})
  let expected_list = CalcitValue::List([
    CalcitValue::Number(1.0),
    CalcitValue::String("two"),
    CalcitValue::Boolean(true),
    CalcitValue::Nil,
  ])
  assert_eq!(result, Ok(expected_list))
}

test "map creation" {
  let result = interpret_cirru("(map |a 1 |b |two |c true |d nil)", {})
  let mut expected_map_values : Map[String, CalcitValue] = {:}
  expected_map_values.set("a", CalcitValue::Number(1.0))
  expected_map_values.set("b", CalcitValue::String("two"))
  expected_map_values.set("c", CalcitValue::Boolean(true))
  expected_map_values.set("d", CalcitValue::Nil)
  assert_eq!(result, Ok(CalcitValue::Map(expected_map_values)))
}

test "map creation with duplicate keys (last one wins)" {
   let result = interpret_cirru("(map |a 1 |b 2 |a 3)", {})
   let mut expected_map_values : Map[String, CalcitValue] = {:}
   expected_map_values.set("a", CalcitValue::Number(3.0))
   expected_map_values.set("b", CalcitValue::Number(2.0))
   assert_eq!(result, Ok(CalcitValue::Map(expected_map_values)))
}

test "map creation - uneven number of arguments" {
  let result = interpret_cirru("(map |a 1 |b)", {})
  assert_true!(result.is_err())
  match result {
    Err(CalcitEvalError(msg)) => {
      assert_true!(msg.contains("Map requires an even number of arguments"))
    }
    Ok(_) => assert_true!(false)
  }
}

test "map creation - key not a string" {
  let result = interpret_cirru("(map 1 1 |b 2)", {})
  assert_true!(result.is_err())
  match result {
    Err(CalcitEvalError(msg)) => {
      assert_true!(msg.contains("Map keys must be strings"))
    }
    Ok(_) => assert_true!(false)
  }
}


test "map get value" {
  let result = interpret_cirru("(get (map |a 10 |b 20) |b)", {})
  assert_eq!(result, Ok(CalcitValue::Number(20.0)))
}

test "map get value - key not found" {
  let result = interpret_cirru("(get (map |a 10) |c)", {})
  assert_eq!(result, Ok(CalcitValue::Nil)) // Expect Nil for missing keys
}

test "map get value - key not a leaf string or CalcitValue::String" {
  let result = interpret_cirru("(get (map |a 10) 1)", {}) // Using a number as key
  assert_true!(result.is_err())
   match result {
    Err(CalcitEvalError(msg)) => {
      assert_true!(msg.contains("Map key must be a leaf string or a string value"))
    }
    Ok(_) => assert_true!(false)
  }
}

test "map assoc value" {
  let result = interpret_cirru("(assoc (map |a 1 |b 2) |c 3)", {})
  let mut expected_map_values : Map[String, CalcitValue] = {:}
  expected_map_values.set("a", CalcitValue::Number(1.0))
  expected_map_values.set("b", CalcitValue::Number(2.0))
  expected_map_values.set("c", CalcitValue::Number(3.0))
  assert_eq!(result, Ok(CalcitValue::Map(expected_map_values)))
}

test "map assoc value - update existing key" {
  let result = interpret_cirru("(assoc (map |a 1 |b 2) |a 3)", {})
  let mut expected_map_values : Map[String, CalcitValue] = {:}
  expected_map_values.set("a", CalcitValue::Number(3.0))
  expected_map_values.set("b", CalcitValue::Number(2.0))
  assert_eq!(result, Ok(CalcitValue::Map(expected_map_values)))
}

test "map assoc - key not a leaf string" {
  let result = interpret_cirru("(assoc (map |a 1) 1 2)", {})
  assert_true!(result.is_err())
   match result {
    Err(CalcitEvalError(msg)) => {
      assert_true!(msg.contains("Assoc: Map key must be a leaf string"))
    }
    Ok(_) => assert_true!(false)
  }
}

test "map count" {
  let result = interpret_cirru("(count (map |a 1 |b 2 |c 3))", {})
  assert_eq!(result, Ok(CalcitValue::Number(3.0)))
}

test "map count on empty map" {
  let result = interpret_cirru("(count (map))", {})
  assert_eq!(result, Ok(CalcitValue::Number(0.0)))
}

test "map dissoc key" {
  let result = interpret_cirru("(dissoc (map |a 1 |b 2 |c 3) |b)", {})
  let mut expected_map_values : Map[String, CalcitValue] = {:}
  expected_map_values.set("a", CalcitValue::Number(1.0))
  expected_map_values.set("c", CalcitValue::Number(3.0))
  assert_eq!(result, Ok(CalcitValue::Map(expected_map_values)))
}

test "map dissoc - key not found" {
  let code = "(dissoc (map |a 1) |b)"
  let result = interpret_cirru(code, {})
  let mut expected_map_values : Map[String, CalcitValue] = {:}
  expected_map_values.set("a", CalcitValue::Number(1.0))
  assert_eq!(result, Ok(CalcitValue::Map(expected_map_values))) // Should be a no-op
}

test "map dissoc - key not a leaf string" {
  let result = interpret_cirru("(dissoc (map |a 1) 1)", {})
  assert_true!(result.is_err())
   match result {
    Err(CalcitEvalError(msg)) => {
      assert_true!(msg.contains("Dissoc: Map key must be a leaf string"))
    }
    Ok(_) => assert_true!(false)
  }
}

test "map conj key-value pairs" {
  let result = interpret_cirru("(conj (map |a 1) |b 2 |c |three)", {})
  let mut expected_map_values : Map[String, CalcitValue] = {:}
  expected_map_values.set("a", CalcitValue::Number(1.0))
  expected_map_values.set("b", CalcitValue::Number(2.0))
  expected_map_values.set("c", CalcitValue::String("three"))
  assert_eq!(result, Ok(CalcitValue::Map(expected_map_values)))
}

test "map conj - uneven number of items to add" {
  let result = interpret_cirru("(conj (map |a 1) |b 2 |c)", {})
  assert_true!(result.is_err())
  match result {
    Err(CalcitEvalError(msg)) => {
      assert_true!(msg.contains("Conj on map requires an even number of items"))
    }
    Ok(_) => assert_true!(false)
  }
}

test "map conj - key not a string" {
  let result = interpret_cirru("(conj (map |a 1) 1 2)", {})
  assert_true!(result.is_err())
  match result {
    Err(CalcitEvalError(msg)) => {
      assert_true!(msg.contains("Conj: Map keys must be strings"))
    }
    Ok(_) => assert_true!(false)
  }
}

// General Error Handling Tests
test "invalid operation - plus with string" {
  let result = interpret_cirru("(+ 1 |a)", {})
  assert_true!(result.is_err())
  match result {
    Err(CalcitEvalError(msg)) => {
      assert_true!(msg.contains("Expected a number, got: String(a)"))
    }
    Ok(_) => assert_true!(false)
  }
}

test "unknown token" {
  let result = interpret_cirru("unknown_token", {})
  assert_true!(result.is_err())
  match result {
    Err(CalcitEvalError(msg)) => {
      assert_true!(msg.contains("Unknown token: unknown_token"))
    }
    Ok(_) => assert_true!(false)
  }
}

test "empty input" {
  let result = interpret_cirru("", {})
  // This might depend on how Cirru::parse? handles empty strings.
  // Assuming it might lead to an error or a specific CalcitValue (e.g. Nil if parse returns empty list)
  // Based on current interpret_cirru, Cirru::parse? error is caught.
  assert_true!(result.is_err())
   match result {
    Err(CalcitEvalError(msg)) => {
      // Example: "Cirru parse error: ..." or specific error for empty parse result
      assert_true!(msg.contains("Cirru parse error"))
    }
    Ok(_) => assert_true!(false)
  }
}

test "unsupported line format" {
  // This test depends on how `interpret_expr` handles unrecognized structures.
  // For example, a list that doesn't match any known operation pattern.
  // We need a Cirru structure that is valid Cirru but not a valid Calcit operation.
  // (Leaf("some_unknown_operation") 1 2) might be treated as a function call.
  // Let's try a list of lists without an operator: ((1 2) (3 4))
  let result = interpret_cirru("((1 2) (3 4))", {})
  assert_true!(result.is_err())
  match result {
    Err(CalcitEvalError(msg)) => {
      assert_true!(msg.contains("Unsupported line format") || msg.contains("Not a function"))
    }
    Ok(_) => assert_true!(false)
  }
}

test "list get element" {
  let result = interpret_cirru("(get (list 10 20 30) 1)", {})
  assert_eq!(result, Ok(CalcitValue::Number(20.0)))
}

test "list get element - index out of bounds (positive)" {
  let result = interpret_cirru("(get (list 10 20 30) 3)", {})
  // Expecting Nil for out-of-bounds, as per current `get` implementation for lists
  assert_eq!(result, Ok(CalcitValue::Nil))
}

test "list get element - index out of bounds (negative)" {
  let result = interpret_cirru("(get (list 10 20 30) -1)", {})
   // Expecting Nil for out-of-bounds
  assert_eq!(result, Ok(CalcitValue::Nil))
}


test "list get element - non-number index" {
  let result = interpret_cirru("(get (list 10 20 30) |a)", {})
  assert_true!(result.is_err())
  match result {
    Err(CalcitEvalError(msg)) => {
      assert_true!(msg.contains("List index must be a number"))
    }
    Ok(_) => assert_true!(false)
  }
}

test "list assoc element" {
  let result = interpret_cirru("(assoc (list 1 2 3) 1 4)", {})
  let expected_list = CalcitValue::List([
    CalcitValue::Number(1.0),
    CalcitValue::Number(4.0),
    CalcitValue::Number(3.0),
  ])
  assert_eq!(result, Ok(expected_list))
}

test "list assoc element - index out of bounds" {
  let result = interpret_cirru("(assoc (list 1 2 3) 3 4)", {})
  assert_true!(result.is_err())
  match result {
    Err(CalcitEvalError(msg)) => {
      assert_true!(msg.contains("Assoc: Index out of bounds"))
    }
    Ok(_) => assert_true!(false)
  }
}

test "list count" {
  let result = interpret_cirru("(count (list 1 2 3 |four))", {})
  assert_eq!(result, Ok(CalcitValue::Number(4.0)))
}

test "list count on empty list" {
  let result = interpret_cirru("(count (list))", {})
  assert_eq!(result, Ok(CalcitValue::Number(0.0)))
}

test "list first element" {
  let result = interpret_cirru("(first (list 10 20))", {})
  assert_eq!(result, Ok(CalcitValue::Number(10.0)))
}

test "list first on empty list" {
  let result = interpret_cirru("(first (list))", {})
  assert_eq!(result, Ok(CalcitValue::Nil))
}

test "list rest" {
  let result = interpret_cirru("(rest (list 1 2 3))", {})
  let expected_list = CalcitValue::List([
    CalcitValue::Number(2.0),
    CalcitValue::Number(3.0),
  ])
  assert_eq!(result, Ok(expected_list))
}

test "list rest on list with one element" {
  let result = interpret_cirru("(rest (list 1))", {})
  let expected_list = CalcitValue::List([])
  assert_eq!(result, Ok(expected_list))
}

test "list rest on empty list" {
  let result = interpret_cirru("(rest (list))", {})
  let expected_list = CalcitValue::List([])
  assert_eq!(result, Ok(expected_list))
}

test "list conj elements" {
  let result = interpret_cirru("(conj (list 1 2) 3 |four)", {})
  let expected_list = CalcitValue::List([
    CalcitValue::Number(1.0),
    CalcitValue::Number(2.0),
    CalcitValue::Number(3.0),
    CalcitValue::String("four"),
  ])
  assert_eq!(result, Ok(expected_list))
}

test "list conj to empty list" {
  let result = interpret_cirru("(conj (list) 1 2)", {})
  let expected_list = CalcitValue::List([
    CalcitValue::Number(1.0),
    CalcitValue::Number(2.0),
  ])
  assert_eq!(result, Ok(expected_list))
}

test "variable definition and lookup" {
  let result = interpret_cirru("(def a 1) \n a", {})
  assert_eq!(result, Ok(CalcitValue::Number(1.0)))
}

test "variable definition and lookup with string" {
  let result = interpret_cirru("(def s |hello) \n s", {})
  assert_eq!(result, Ok(CalcitValue::String("hello")))
}

test "if true expression" {
  let result = interpret_cirru("(if true 1 2)", {})
  assert_eq!(result, Ok(CalcitValue::Number(1.0)))
}

test "if false expression" {
  let result = interpret_cirru("(if false 1 2)", {})
  assert_eq!(result, Ok(CalcitValue::Number(2.0)))
}

test "if with nil condition (expected error or specific behavior)" {
  // Current implementation of `if` expects a Boolean.
  // Nil is not a boolean, so it should raise an error.
  let result = interpret_cirru("(if nil 1 2)", {})
  assert_true!(result.is_err())
  match result {
    Err(CalcitEvalError(msg)) => {
      assert_true!(msg.contains("Condition must be a boolean"))
    }
    Ok(_) => assert_true!(false) // Should not happen
  }
}

test "if with non-boolean number condition" {
  let result = interpret_cirru("(if 1 1 2)", {})
  assert_true!(result.is_err())
  match result {
    Err(CalcitEvalError(msg)) => {
      assert_true!(msg.contains("Condition must be a boolean"))
    }
    Ok(_) => assert_true!(false) // Should not happen
  }
}

test "if with only then branch - true" {
  let result = interpret_cirru("(if true 1)", {})
  assert_eq!(result, Ok(CalcitValue::Number(1.0)))
}

test "if with only then branch - false" {
  let result = interpret_cirru("(if false 1)", {})
  assert_eq!(result, Ok(CalcitValue::Nil))
}
