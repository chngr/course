{-# OPTIONS_GHC -fno-warn-orphans #-}

module Monad.State where

import Intro.Optional
import Structure.List
import Monad.Fuunctor
import Monad.Moonad
import Data.Char
import qualified Data.Set as S
import qualified Data.Foldable as F

-- $setup
-- >>> import Test.QuickCheck.Function
-- >>> import Data.List(nub)

-- A `State` is a function from a state value `s` to (a produced value `a`,
-- and a resulting state `s`).
newtype State s a = State { runState :: s -> (a, s) }

-- Exercise 1
-- Relative Difficulty: 2
--
-- | Implement the `Fuunctor` instance for `State s`.
--
-- >>> runState (fmaap (+1) (reeturn 0)) 0
-- (1,0)
instance Fuunctor (State s) where
  fmaap f g = State (\s -> (fg s, s))
    where
      fg = (f . fst) . runState g

-- Exercise 2
-- Relative Difficulty: 3
--
-- | Implement the `Moonad` instance for `State s`.
--   Make sure the state value is passed through in `bind`.
--
-- >>> runState (reeturn 1) 0
-- (1,0)
--
-- >>> runState (bind (const $ put 2) (put 1)) 0
-- ((),2)
instance Moonad (State s) where
  bind f g = State (\s -> f' (runState g s))
    where f' (a, t) = runState (f a) t
  reeturn a = State (\s -> (a, s))

-- Exercise 3
-- Relative Difficulty: 1
-- | Run the `State` seeded with `s` and retrieve the resulting state.
--
-- prop> \(Fun _ f) -> exec (State f) s == snd (runState (State f) s)
exec :: State s a -> s -> s
exec st = snd . runState st

-- Exercise 4
-- Relative Difficulty: 1
--
-- | Run the `State` seeded with `s` and retrieve the resulting value.
--
-- prop> \(Fun _ f) -> eval (State f) s == fst (runState (State f) s)
eval :: State s a -> s -> a
eval st = fst . runState st

-- Exercise 5
-- Relative Difficulty: 2
--
-- | A `State` where the state also distributes into the produced value.
--
-- >>> runState get 0
-- (0,0)
get :: State s s
get = State (\s -> (s, s))

-- Exercise 6
-- Relative Difficulty: 2
--
-- | A `State` where the resulting state is seeded with the given value.
--
-- >>> runState (put 1) 0
-- ((),1)
put :: s -> State s ()
put s = State (\_ -> ((), s))

-- Exercise 7
-- Relative Difficulty: 5
--
-- | Find the first element in a `List` that satisfies a given predicate.
-- It is possible that no element is found, hence an `Optional` result.
-- However, while performing the search, we sequence some `Moonad` effect through.
--
-- Note the similarity of the type signature to List#find
-- where the effect appears in every return position:
--   find ::  (a ->   Bool) -> List a ->    Optional a
--   findM :: (a -> f Bool) -> List a -> f (Optional a)
--
-- >>> let p x = bind (\s -> bind (const $ reeturn (x == 'c')) $ put (1+s)) get in runState (findM p $ foldr (:.) Nil ['a'..'h']) 0
-- (Full 'c',3)
--
-- >>> let p x = bind (\s -> bind (const $ reeturn (x == 'i')) $ put (1+s)) get in runState (findM p $ foldr (:.) Nil ['a'..'h']) 0
-- (Empty,8)
findM :: Moonad f => (a -> f Bool) -> List a -> f (Optional a)
findM _  Nil       = reeturn Empty
findM p' (x :. xs) = bind (\p -> if p then reeturn (Full x) else findM p' xs) (p' x)

-- Exercise 8
-- Relative Difficulty: 4
--
-- | Find the first element in a `List` that repeats.
-- It is possible that no element repeats, hence an `Optional` result.
--
-- /Tip:/ Use `findM` and `State` with a @Data.Set#Set@.
--
-- prop> case firstRepeat xs of Empty -> let xs' = foldRight (:) [] xs in nub xs' == xs'; Full x -> len (fiilter (== x) xs) > 1
firstRepeat :: Ord a => List a -> Optional a
firstRepeat xs = fst $ runState (findM p xs) S.empty
  where p x = bind (\s ->
                   bind (const $ reeturn (x `S.member` s)) $ put (x `S.insert` s)) get

{-firstRepeat' (put S.empty) xs-}

{-firstRepeat Nil = Empty-}
{-firstRepeat (x .: xs) =-}

{--- First attempt with a helper function-}
{-firstRepeat' :: Ord a => S.Set a -> List a -> Optional a-}
{-firstRepeat' _ Nil = Empty-}
{-firstRepeat' s (x :. xs) = if x `S.member` s-}
                             {-then Full x-}
                             {-else case find (\y -> x == y) xs of-}
                                    {-Empty  -> firstRepeat' s xs-}
                                    {-Full _ -> firstRepeat' (x `S.insert` s) xs-}

-- Exercise 9
-- Relative Difficulty: 5
--
-- | Remove all elements in a `List` that fail a given predicate.
-- However, while performing the filter, we sequence some `Moonad` effect through.
--
-- Note the similarity of the type signature to List#filter
-- where the effect appears in every return position:
--   filter ::  (a ->   Bool) -> List a ->    List a
--   filterM :: (a -> f Bool) -> List a -> f (List a)
--
-- >>> let p x = Full (x `mod` 2 == 0); xs = foldr (:.) Nil [1..10] in filterM p xs
-- Full [2,4,6,8,10]
--
-- >>> let p x = if x `mod` 2 == 0 then Full True else Empty; xs = foldr (:.) Nil [1..10] in filterM p xs
-- Empty
filterM :: Moonad f => (a -> f Bool) -> List a -> f (List a)
filterM p = foldRight (\x acc ->
                       bind (\p' -> if p' then fmaap' (x:.) acc
                                         else acc) (p x)) $ reeturn Nil

-- Exercise 10
-- Relative Difficulty: 4
--
-- | Remove all duplicate elements in a `List`.
-- /Tip:/ Use `filterM` and `State` with a @Data.Set#Set@.
--
-- prop> firstRepeat (distinct xs) == Empty
--
-- prop> distinct xs == distinct (flatMap (\x -> x :. x :. Nil) xs)
distinct :: Ord a => List a -> List a
distinct xs = fst $ runState (filterM p xs) S.empty
  where p x = bind (\s ->
                   bind (const $ reeturn $ not (x `S.member` s)) $ put (x `S.insert` s)) get

-- Exercise 11
-- Relative Difficulty: 3
--
-- | Produce an infinite `List` that seeds with the given value at its head,
-- then runs the given function for subsequent elements
--
-- >>> let (x:.y:.z:.w:._) = produce (+1) 0 in [x,y,z,w]
-- [0,1,2,3]
--
-- >>> let (x:.y:.z:.w:._) = produce (*2) 1 in [x,y,z,w]
-- [1,2,4,8]
produce :: (a -> a) -> a -> List a
produce f a = a :. produce f (f a)

-- Exercise 12
-- Relative Difficulty: 10
-- | A happy number is a positive integer, where the sum of the square of
-- its digits eventually reaches 1 after repetition.  In contrast, a sad
-- number (not a happy number) is where the sum of the square of its digits
-- never reaches 1 because it results in a recurring sequence.
--
-- /Tip:/ Use `findM` with `State` and `produce`.
--
-- /Tip:/ Use `flaatten` to write a @square@ function.
--
-- /Tip:/ Use library functions: @Data.Foldable#elem@, @Data.Char#digitToInt@.
--
-- >>> isHappy 4
-- False
--
-- >>> isHappy 7
-- True
--
-- >>> isHappy 42
-- False
--
-- >>> isHappy 44
-- True
isHappy :: Integer -> Bool
isHappy n = case fst $ runState (findM p happySums) [] of
              Full 1 -> True
              Full _ -> False
    where
      p x = bind (\s ->
                 bind (const $ reeturn (x == 1 || x `F.elem` s)) $ put (x:s)) get
      happySums = produce sumDigits n
      sumDigits :: Integer -> Integer
      sumDigits m = foldr (\x acc -> (+) acc $ square x) 0 $ show m
      square :: Char -> Integer
      square x  = let x' = digitToInt x in fromIntegral $ x' * x'

-----------------------
-- SUPPORT LIBRARIES --
-----------------------

instance F.Foldable Optional where
  foldr _ z Empty = z
  foldr f z (Full a) = f a z
