import random
import json
import time
from collections import Counter

# --- A mock Wordle game to test the bot against ---
# This class simulates the server-side Wordle game.
# The bot will play against this.
class MockWordleGame:
    def __init__(self, answer: str):
        self.answer = answer.lower()
        self.tries = 0
        self.max_tries = 6

    def guess(self, guess_word: str) -> dict:
        self.tries += 1
        guess_word = guess_word.lower()

        if self.tries > self.max_tries:
            return {"message": "Tries exceeded", "feedback": "FAIL", "answer": self.answer}

        if guess_word == self.answer:
            return {"message": "You won!", "feedback": "WIN", "answer": self.answer}

        feedback = [" ", " ", " ", " ", " "]
        answer_list = list(self.answer)

        # First pass for greens (exact matches)
        for i in range(len(guess_word)):
            if guess_word[i] == answer_list[i]:
                feedback[i] = "G"
                answer_list[i] = None # Mark as used

        # Second pass for ambers and greys
        for i in range(len(guess_word)):
            if feedback[i] != "G":
                if guess_word[i] in answer_list:
                    feedback[i] = "Y"
                    # Mark the first occurrence of the letter in the answer as used
                    answer_list[answer_list.index(guess_word[i])] = None
                else:
                    feedback[i] = "R" # Red

        return {"message": "Keep guessing", "feedback": "".join(feedback), "answer": "unknown"}


# --- The corrected WordleBot class ---
class WordleBot:
    # Class variables for memoization
    FIRST_TIME = True
    word_store = []

    def __init__(self, mock_game_instance: MockWordleGame):
        """
        Initializes the bot, loading the word list if this is the first instance.
        
        Args:
            mock_game_instance: An instance of a Wordle-like game to play against.
        """
        if WordleBot.FIRST_TIME:
            WordleBot.FIRST_TIME = False
            try:
                # Assuming 'words_5.txt' exists and contains a list of 5-letter words
                with open("words_5.txt", "r") as f:
                    WordleBot.word_store = [_.strip().upper() for _ in f if len(_.strip()) == 5]
            except FileNotFoundError:
                print("words_5.txt not found. Using a default list.")
                WordleBot.word_store = ["ABOVE", "ABOUT", "ACORN", "AFOOT", "AFORE"]
        
        # Use a copy of the master word list
        self.words = WordleBot.word_store[:]
        random.shuffle(self.words)
        
        self.tries = 0
        self.allowed = 6
        self.status = "PLAY"
        self.game_instance = mock_game_instance
        
        self.guess = self.words[0] if self.words else ""
        self.response = ""
        if self.guess:
            print(f"Starting new game. Guessing with first word: {self.guess}")
        else:
            self.status = "ERROR"
            print("No words in the word list.")

    def drop_impossibles(self):
        """Filters the word list based on the feedback from the last guess."""

        # Count occurrences of letters in the guess
        guess_counts = Counter(self.guess)
        
        # Determine greens, yellows, and confirmed "not in word" letters
        greens = {}  # {pos: char}
        yellows = {} # {char: count}
        greys = set() # {char}
        
        for pos, feedback_char in enumerate(self.response):
            guess_char = self.guess[pos]
            if feedback_char == "G":
                greens[pos] = guess_char
            elif feedback_char == "Y":
                if guess_char not in yellows:
                    yellows[guess_char] = 0
                yellows[guess_char] += 1
            else: # Red 'R'
                # A letter is definitively grey only if all its occurrences in the guess are grey
                is_all_grey = True
                for i in range(len(self.guess)):
                    if self.guess[i] == guess_char and self.response[i] != "R":
                        is_all_grey = False
                        break
                if is_all_grey:
                    greys.add(guess_char)
        
        # Filter the word list
        new_words = []
        for word in self.words:
            # Check for greens
            if not all(word[pos] == char for pos, char in greens.items()):
                continue

            # Check for yellows
            is_valid_yellow = True
            word_counts = Counter(word)
            for char, count in yellows.items():
                # Word must contain at least as many of the yellow letters as counted
                if word_counts[char] < count:
                    is_valid_yellow = False
                    break
                
                # The yellow letter must not be in the position of the guess
                for pos in range(len(self.guess)):
                    if self.guess[pos] == char and self.response[pos] == "Y" and word[pos] == char:
                        is_valid_yellow = False
                        break
            if not is_valid_yellow:
                continue

            # Check for greys
            is_valid_grey = True
            for char in greys:
                # The word must not contain this letter
                if char in word:
                    is_valid_grey = False
                    break
            if not is_valid_grey:
                continue

            new_words.append(word)

        self.words = new_words


    def play_turn(self):
        """Performs a single guess and updates the bot's state."""
        if not self.words:
            print("No possible words left! The bot has failed.")
            self.status = "ERROR"
            return
            
        self.tries += 1
        print(f"\nAttempt {self.tries}: Guessing '{self.guess}'")
        response = self.game_instance.guess(self.guess)
        
        # Capture the feedback and check for end conditions
        self.response = response["feedback"]
        
        if self.response == "WIN":
            print(f"Bot WON in {self.tries} tries! Answer was {self.guess}")
            self.status = "WON"
            return
        
        if self.tries >= self.allowed:
            print("Bot EXCEEDED tries.")
            self.status = "EXCEEDED"
            print(f"Answer was {response['answer']}")
            return

        print(f"Feedback: {self.response}")

        self.drop_impossibles()
        
        # If there are no words left, something is wrong
        if not self.words:
            print("No possible words left!")
            self.status = "ERROR"
            return

        # Choose the next guess from the remaining possible words
        self.guess = self.words[0]

    def start_solving(self):
        """The main game loop."""
        while self.status == "PLAY":
            self.play_turn()
            time.sleep(1)

# --- How to run the bot ---
if __name__ == "__main__":
    # Create a new mock game with a specific answer
    wordle_game = MockWordleGame(answer="RETRY")

    # Initialize the bot and pass the game instance to it
    bot = WordleBot(mock_game_instance=wordle_game)

    # Start the bot's game loop
    bot.start_solving()
