module Data.ArrayView
       ( ArrayView
       , fromArray
       , toArray

       , force

       , fromFoldable
       , toUnfoldable
       , singleton
       , range, (..)
       , replicate
       , some
       , many
       , null
       , length
       , cons, (:)
       , snoc
       , insert
       , insertBy
       , head
       , last
       , tail
       , init
       , uncons
       , unsnoc
       , index, (!!)
       , elemIndex
       , elemLastIndex
       , findIndex
       , findLastIndex
       , insertAt
       , deleteAt
       , updateAt
       , updateAtIndices
       , modifyAt
       , modifyAtIndices
       , alterAt
       , reverse
       , concat
       , concatMap
       , filter
       , partition
       , filterA
       , mapMaybe
       , catMaybes
       , mapWithIndex
       , sort
       , sortBy
       , sortWith
       , slice
       , take
       , takeEnd
       , takeWhile
       , drop
       , dropEnd
       , dropWhile
       , span
       , group
       , group'
       , groupBy
       , nub
       , nubEq
       , nubBy
       , nubByEq
       , union
       , unionBy
       , delete
       , deleteBy
       , difference
       , intersect
       , intersectBy
       , zipWith
       , zipWithA
       , zip
       , unzip
       , foldM
       , foldRecM
       , unsafeIndex

       , class ArrayToView
       , use
       )
where


