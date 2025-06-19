///|
test "basic data types" {
  assert_eq(interpret_cirru("do 1"), Number(1.0))
  assert_eq(interpret_cirru("do 1.5"), Number(1.5))
  // bool
  assert_eq(interpret_cirru("do true"), Bool(true))
  assert_eq(interpret_cirru("do false"), Bool(false))
  // nil
  assert_eq(interpret_cirru("do nil"), Nil)
  // string
  assert_eq(interpret_cirru("do \"|hello\""), String("hello"))
  assert_eq(interpret_cirru("do \"|\""), String(""))
  assert_eq(interpret_cirru("do |hello"), String("hello"))
}
