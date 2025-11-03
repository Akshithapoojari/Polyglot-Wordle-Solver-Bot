

import scala.io.Source
import scala.util.Random
import scala.collection.mutable.{Map => MMap, Set => MSet, ArrayBuffer}

// --- A mock Wordle game to test the bot against ---
class MockWordleGame(answer: String) {
  private val lowerCaseAnswer = answer.toLowerCase()
  private var tries: Int = 0
  private val maxTries: Int = 6

  def guess(guessWord: String): Map[String, String] = {
    tries += 1
    val lowerCaseGuessWord = guessWord.toLowerCase()

    if (tries > maxTries) {
      return Map("message" -> "Tries exceeded", "feedback" -> "FAIL", "answer" -> lowerCaseAnswer)
    }

    if (lowerCaseGuessWord == lowerCaseAnswer) {
      return Map("message" -> "You won!", "feedback" -> "WIN", "answer" -> lowerCaseAnswer)
    }

    val feedback = Array.fill(5)(' ')
    val answerList = ArrayBuffer.from(lowerCaseAnswer.toSeq)

    // First pass for greens (exact matches)
    for (i <- lowerCaseGuessWord.indices) {
      if (lowerCaseGuessWord(i) == answerList(i)) {
        feedback(i) = 'G'
        answerList(i) = 0.toChar // Mark as used
      }
    }

    // Second pass for yellows and reds
    for (i <- lowerCaseGuessWord.indices) {
      if (feedback(i) != 'G') {
        val charToFind = lowerCaseGuessWord(i)
        val charIndexInAnswerList = answerList.indexOf(charToFind)
        if (charIndexInAnswerList != -1) {
          feedback(i) = 'Y'
          answerList(charIndexInAnswerList) = 0.toChar // Mark as used
        } else {
          feedback(i) = 'R' // Red
        }
      }
    }

    Map("message" -> "Keep guessing", "feedback" -> feedback.mkString, "answer" -> "unknown")
  }
}

// --- The corrected WordleBot class ---
class WordleBot(mockGameInstance: MockWordleGame) {
  import WordleBot._

  private var words: List[String] = _
  private var tries: Int = 0
  private val allowed: Int = 6
  private var status: String = "PLAY"
  private val gameInstance: MockWordleGame = mockGameInstance
  
  private var guess: String = ""
  private var responseFeedback: String = ""

  if (FIRST_TIME) {
    FIRST_TIME = false
    try {
      wordStore = Source.fromFile("words_5.txt").getLines()
                                  .map(_.trim.toUpperCase)
                                  .filter(_.length == 5)
                                  .toList
    } catch {
      case _: java.io.FileNotFoundException =>
        println("words_5.txt not found. Using a default list.")
        wordStore = List("ABOVE", "ABOUT", "ACORN", "AFOOT", "AFORE")
    }
  }
  
  words = Random.shuffle(wordStore)
  
  guess = if (words.nonEmpty) words.head else ""
  if (guess.nonEmpty) {
    println(s"Starting new game. Guessing with first word: $guess")
  } else {
    status = "ERROR"
    println("No words in the word list.")
  }

  def dropImpossibles(): Unit = {
    val greens: MMap[Int, Char] = MMap()
    val yellows: MMap[Char, Int] = MMap()
    val greys: MSet[Char] = MSet()
    
    for (pos <- responseFeedback.indices) {
      val feedbackChar = responseFeedback(pos)
      val guessedChar = guess(pos)
      
      if (feedbackChar == 'G') {
        greens(pos) = guessedChar
      } else if (feedbackChar == 'Y') {
        yellows(guessedChar) = yellows.getOrElse(guessedChar, 0) + 1
      } else { // Red 'R'
        val isAllGrey = guess.indices.forall { i =>
          !(guess(i) == guessedChar && responseFeedback(i) != 'R')
        }
        if (isAllGrey) {
          greys += guessedChar
        }
      }
    }
    
    words = words.filter { word =>
      val greenCheck = greens.forall { case (pos, char) => word(pos) == char }
      
      val yellowCheck = {
        val wordCounts = word.groupMapReduce(identity)(_ => 1)(_ + _)
        yellows.forall { case (char, count) =>
          wordCounts.getOrElse(char, 0) >= count &&
          !guess.indices.exists(pos => guess(pos) == char && responseFeedback(pos) == 'Y' && word(pos) == char)
        }
      }
      
      val greyCheck = greys.forall(char => !word.contains(char))
      
      greenCheck && yellowCheck && greyCheck
    }
  }

  def playTurn(): Unit = {
    if (words.isEmpty) {
      println("No possible words left! The bot has failed.")
      status = "ERROR"
      return
    }
      
    tries += 1
    println(s"\nAttempt $tries: Guessing '$guess'")
    val responseMap = gameInstance.guess(guess)
    
    responseFeedback = responseMap("feedback")
    
    if (responseFeedback == "WIN") {
      println(s"Bot WON in $tries tries! Answer was $guess")
      status = "WON"
      return
    }
    
    if (tries >= allowed) {
      println("Bot EXCEEDED tries.")
      status = "EXCEEDED"
      println(s"Answer was ${responseMap("answer")}")
      return
    }

    println(s"Feedback: $responseFeedback")

    dropImpossibles()
    
    if (words.isEmpty) {
      println("No possible words left!")
      status = "ERROR"
      return
    }

    guess = words.head
  }

  def startSolving(): Unit = {
    while (status == "PLAY") {
      playTurn()
      Thread.sleep(1000)
    }
  }
}

object WordleBot {
  var FIRST_TIME: Boolean = true
  var wordStore: List[String] = List.empty
}

// --- How to run the bot ---
object Wordle extends App {
  val wordleGame = new MockWordleGame(answer = "AKSHU")
  val bot = new WordleBot(mockGameInstance = wordleGame)
  bot.startSolving()
}
