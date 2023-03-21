{ name = "array-views"
, dependencies =
  [ "arrays"
  , "bifunctors"
  , "control"
  , "foldable-traversable"
  , "maybe"
  , "newtype"
  , "nonempty"
  , "prelude"
  , "tailrec"
  , "tuples"
  , "unfoldable"
  ]
, packages = ./packages.dhall
, sources = [ "src/**/*.purs" ]
}
