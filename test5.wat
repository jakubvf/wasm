(module
  ;; import the browser console object, you'll need to pass this in from JavaScript
  (import "console" "log" (func $log (param i32)))

  (func
    ;; create a local variable and initialize it to 0
    i32.const 1
    (if
        (then
            i32.const 1
            call $log
            )
        (else
            i32.const 0
            call $log
            )
    )
  )
  (start 1) ;; run the first function automatically
)