import Control.Alternative (class Alternative)
import Control.Lazy (class Lazy)
import Control.Monad.Rec.Class (class MonadRec)
import Data.Array as A
import Data.Array.NonEmpty as NEA
import Data.Eq (class Eq1)
import Data.Generic.Rep (class Generic)
import Data.Maybe (Maybe(..))
import Data.Newtype (class Newtype)
import Data.NonEmpty (NonEmpty, (:|))
import Data.NonEmpty as NE
import Data.Ord (class Ord1)
import Data.Profunctor.Strong ((***))
import Data.Traversable (class Foldable, class Traversable, foldMap, foldl, foldr, sequenceDefault, traverse)
import Data.Tuple (Tuple)
import Data.Unfoldable (class Unfoldable, unfoldr)
import Data.Unfoldable1 (class Unfoldable1, unfoldr1)
import Prelude (class Applicative, class Apply, class Bind, class Eq, class Functor, class Monad, class Monoid, class Ord, class Semigroup, class Show, type (~>), Ordering, apply, bind, compare, eq, join, map, otherwise, pure, show, (&&), (+), (-), (<), (<#>), (<<<), (<=), (<>), (==), (>), (>=), (>>>), (||))


newtype ArrayView a = View { from :: Int, len :: Int, arr :: Array a }

derive instance newtypeArrayView :: Newtype (ArrayView a) _

derive instance genericArrayView :: Generic (ArrayView a) _

instance showArrayView :: Show a => Show (ArrayView a) where
  show av  = "fromArray " <> show (toArray av)

instance eqArrayView :: Eq a => Eq (ArrayView a) where
  eq a b = lenA == length b && go (lenA - 1)
    where
      lenA = length a
      go (-1) = true
      go ix = if a !! ix == b !! ix then
               go (ix - 1)
             else
               false

instance eq1ArrayView :: Eq1 ArrayView where
  eq1 a b = a `eq` b

instance ordArrayView :: Ord a => Ord (ArrayView a) where
  compare a b = toArray a `compare` toArray b

instance ord1ArrayView :: Ord1 ArrayView where
  compare1 a b = a `compare` b

instance functorArrayView :: Functor ArrayView where
  map f = toArray >>> map f >>> fromArray

instance applyArrayView :: Apply ArrayView where
  apply f arr = fromArray (apply (toArray f) (toArray arr))

instance bindArrayView :: Bind ArrayView where
  bind m f = concatMap f m

instance applicativeArrayView :: Applicative ArrayView where
  pure = singleton

instance monadArrayView :: Monad ArrayView

instance foldableArrayView :: Foldable ArrayView where
  foldl f z = toArray >>> foldl f z
  foldr f z = toArray >>> foldr f z
  foldMap f = toArray >>> foldMap f

instance traversableArrayView :: Traversable ArrayView where
  traverse f av = map fromArray (traverse f (toArray av))
  sequence = sequenceDefault

instance unfoldable1ArrayView :: Unfoldable1 ArrayView where
  unfoldr1 f z = fromArray (unfoldr1 f z)

instance unfoldableArrayView :: Unfoldable ArrayView where
  unfoldr f z = fromArray (unfoldr f z)

instance semigroupArrayView :: Semigroup (ArrayView a) where
  append a b = fromArray (toArray a <> toArray b)

instance monoidArrayView :: Monoid (ArrayView a) where
  mempty = empty

fromFoldable :: forall f. Foldable f => f ~> ArrayView
fromFoldable = A.fromFoldable >>> fromArray

toUnfoldable :: forall f. Unfoldable f => ArrayView ~> f
toUnfoldable = toArray >>> A.toUnfoldable

singleton :: forall a. a -> ArrayView a
singleton a = View { from: 0, len: 1, arr: [a] }

range :: Int -> Int -> ArrayView Int
range f = A.range f >>> fromArray

infix 8 range as ..

replicate :: forall a. Int -> a -> ArrayView a
replicate i = A.replicate i >>> fromArray

-- Using `Lazy (f (ArrayView a))` constraint is impossible due to `OrphanInstances`.
some :: forall f a. Alternative f => Lazy (f (Array a)) => f a -> f (ArrayView a)
some = A.some >>> map fromArray

-- Using `Lazy (f (ArrayView a))` constraint is impossible due to `OrphanInstances`.
many :: forall f a. Alternative f => Lazy (f (Array a)) => f a -> f (ArrayView a)
many = A.many >>> map fromArray

null :: forall a. ArrayView a -> Boolean
null (View { len: 0 }) = true
null _                 = false

length :: forall a. ArrayView a -> Int
length (View { len }) = len

-- | *O(n)*
cons :: forall a. a -> ArrayView a -> ArrayView a
cons a av = fromArray (A.cons a (toArray av))

infix 6 cons as :

-- | *O(n)*
snoc :: forall a. ArrayView a -> a -> ArrayView a
snoc av a = fromArray (A.snoc (toArray av) a)

insert :: forall a. Ord a => a -> ArrayView a -> ArrayView a
insert a = toArray >>> A.insert a >>> fromArray

insertBy :: forall a. (a -> a -> Ordering) -> a -> ArrayView a -> ArrayView a
insertBy f a = toArray >>> A.insertBy f a >>> fromArray

head :: forall a. ArrayView a -> Maybe a
head = join <<< whenNonEmpty \(View { from, arr }) -> arr A.!! from

last :: forall a. ArrayView a -> Maybe a
last = join <<< whenNonEmpty \(View { from, len, arr }) -> arr A.!! (from + len - 1)

-- | *O(1)*
tail :: forall a. ArrayView a -> Maybe (ArrayView a)
tail = whenNonEmpty \(View view) -> View view { from = view.from + 1, len = view.len - 1 }

-- | *O(1)*
init :: forall a. ArrayView a -> Maybe (ArrayView a)
init = whenNonEmpty \(View view) -> View view { len = view.len - 1 }

-- | *O(1)*
uncons :: forall a. ArrayView a -> Maybe { head :: a, tail :: ArrayView a }
uncons av @ (View { from, arr }) = do
  head <- arr A.!! from
  tail <- tail av
  pure { head, tail }

-- | *O(1)*
unsnoc :: forall a. ArrayView a -> Maybe { init :: ArrayView a, last :: a }
unsnoc av @ (View { from, len, arr }) = do
  init <- init av
  last <- arr A.!! (from + len - 1)
  pure { init, last }

index :: forall a. ArrayView a -> Int -> Maybe a
index av @ (View { from, len, arr }) ix
  | ix >= 0 && ix < len = arr A.!! (from + ix)
  | otherwise = Nothing

infixl 8 index as !!

elemIndex :: forall a. Eq a => a -> ArrayView a -> Maybe Int
elemIndex e = use (A.elemIndex e)

elemLastIndex :: forall a. Eq a => a -> ArrayView a -> Maybe Int
elemLastIndex e = use (A.elemLastIndex e)

findIndex :: forall a. (a -> Boolean) -> ArrayView a -> Maybe Int
findIndex p = use (A.findIndex p)

findLastIndex :: forall a. (a -> Boolean) -> ArrayView a -> Maybe Int
findLastIndex p = use (A.findLastIndex p)

insertAt :: forall a. Int -> a -> ArrayView a -> Maybe (ArrayView a)
insertAt ix e = use (A.insertAt ix e)

deleteAt :: forall a. Int -> ArrayView a -> Maybe (ArrayView a)
deleteAt = use (A.deleteAt :: Int -> Array a -> Maybe (Array a))

updateAt :: forall a. Int -> a -> ArrayView a -> Maybe (ArrayView a)
updateAt ix v = use (A.updateAt ix v)

updateAtIndices :: forall t a. Foldable t => t (Tuple Int a) -> ArrayView a -> ArrayView a
updateAtIndices t = use (A.updateAtIndices t)

modifyAt :: forall a. Int -> (a -> a) -> ArrayView a -> Maybe (ArrayView a)
modifyAt ix f = use (A.modifyAt ix f)

modifyAtIndices :: forall t a. Foldable t => t Int -> (a -> a) -> ArrayView a -> ArrayView a
modifyAtIndices t f = use (A.modifyAtIndices t f)

alterAt :: forall a. Int -> (a -> Maybe a) -> ArrayView a -> Maybe (ArrayView a)
alterAt = use (A.alterAt :: Int -> (a -> Maybe a) -> Array a -> Maybe (Array a))

reverse :: forall a. ArrayView a -> ArrayView a
reverse = use (A.reverse :: Array a -> Array a)

concat :: forall a. ArrayView (ArrayView a) -> ArrayView a
concat = use (A.concat :: Array (Array a) -> Array a)

concatMap :: forall a b. (a -> ArrayView b) -> ArrayView a -> ArrayView b
concatMap = use (A.concatMap :: (a -> Array b) -> Array a -> Array b)

filter :: forall a. (a -> Boolean) -> ArrayView a -> ArrayView a
filter f = use (A.filter f)

partition :: forall a. (a -> Boolean) -> ArrayView a -> { yes :: ArrayView a, no :: ArrayView a }
partition p = use (A.partition p) >>> fix
  where
    fix :: { no :: Array a, yes :: Array a } -> { yes :: ArrayView a, no :: ArrayView a }
    fix { yes, no } = { yes: fromArray yes, no: fromArray no }

filterA :: forall a f. Applicative f => (a -> f Boolean) -> ArrayView a -> f (ArrayView a)
filterA f = use (A.filterA f)

mapMaybe :: forall a b. (a -> Maybe b) -> ArrayView a -> ArrayView b
mapMaybe f = use (A.mapMaybe f)

catMaybes :: forall a. ArrayView (Maybe a) -> ArrayView a
catMaybes = use (A.catMaybes :: Array (Maybe a) -> Array a)

mapWithIndex :: forall a b. (Int -> a -> b) -> ArrayView a -> ArrayView b
mapWithIndex f = use (A.mapWithIndex f)

sort :: forall a. Ord a => ArrayView a -> ArrayView a
sort = use (A.sort :: Array a -> Array a)

sortBy :: forall a. (a -> a -> Ordering) -> ArrayView a -> ArrayView a
sortBy f = use (A.sortBy f)

sortWith :: forall a b. Ord b => (a -> b) -> ArrayView a -> ArrayView a
sortWith f = use (A.sortWith f)

-- | *O(1)*
slice :: forall a. Int -> Int -> ArrayView a -> ArrayView a
slice start' end' (View view @ { from, len, arr }) =
  if end <= start || start >= len
  then empty --  forget about the original array
             -- (allow it to be GC'ed)
  else View view { from = from + start, len = end - start }
  where
    start = between 0 len (fix start')
    end   = between 0 len (fix end')
    between lb ub n =
      if n < lb
      then lb
      else if n > ub
           then ub
           else n
    fix n
      | n < 0 = len + n
      | otherwise = n

-- | *O(1)*
take :: forall a. Int -> ArrayView a -> ArrayView a
take n = slice 0 n

-- | *O(1)*
takeEnd :: forall a. Int -> ArrayView a -> ArrayView a
takeEnd n xs = drop (length xs - n) xs

takeWhile :: forall a. (a -> Boolean) -> ArrayView a -> ArrayView a
takeWhile p xs = (span p xs).init

-- | *O(1)*
drop :: forall a. Int -> ArrayView a -> ArrayView a
drop n av = slice n (length av) av

-- | *O(1)*
dropEnd :: forall a. Int -> ArrayView a -> ArrayView a
dropEnd n xs = take (length xs - n) xs

dropWhile :: forall a. (a -> Boolean) -> ArrayView a -> ArrayView a
dropWhile p xs = (span p xs).rest

-- | The time complexity of `span` only depends on the length of the resulting
-- | `init` ArrayView.
span :: forall a. (a -> Boolean) -> ArrayView a ->
        { init :: ArrayView a, rest :: ArrayView a }
span p av =
  -- `span` implementation from Data/Array.purs is copypasted here instead of
  -- reusing `Data.Array.span` because `slice` on `ArrayView` is O(1), and
  -- we can take advantage of it.
  case go 0 of
    Just 0 ->
      { init: empty, rest: av }
    Just i ->
      { init: slice 0 i av, rest: slice i (length av) av }
    Nothing ->
      { init: av, rest: empty }
  where
    go i =
      case index av i of
        Just x -> if p x then go (i + 1) else Just i
        Nothing -> Nothing

group :: forall a. Eq a => ArrayView a -> ArrayView (NonEmpty ArrayView a)
group av = fromArray (A.group (toArray av) <#> fromNonEmpty)

group' :: forall a. Ord a => ArrayView a -> ArrayView (NonEmpty ArrayView a)
group' av = fromArray (A.group' (toArray av) <#> fromNonEmpty)

groupBy :: forall a. (a -> a -> Boolean) -> ArrayView a -> ArrayView (NonEmpty ArrayView a)
groupBy f = use (A.groupBy f)

nub :: forall a. Ord a => ArrayView a -> ArrayView a
nub = use (A.nub :: Array a -> Array a)

nubEq :: forall a. Eq a => ArrayView a -> ArrayView a
nubEq = use (A.nubEq :: Array a -> Array a)

nubBy :: forall a. (a -> a -> Ordering) -> ArrayView a -> ArrayView a
nubBy f = use (A.nubBy f)

nubByEq :: forall a. (a -> a -> Boolean) -> ArrayView a -> ArrayView a
nubByEq p = use (A.nubByEq p)

union :: forall a. Eq a => ArrayView a -> ArrayView a -> ArrayView a
union = use (A.union :: Array a -> Array a -> Array a)

unionBy :: forall a. (a -> a -> Boolean) -> ArrayView a -> ArrayView a -> ArrayView a
unionBy p = use (A.unionBy p)

delete :: forall a. Eq a => a -> ArrayView a -> ArrayView a
delete a = use (A.delete a)

deleteBy :: forall a. (a -> a -> Boolean) -> a -> ArrayView a -> ArrayView a
deleteBy f = use (A.deleteBy f)

difference :: forall a. Eq a => ArrayView a -> ArrayView a -> ArrayView a
difference = use (A.difference :: Array a -> Array a -> Array a)

intersect :: forall a. Eq a => ArrayView a -> ArrayView a -> ArrayView a
intersect = use (A.intersect :: Array a -> Array a -> Array a)

intersectBy :: forall a. (a -> a -> Boolean) -> ArrayView a -> ArrayView a -> ArrayView a
intersectBy f = use (A.intersectBy f)

zipWith :: forall a b c. (a -> b -> c) -> ArrayView a -> ArrayView b -> ArrayView c
zipWith f = use (A.zipWith f)

zipWithA :: forall m a b c. Applicative m => (a -> b -> m c) -> ArrayView a -> ArrayView b -> m (ArrayView c)
zipWithA f a b = A.zipWithA f (toArray a) (toArray b) <#> fromArray

zip :: forall a b. ArrayView a -> ArrayView b -> ArrayView (Tuple a b)
zip = use (A.zip :: Array a -> Array b -> Array (Tuple a b))

unzip :: forall a b. ArrayView (Tuple a b) -> Tuple (ArrayView a) (ArrayView b)
unzip = (fromArray *** fromArray) <<< A.unzip <<< toArray

foldM :: forall m a b. Monad m => (a -> b -> m a) -> a -> ArrayView b -> m a
foldM f a = toArray >>> A.foldM f a

foldRecM :: forall m a b. MonadRec m => (a -> b -> m a) -> a -> ArrayView b -> m a
foldRecM f a = toArray >>> A.foldRecM f a

unsafeIndex :: forall a. Partial => ArrayView a -> Int -> a
unsafeIndex (View view @ { from, len, arr }) ix
  | ix < len && ix >= 0 = A.unsafeIndex arr (ix + from)

fromArray :: Array ~> ArrayView
fromArray arr = let len = A.length arr in
  View { from: 0, len, arr }

toArray :: ArrayView ~> Array
toArray (View { from, len, arr })
  | from == 0 && A.length arr == len =
    arr
  | otherwise =
    A.slice from (from + len) arr

-- | Perform deferred `slice`. This function allows the garbage collector to
-- | free the array referenced by the given `ArrayView`.
-- |
-- | *O(n)*
-- |
-- | ```purescript
-- | force = toArray >>> fromArray
-- | ```
force :: forall a. ArrayView a -> ArrayView a
force = toArray >>> fromArray

-- internal

fromNonEmpty :: NEA.NonEmptyArray ~> NonEmpty ArrayView
fromNonEmpty nav = let t = NEA.uncons nav in
  t.head :| fromArray (t.tail)

toNonEmpty :: NonEmpty ArrayView ~> NEA.NonEmptyArray
toNonEmpty narr = NEA.cons' (NE.head narr) (toArray (NE.tail narr))

whenNonEmpty :: forall a b. (ArrayView a -> b) -> ArrayView a -> Maybe b
whenNonEmpty _ (View { len: 0 }) = Nothing
whenNonEmpty f av           = Just (f av)

empty :: forall a. ArrayView a
empty = View { from: 0, len: 0, arr: [] }


-- | This typeclass allows to convert any function that operates on `Array` to a
-- | function that operates on `ArrayView`.
-- |
-- | *Note*: either type annotation or partial application of some number of
-- | arguments is needed, because otherwise the type inference will not be
-- | able to guess the correct type.
-- |
-- | ```
-- | import Data.Array as A
-- |
-- | -- OK
-- | zipWith :: forall a b c. (a -> b -> c) -> ArrayView a -> ArrayView b -> ArrayView c
-- | zipWith = use (A.zipWith :: (a -> b -> c) -> Array a -> Array b -> Array c)
-- |
-- | -- OK
-- | zipWith :: forall a b c. (a -> b -> c) -> ArrayView a -> ArrayView b -> ArrayView c
-- | zipWith f = use (A.zipWith f) -- all three type parameters are tied to `f`
-- |
-- | -- Type error
-- | zipWith :: forall a b c. (a -> b -> c) -> ArrayView a -> ArrayView b -> ArrayView c
-- | zipWith = use A.zipWith
-- | ```
class ArrayToView a b where
  use :: a -> b

instance useArrayViewId :: ArrayToView a a where
  use x = x

else instance useArrayViewBi :: (ArrayToView b a, ArrayToView c d) => ArrayToView (a -> c) (b -> d) where
  use f x = use (f (use x))

else instance useArrayViewFrom :: ArrayToView a b => ArrayToView (Array a) (ArrayView b) where
  use = fromArray <<< map use

else instance useArrayViewTo :: ArrayToView a b => ArrayToView (ArrayView a) (Array b) where
  use = toArray <<< map use

else instance useArrayViewFromNEA :: ArrayToView (NEA.NonEmptyArray a) (NonEmpty ArrayView a) where
  use = fromNonEmpty

else instance useArrayViewToNEA :: ArrayToView (NE.NonEmpty ArrayView a) (NEA.NonEmptyArray a) where
  use = toNonEmpty

else instance useArrayViewFunctor :: (Functor f, ArrayToView a b) => ArrayToView (f a) (f b) where
  use = map use
