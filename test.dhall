let conf = ./spago.dhall

in conf // {
  sources = conf.sources # [ "test/**/*.purs" ],
  dependencies = conf.dependencies #
    [ "console"
    , "effect"
    , "assert"
    , "partial"
    , "quickcheck"
    , "quickcheck-laws"
    ]
}
