module Carnap.Languages.PurePropositional.Parser (purePropFormulaParser, standardLetters, extendedLetters, hausmanOpts, PurePropositionalParserOptions(..)) where

import Carnap.Languages.PurePropositional.Syntax
import Carnap.Languages.PurePropositional.Util (isAtom)
import Carnap.Languages.Util.LanguageClasses (BooleanLanguage, IndexedPropLanguage)
import Carnap.Languages.Util.GenericParsers
import Text.Parsec
import Text.Parsec.Expr

data PurePropositionalParserOptions u m = PurePropositionalParserOptions 
                                        { atomicSentenceParser :: ParsecT String u m PureForm 
                                        , hasBooleanConstants :: Bool
                                        , opTable :: [[Operator String u m PureForm]]
                                        , parenRecur :: PurePropositionalParserOptions u m
                                            -> (PurePropositionalParserOptions u m -> ParsecT String u m PureForm) 
                                            -> ParsecT String u m PureForm
                                        }

standardLetters :: Monad m => PurePropositionalParserOptions u m
standardLetters = PurePropositionalParserOptions 
                        { atomicSentenceParser = sentenceLetterParser "PQRSTUVW" 
                        , hasBooleanConstants = False
                        , opTable = standardOpTable
                        , parenRecur = \opt recurWith -> parenParser (recurWith opt)
                        }

extendedLetters :: Monad m => PurePropositionalParserOptions u m
extendedLetters = standardLetters { atomicSentenceParser = sentenceLetterParser "ABCDEFGHIJKLMNOPQRSTUVWXYZ" }

hausmanOpts ::  Monad m => PurePropositionalParserOptions u m
hausmanOpts = extendedLetters 
                { opTable = hausmanOpTable 
                , parenRecur = hausmanDispatch
                }
    where hausmanDispatch opt recurWith = hausmanBrace opt recurWith
                                      <|> hausmanParen opt recurWith
                                      <|> hausmanBracket opt recurWith
          hausmanBrace opt recurWith = wrappedWith '{' '}' (recurWith opt {parenRecur = hausmanBracket}) >>= noatoms
          hausmanParen opt recurWith = wrappedWith '(' ')' (recurWith opt {parenRecur = hausmanBrace}) >>= noatoms
          hausmanBracket opt recurWith = wrappedWith '[' ']' (recurWith opt {parenRecur = hausmanParen}) >>= noatoms
          noatoms a = if isAtom a then unexpected "atomic sentence wrapped in parentheses" else return a

--this parses as much formula as it can, but is happy to return an output if the
--initial segment of a string is a formula
purePropFormulaParser :: Monad m => PurePropositionalParserOptions u m -> ParsecT String u m PureForm
purePropFormulaParser opts = buildExpressionParser (opTable opts) subFormulaParser
    --subformulas are either
    where subFormulaParser = (parenRecur opts) opts purePropFormulaParser --formulas wrapped in parentheses
                          <|> unaryOpParser [parseNeg] subFormulaParser --negations or modalizations of subformulas
                          <|> try (atomicSentenceParser opts <* spaces)--or atoms
                          <|> if hasBooleanConstants opts then try (booleanConstParser <* spaces) else parserZero
                          <|> ((schemevarParser <* spaces) <?> "")

standardOpTable :: Monad m => [[Operator String u m PureForm]]
standardOpTable = [ [ Prefix (try parseNeg)]
                  , [Infix (try parseOr) AssocLeft, Infix (try parseAnd) AssocLeft]
                  , [Infix (try parseIf) AssocNone, Infix (try parseIff) AssocNone]
                  ]

hausmanOpTable :: Monad m => [[Operator String u m PureForm]]
hausmanOpTable = [[ Prefix (try parseNeg)
                  , Infix (try parseOr) AssocNone
                  , Infix (try (parseAsAnd [".", "∧", "∙"])) AssocNone
                  , Infix (try parseIf) AssocNone
                  , Infix (try parseIff) AssocNone
                  ]]
