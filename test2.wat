(module
  (func $add (export "add") (param $lhs i32) (param $rhs i32) (result i32)
    local.get $lhs
    local.get $rhs
    i32.add)
  (func (export "start") (result i32)
    i32.const 90
    i32.const 50
    call $add))
