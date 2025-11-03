polyglot-wordle-solver-bot

A project to implement the core logic for a Wordle game (and solver bot) in multiple programming languages: Python, Haskell, Scala 3, and Elixir.

The Core Logic: Game vs. Solver

This repository focuses on the single most important piece of logic required for any Wordle application: the guess-checking function.

A Wordle Game needs this function to score the player's guess.

A Wordle Solver Bot needs this function to test its own hypothetical guesses and filter its list of possible words.

The function's signature is simple, though its implementation is tricky:

check_guess(target: string, guess: string) -> list[Feedback]

Where Feedback is one of:

Correct: The letter is in the correct position (Green).

Present: The letter is in the target word but in the wrong position (Yellow).

Absent: The letter is not in the target word at all (Gray).

The "Duplicate Letter" Problem

The logic must correctly handle duplicate letters. For example:

Target: SPOON

Guess: TOOLS

Result: [Absent, Present, Present, Absent, Present]

T: Absent

O: Present (matches the first 'O' in SPOON)

O: Present (matches the second 'O' in SPOON)

L: Absent

S: Present (matches the 'S' in SPOON)

Target: APPLE

Guess: PAPPY

Result: [Present, Correct, Correct, Absent, Absent]

P (1): Present (matches the second 'P' in APPLE)

A (2): Correct

P (3): Correct

P (4): Absent (The guess has three 'P's, but the target only has two. Since two are already "used" by the correct/present feedback, this third 'P' is Absent.)

Y (5): Absent

All implementations in this repository use a two-pass algorithm to handle this correctly:

First Pass (Greens): Iterate through the words and find all Correct matches. "Use up" these letters from both the guess and the target.

Second Pass (Yellows/Grays): Iterate again. Check the remaining guess letters against the remaining target letters to find Present (yellow) matches. If a letter isn't Correct or Present, it's Absent.

Implementations

1. Python (python/)

A standard, imperative implementation using a dictionary (Counter) to track letter counts for the two-pass algorithm.

To Run:

python3 python/logic.py


2. Haskell (haskell/)

A purely functional implementation. It uses a first pass with zipWith to find Correct matches and a second pass that threads a Map of remaining letter counts to determine Present and Absent feedback.

To Run:

runhaskell haskell/Logic.hs


3. Scala 3 (scala3/)

A modern, functional-style implementation using Scala 3's enum feature for Feedback. The logic is similar to the Python version but implemented with immutable collections (Map) and a two-pass map and foldLeft.

To Run:

Make sure you have the Scala 3 compiler (scalac) and runner (scala) installed.

scalac scala3/Logic.scala

scala scala3.Logic

4. Elixir (elixir/)

A functional implementation that heavily uses Elixir's Enum module and pattern matching. It uses Enum.map_reduce/3 to efficiently perform the two-pass logic while threading the state of the target_counts map.

To Run:

elixir elixir/logic.ex


Next Steps: Building the "Bot"

With this core logic, you can now build the solver bot. The bot needs to:

Load a Word List: Get a comprehensive list of all valid 5-letter words.

Maintain State: Keep a list of "possible" words, which starts as the full word list.

Make a Guess: Pick a word from the list (a good starting guess is "SOARE" or "CRANE").

Get Feedback: Use the check_guess function (from this repo) to get feedback.

Filter the List: This is the other hard part. The bot must remove any words from its "possible" list that do not match the feedback.

e.g., if the feedback for CRANE is [Absent, Present, Absent, Present, Absent], the bot must:

Remove all words that have 'C', 'A', or 'N' in them.

Keep only words that do contain 'R' and 'E'.

Keep only words that do not have 'R' in position 2 or 'E' in position 4.

Repeat: Pick a new guess from the (much smaller) list and repeat until only one word is left.
