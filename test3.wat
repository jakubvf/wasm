(module
    (func $rekurze (param $p i32) (result i32)
        local.get $p
        i32.const 10
        i32.eq
        (if
            (then
                local.get $p
                return)
            (else
                local.get $p
                i32.const 1
                i32.add
                call $rekurze
                return)
        )
        i32.const 0
        return
    )
    (func $start (export "start")
        i32.const 0
        call $rekurze
        drop)
    (start $start)
)
