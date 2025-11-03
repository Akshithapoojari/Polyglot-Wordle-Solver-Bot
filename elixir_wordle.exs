defmodule MockWordleGame do
  defstruct answer: nil, tries: 0, max_tries: 6

  def new(answer) do
    %MockWordleGame{answer: String.downcase(answer)}
  end

  def guess(game, guess_word) do
    guess_word = String.downcase(guess_word)
    game = %{game | tries: game.tries + 1}

    cond do
      game.tries > game.max_tries ->
        {%{message: "Tries exceeded", feedback: "FAIL", answer: game.answer}, game}
      guess_word == game.answer ->
        {%{message: "You won!", feedback: "WIN", answer: game.answer}, game}
      true ->
        feedback = generate_feedback(guess_word, game.answer)
        {%{message: "Keep guessing", feedback: feedback, answer: "unknown"}, game}
    end
  end

  defp generate_feedback(guess_word, answer) do
    guess_list = String.to_charlist(guess_word)
    answer_list = String.to_charlist(answer)

    # First pass for greens (exact matches)
    {feedback, remaining_answer} =
      Enum.zip(guess_list, answer_list)
      |> Enum.with_index()
      |> Enum.map_reduce(answer_list, fn {{g, a}, i}, acc_answer ->
        if g == a do
          {{?G, i}, List.replace_at(acc_answer, i, nil)}
        else
          {{?_, i}, acc_answer}
        end
      end)

    # Second pass for yellows and greys
    Enum.zip(guess_list, feedback)
    |> Enum.map_reduce(remaining_answer, fn {g, {f, _}}, acc_answer ->
      if f == ?G do
        {?G, acc_answer}
      else
        case Enum.find_index(acc_answer, &(&1 == g)) do
          nil ->
            {?R, acc_answer}
          found_index ->
            {?Y, List.replace_at(acc_answer, found_index, nil)}
        end
      end
    end)
    |> elem(0)
    |> to_string()
  end
end

defmodule WordleBot do
  defstruct words: [], tries: 0, allowed: 6, status: "PLAY", game_instance: nil, guess: nil, response: nil

  def new(game_instance) do
    words =
      try do
        "words_5.txt"
        |> File.read!()
        |> String.split("
", trim: true)
        |> Enum.filter(&(&1 != ""))
        |> Enum.map(&String.upcase/1)
      rescue
        _ ->
          IO.puts("words_5.txt not found. Using a default list.")
          ["ABOVE", "ABOUT", "ACORN", "AFOOT", "AFORE"]
      end

    words = Enum.shuffle(words)
    guess = hd(words)

    IO.puts("Starting new game. Guessing with first word: #{guess}")

    %WordleBot{
      words: words,
      game_instance: game_instance,
      guess: guess
    }
  end

  def start_solving(bot) do
    case bot.status do
      "PLAY" ->
        bot
        |> play_turn()
        |> start_solving()
      _ ->
        :ok
    end
  end

  defp play_turn(bot) do
    if bot.words == [] do
      IO.puts("No possible words left! The bot has failed.")
      %{bot | status: "ERROR"}
    else
      bot = %{bot | tries: bot.tries + 1}
      IO.puts("
Attempt #{bot.tries}: Guessing '#{bot.guess}'")

      {response, new_game_instance} = MockWordleGame.guess(bot.game_instance, bot.guess)
      bot = %{bot | game_instance: new_game_instance, response: response.feedback}

      cond do
        response.feedback == "WIN" ->
          IO.puts("Bot WON in #{bot.tries} tries! Answer was #{bot.guess}")
          %{bot | status: "WON"}
        bot.tries >= bot.allowed ->
          IO.puts("Bot EXCEEDED tries.")
          IO.puts("Answer was #{response.answer}")
          %{bot | status: "EXCEEDED"}
        true ->
          IO.puts("Feedback: #{response.feedback}")
          new_words = drop_impossibles(bot)
          new_guess = if new_words != [], do: hd(new_words), else: nil
          %{bot | words: new_words, guess: new_guess}
      end
    end
  end

  defp drop_impossibles(bot) do
    guess_chars = String.to_charlist(bot.guess)
    response_chars = String.to_charlist(bot.response)

    # Determine greens, yellows, and greys from feedback
    {greens, yellows, greys} =
      Enum.zip(guess_chars, response_chars)
      |> Enum.with_index()
      |> Enum.reduce({%{}, %{}, MapSet.new()}, fn {{guess_char, feedback_char}, pos}, {acc_greens, acc_yellows, acc_greys} ->
        case feedback_char do
          ?G ->
            {Map.put(acc_greens, pos, guess_char), acc_yellows, acc_greys}
          ?Y ->
            {acc_greens, Map.update(acc_yellows, guess_char, 1, &(&1 + 1)), acc_greys}
          ?R ->
            # A letter is grey only if it's not also green or yellow elsewhere in the guess
            is_also_green_or_yellow = Enum.any?(Enum.with_index(guess_chars), fn {c, i} ->
              c == guess_char and Enum.at(response_chars, i) != ?R
            end)
            if is_also_green_or_yellow do
              {acc_greens, acc_yellows, acc_greys}
            else
              {acc_greens, acc_yellows, MapSet.put(acc_greys, guess_char)}
            end
        end
      end)

    # Filter the word list based on the constraints
    Enum.filter(bot.words, fn word ->
      word_chars = String.to_charlist(word)
      word_counts = Enum.frequencies(word_chars)

      # Check greens: all green letters must be in the correct positions
      greens_ok = Enum.all?(greens, fn {pos, char} -> Enum.at(word_chars, pos) == char end)

      # Check greys: word must not contain any grey letters
      greys_ok = Enum.all?(greys, fn char -> not (char in word_chars) end)

      # Check yellows:
      yellows_ok =
        Enum.all?(yellows, fn {char, count} ->
          # Word must contain at least the number of yellow letters
          Map.get(word_counts, char, 0) >= count and
          # The yellow letter must not be in the same position as the guess
          !Enum.any?(Enum.with_index(guess_chars), fn {gc, pos} ->
            gc == char and Enum.at(response_chars, pos) == ?Y and Enum.at(word_chars, pos) == char
          end)
        end)

      greens_ok and greys_ok and yellows_ok
    end)
  end
end

defmodule Main do
  def run do
    # Use the same answer as the Python script for consistent output
    game = MockWordleGame.new("RAISE")
    bot = WordleBot.new(game)
    WordleBot.start_solving(bot)
  end
end

Main.run()