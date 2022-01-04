[
  inputs: [
    "{mix,.formatter}.exs",
    "{config,lib,test}/**/*.{ex,exs}"
  ],
  export: [
    locals_without_parens: [
      schedule: 2
    ]
  ],
  locals_without_parens: [
    schedule: 1,
    on_exit: 1,
    raise: 1
  ]
]
