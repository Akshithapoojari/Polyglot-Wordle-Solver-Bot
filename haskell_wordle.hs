{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE RecordWildCards #-}
import System.IO
import System.Directory (doesFileExist)
import Control.Monad (when, filterM)
import Data.List (nub, sort)
import Data.Char (toUpper)
import Control.Concurrent (threadDelay)
import Text.Printf (printf)
import qualified Data.Map as Map

-- Data types for the game
data FeedbackChar = Green | Yellow | Grey deriving (Show, Eq, Ord)
type Feedback = [FeedbackChar]

data GameStatus = Playing | Won | Lost deriving (Show, Eq)

data GameState = GameState {
    wordList     :: [String],
    tries        :: Int,
    maxTries     :: Int,
    answer       :: String,
    currentGuess :: String,
    gameStatus   :: GameStatus
} deriving (Show)

-- Counts the occurrences of each element in a list
countOccurrences :: (Ord a) => [a] -> Map.Map a Int
countOccurrences = Map.fromListWith (+) . map (, 1)

-- The mock game logic to evaluate a guess
evaluateGuess :: String -> String -> Feedback
evaluateGuess secret guess =
    let
        secretChars = zip [0..] secret
        guessChars = zip [0..] guess

        -- First pass for Greens
        greenPass (greens, secretMap, guessMap) (i, gc) =
            if gc == secret !! i
            then ((i, Green) : greens, Map.adjust (subtract 1) gc secretMap, Map.adjust (subtract 1) gc guessMap)
            else (greens, secretMap, guessMap)

        (greens, remainingSecret, _) = foldl greenPass ([], countOccurrences secret, countOccurrences guess) guessChars

        -- Second pass for Yellows and Greys
        yellowGreyPass (feedback, secretMap) (i, gc) =
            if (i, Green) `elem` greens
            then (feedback, secretMap)
            else
                let secretCount = Map.findWithDefault 0 gc secretMap
                in if secretCount > 0
                   then ((i, Yellow) : feedback, Map.adjust (subtract 1) gc secretMap)
                   else ((i, Grey) : feedback, secretMap)

        (feedback, _) = foldl yellowGreyPass ([], remainingSecret) guessChars

    in map snd . sort $ feedback ++ greens


-- Filter the word list based on feedback
filterWords :: String -> Feedback -> [String] -> [String]
filterWords guess feedback words =
    let
        greenLetters = [(c, i) | ((c, i), f) <- zip (zip guess [0..]) feedback, f == Green]
        yellowLetters = [(c, i) | ((c, i), f) <- zip (zip guess [0..]) feedback, f == Yellow]
        greyLetters = [c | (c, f) <- zip guess feedback, f == Grey]

        -- Letters that are confirmed not in the word
        confirmedGreys = [c | c <- greyLetters, c `notElem` (map fst greenLetters ++ map fst yellowLetters)]

    in filter (\word ->
        -- Rule 1: Green letters must be in the correct position
        all (\(c, i) -> word !! i == c) greenLetters &&

        -- Rule 2: Yellow letters must be in the word but not in the guessed position
        all (\(c, i) -> c `elem` word && word !! i /= c) yellowLetters &&

        -- Rule 3: The count of yellow letters in the word must be at least the number of yellow hints for that letter
        all (\c -> count c word >= count c (map fst yellowLetters)) (nub (map fst yellowLetters)) &&

        -- Rule 4: Grey letters must not be in the word
        all (`notElem` word) confirmedGreys

    ) words
    where count c = length . filter (==c)


-- The main game loop
gameLoop :: GameState -> IO ()
gameLoop state@GameState{..} = do
    printf "\nAttempt %d: Guessing '%s'\n" (tries + 1) currentGuess
    
    let feedback = evaluateGuess answer currentGuess
    let feedbackStr = map feedbackCharToString feedback
    
    printf "Feedback: %s\n" feedbackStr

    if feedback == replicate 5 Green
    then do
        printf "Bot WON in %d tries! Answer was %s\n" (tries + 1) currentGuess
        printf "YOU WON!\n"
        return ()
    else if tries + 1 >= maxTries
    then do
        printf "Bot EXCEEDED tries.\n"
        printf "YOU LOST!\n"
        return ()
    else do
        let newWordList = filterWords currentGuess feedback wordList
        
        when (not (null newWordList)) $ threadDelay 1000000 -- 1 second delay

        case newWordList of
            [] -> putStrLn "No possible words left! The bot has failed."
            (nextGuess:_) ->
                let newState = state {
                        wordList = newWordList,
                        tries = tries + 1,
                        currentGuess = nextGuess
                    }
                in gameLoop newState

feedbackCharToString :: FeedbackChar -> Char
feedbackCharToString Green = 'G'
feedbackCharToString Yellow = 'Y'
feedbackCharToString Grey = 'R'

-- Entry point of the program
main :: IO ()
main = do
    let answer = "RAISE"
    
    fileExists <- doesFileExist "words_5.txt"
    wordLines <- if fileExists
                 then lines <$> readFile "words_5.txt"
                 else return ["ABOVE", "ABOUT", "ACORN", "AFOOT", "AFORE", "RAISE"]

    let allWords = nub [map toUpper w | w <- wordLines, length w == 5]
    
    case allWords of
        [] -> putStrLn "Word list is empty. Cannot start the game."
        (firstGuess:_) -> do
            let initialState = GameState {
                wordList = allWords,
                tries = 0,
                maxTries = 6,
                answer = answer,
                currentGuess = firstGuess,
                gameStatus = Playing
            }
            printf "Starting new game. Guessing with first word: %s\n" firstGuess
            gameLoop initialState