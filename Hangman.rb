require "net/http"
require "uri"
require "rubygems"
require "json"
require "set"

$dict_file = "/usr/share/dict/words"

class Game
    def initialize
	uri = URI.parse("http://gallows.hulu.com/play?code=magrimes@mtu.edu")
	response = Net::HTTP.get_response(uri)
	response_json = JSON.parse(response.body)
	@status		    = response_json["status"]
	@token		    = response_json["token"]
	@remaining_guesses  = response_json["remaining_guesses"]
	@state		    = response_json["state"]
	@guessed	    = Set.new
	@possible_guesses   = Hash.new
	@current_word = 0   # current word being guessed
	@current_word_len = 0
	@word_lengths = Array.new
    end

    def guess(letter)
	uri = URI.parse("http://gallows.hulu.com/play?code=magrimes@mtu.edu" \
			"&token=#{@token}&guess=#{letter}")
	response = Net::HTTP.get_response(uri)
	response_json = JSON.parse(response.body)

	guess_was_wrong = response_json["remaining_guesses"] < @remaining_guesses

	@status		    = response_json["status"]
	@token		    = response_json["token"]
	@remaining_guesses  = response_json["remaining_guesses"]
	@state		    = response_json["state"]
	@guessed.add(letter)

	deleted = 0
	if guess_was_wrong
	    puts "We guessed wrong!"
	    @possible_guesses.each do |k, word|
		if word.include?(letter)
		    @possible_guesses.delete(k)
		    deleted += 1
		end
	    end
	else
	    puts "Correct guess!"
	    vals = Hash.new
	    words = @state.split(" ")

	    # add all word lengths containing the correctly guessed letter
	    # as well as the index that the letter was found at into a hash
	    letter = letter.capitalize
	    words.each do |word|
		if word.include?(letter)
		    vals.store(word.length, word.index(letter))
		end
	    end

	    # remove all letters with correct guessed letter at
	    # index it was found
	    @possible_guesses.each do |k, word|
		vals.each do |len, index|
		    if word.length == len and word[index] == letter.downcase
			@possible_guesses.delete(k)
			deleted += 1
		    end
		end
	    end
	end

	puts "Deleted #{deleted} words from possible guess list!"

    end

    def status
	@status
    end

    def status=(status)
	@status = status
    end

    def print_game
	print "\n"
	puts "Status: #{@status}"
	puts "Token: #{@token}"
	puts "Guesses Left: #{@remaining_guesses}"
	puts "State: #{@state}"
	print "\n"
    end

    def get_next_word
	# get the index of the first uncompleted word
	words = @state.split(" ")

	@current_word = 0
	while (!words[@current_word].include?("_"))
	    @current_word = @current_word + 1
	end
	@current_word_len = words[@current_word].length
	puts "Currently trying to guess word #{@current_word}"
    end

    def word_completed?
	words = @state.split(" ")
	return !words[@current_word].include?("_")
    end

    def get_word_lengths
	words = @state.split(" ")
	words.each do |word|
	    @word_lengths.push(word.length)
	end
    end

    #
    # As of right now, this method will fill the @possible_guesses list with
    # all words of the same length as the word we are trying to guess.
    #
    def get_guesses
	if File.exist?($dict_file)
	    dict = File.open($dict_file, "r") do |file|
		words = @state.split(" ")
		file.each do |line|

		    # add all words of the same length as words we are looking for
		    correct_length = @word_lengths.include?(line.length - 1)
		    start_with_uppercase = ('A'..'Z').to_a.include?(line[0])

		    if (correct_length and not start_with_uppercase)
			    @possible_guesses[line] = line
		    end
		end
		puts "Added #{@possible_guesses.count} possible words!"
	    end
	else
	    puts "ERROR - Could not find dictionary file: #{dict_file}"
	end
    end

    def calculate_frequencies
	letters = Array.new(26, 0)

	@possible_guesses.each do |k, word|
	    word.each_char do |letter|
		if (letter == "\n" or letter[0] < 97)
		    break
		end
		offset = letter[0] - 97
		letters[offset] = letters[offset] + 1
	    end
	end

	# print out frequencies of each char
	# for i in 0..25
	#    print "#{(i + 97).chr} : #{letters[i]}   "
	# end
	# print "\n"

	@guessed.each do |letter|
	    letters[letter[0] - 97] = 0
	end

	letters.index(letters.max)
    end

end

#########################################################
#		Start of main program			#
#########################################################

puts "Starting new game..."
game = Game.new
game.get_word_lengths
game.get_guesses
while (game.status == "ALIVE")

    game.print_game

    # special case for when first word is a single letter -
    # unix dictionary has each letter being a word on its own

    guessed_i = false
    if @current_word_len == 1
	puts "current word is one letter"
	if (guessed_i)
	    guess_char = "a"
	else
	    guess_char = "i"
	    guessed_i = true
	end
    else
	best = game.calculate_frequencies
	guess_char = (best + 97).chr
    end

    puts "Guessing #{guess_char}..."

    game.guess(guess_char)

end

if (game.status == "FREE")
    print "\nYou won!\n"
else
    print "\nHe's dead, Jim...\n"
end

game.print_game
