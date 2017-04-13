{-# LANGUAGE FlexibleContexts #-}
module Carnap.GHCJS.Widget.RenderDeduction (renderDeductionFitch, renderDeductionMontegue) where

import Lib
import Carnap.Core.Data.AbstractSyntaxDataTypes
import Carnap.Core.Data.AbstractSyntaxClasses
import Carnap.Calculi.NaturalDeduction.Syntax (DeductionLine(..), Deduction(..), depth)
import GHCJS.DOM.Types (Document,Element)
import GHCJS.DOM.Element (setInnerHTML,setAttribute)
import GHCJS.DOM.Node (appendChild)
import GHCJS.DOM.Document (createElement)
import Data.Tree (Tree(..))
import Data.List (intercalate)

deductionToForest n ded@(d:ds) = map toTree chunks
    where chunks = chunkBy n ded
          toTree (Left x) = Node x []
          toTree (Right (x:xs)) = Node x (deductionToForest (depth $ snd x) ((0,SeparatorLine 0):xs))
deductionToForest _ [] = []

chunkBy n [] = []
chunkBy n (x:xs)
    | deep x = Right (x:takeWhile deep xs):chunkBy n (dropWhile deep xs)
    | otherwise = Left x:chunkBy n xs
    where deep x = depth (snd x) > n

--this is for Fitch proofs
renderTreeFitch w = treeToElement asLine asSubproof
    where asLine (n,AssertLine f r _ deps) = do (theWrapper,theLine,theForm,theRule) <- lineBase w n (Just f) (Just (r,deps)) "assertion"
                                                appendChild theLine (Just theForm)
                                                appendChild theLine (Just theRule)
                                                return theWrapper

          asLine _ = do (Just sl) <- createElement w (Just "div")
                        return sl

          asSubproof l ls = do setAttribute l "class" "subproof"
                               mapM_ (appendChild l . Just) ls

--this is for Kalish and Montegue Proofs
renderTreeMontegue w = treeToElement asLine asSubproof
    where asLine (n,AssertLine f r _ deps) = do (theWrapper,theLine,theForm,theRule) <- lineBase w n (Just f) norule "assertion"
                                                appendChild theLine (Just theForm)
                                                appendChild theLine (Just theRule)
                                                return theWrapper

          asLine (n,ShowLine f _)   = do (theWrapper,theLine,theForm,_) <- lineBase w n (Just f) norule "show"
                                         (Just theHead) <- createElement w (Just "span")
                                         setInnerHTML theHead (Just $ "Show: ")
                                         appendChild theLine (Just theHead)
                                         appendChild theLine (Just theForm)
                                         return theWrapper

          asLine (n,QedLine r _ deps) = do (theWrapper,theLine,_,theRule) <- lineBase w n noform (Just (r,deps)) "qed"
                                           appendChild theLine (Just theRule)
                                           appendChild theWrapper (Just theLine)
                                           return theWrapper

          asLine _ = do (Just sl) <- createElement w (Just "div")
                        return sl

          asSubproof l ls = do setAttribute l "class" "subproof"
                               mapM_ (appendChild l . Just) ls

          noform :: Maybe ()
          noform = Nothing

          norule :: Maybe ([()],[(Int,Int)])
          norule = Nothing

--The basic parts of a line, with Maybes for the fomula and the rule-dependency pair.
lineBase :: (Show a, Show b) => 
    Document -> Int -> Maybe a -> Maybe ([b],[(Int,Int)]) -> String -> IO (Element,Element,Element,Element)
lineBase w n mf mrd lineclass = 
        do (Just theWrapper) <- createElement w (Just "div")
           (Just theLine) <- createElement w (Just "div")
           (Just lineNum) <- createElement w (Just "span")
           (Just theForm) <- createElement w (Just "span")
           (Just theRule) <- createElement w (Just "span")
           setInnerHTML lineNum (Just $ show n ++ ".")
           whileJust mrd (\(r,deps) -> setInnerHTML theRule (Just $ show (head r) ++ " " ++ intercalate ", " (map renderDep deps)))
           whileJust mf (\f -> setInnerHTML theForm (Just $ show f))
           setAttribute theRule "class" "rule"
           appendChild theWrapper (Just theLine)
           appendChild theLine (Just lineNum)
           setAttribute theWrapper "class" lineclass
           return (theWrapper,theLine,theForm,theRule)

renderDeduction :: String -> (Document -> Tree (Int, DeductionLine t t1 t2) -> IO Element) -> Document -> [DeductionLine t t1 t2] -> IO Element
renderDeduction cls render w ded = 
        do let forest = deductionToForest 0 (zip [1..] ded)
           lines <- mapM (render w) forest
           (Just theProof) <- createElement w (Just "div")
           setAttribute theProof "class" cls
           mapM_ (appendChild theProof . Just) lines
           return theProof

renderDeductionFitch :: (Show t,Schematizable (t1 (FixLang t1)), CopulaSchema (FixLang t1)) => Document -> [DeductionLine t t1 t2] -> IO Element
renderDeductionFitch = renderDeduction "fitchDisplay" renderTreeFitch

renderDeductionMontegue :: (Show t,Schematizable (t1 (FixLang t1)), CopulaSchema (FixLang t1)) => Document -> [DeductionLine t t1 t2] -> IO Element
renderDeductionMontegue = renderDeduction "montegueDisplay" renderTreeMontegue

renderDep (n,m) = if n==m then show n else show n ++ "-" ++ show m

whileJust :: Monad m => Maybe a -> (a -> m b) -> m ()
whileJust (Just m) f = f m >> return ()
whileJust Nothing _ = return ()
