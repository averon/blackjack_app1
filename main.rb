require 'rubygems'
require 'sinatra'
require 'pry'

set :sessions, true

helpers do
  def initialize_game
    construct_deck
  
    session[:player_chips] = 500
    session[:player_bet] = 0
    clear_hands
    deal_cards
  end

  def construct_deck
    values = %w[2 3 4 5 6 7 8 9 10 J Q K A]
    suits = %w[S C D H]
    session[:deck] = values.product(suits).shuffle
  end

  def clear_hands
    session[:dealer_cards] = []
    session[:player_cards] = []
    construct_deck if session[:deck].size < 20
  end

  def deal_cards
    2.times do
      session[:player_cards] << session[:deck].pop
      session[:dealer_cards] << session[:deck].pop
    end
  end

  def jpg card
    output = ""
    output << 'spades' if card[1] == 'S'
    output << 'clubs' if card[1] == 'C'
    output << 'diamonds' if card[1] == 'D'
    output << 'hearts' if card[1] == 'H'
    output << '_' + card[0] + '.jpg' if card[0] <= '9'
    output << '_jack.jpg' if card[0] == 'J'
    output << '_queen.jpg' if card[0] == 'Q'
    output << '_king.jpg' if card[0] == 'K'
    output << '_ace.jpg' if card[0] == 'A'
    "/images/cards/" + output
  end

  def hit player_hand
     player_hand << session[:deck].pop if hand_value(player_hand) < 21
  end

  def hand_value hand
    points = 0
    aces = 0
    hand.each do |card|
      if card[0] > "9" and card[0] != "A"
        points += 10
      elsif card[0] == "A"
        points += 11
        aces += 1
      else
        points += card[0].to_i
      end
    end
    aces.times { points -= 10 if points > 21 }

    points
  end

  def phv
    hand_value session[:player_cards]
  end

  def dhv
    hand_value session[:dealer_cards]
  end

  def autoplay player
    if hand_value(player) < 17
      hit player
      autoplay player
    end
  end
end

get '/' do
  if session[:player_name]
    initialize_game
    erb :player_turn
  else
    redirect '/new_player'
  end
end

get '/new_player' do
  session[:player_name] = nil
  erb :new_player
end

post '/new_player' do
  if params[:player_name].empty?
    @info = "Please enter your name to play!"
    erb :new_player
  else
    session[:player_name] = params[:player_name]
    initialize_game
    redirect '/player_turn'
  end
end

get '/player_turn' do
  erb :player_turn
end

get '/end_of_round' do
  autoplay session[:dealer_cards]
  unless phv > 21
    if phv > dhv or dhv > 21
      session[:player_chips] = session[:player_chips].to_i + session[:player_bet].to_i * 2
      @success = "#{session[:player_name]} wins! You now have #{session[:player_chips]} chips."
    elsif phv == dhv
      @error = "Push."
    end
  end
  @alert = "Dealer wins. You now have #{session[:player_chips]} chips." if phv > 21 or (dhv <= 22 && dhv > phv)
  erb :end_of_round
end

post '/play_again' do
  if phv == dhv
    @error = "Push round! Your bet is #{session[:player_bet]} chips."
    clear_hands
    deal_cards
    erb :player_turn
  elsif params[:player_bet].to_i < 5
    @alert = "You have to bet at least 5 to play!"
    erb :end_of_round
  elsif params[:player_bet].to_i <= session[:player_chips].to_i
    session[:player_bet] = params[:player_bet]
    session[:player_chips] = session[:player_chips].to_i - session[:player_bet].to_i
    @success = "You bet #{session[:player_bet]} chips!"
    clear_hands
    deal_cards
    erb :player_turn
  else
    @alert = "You don't have enough chips!"
    erb :end_of_round
  end
end

post '/hit' do
  unless hand_value(session[:player_cards]) > 21
    hit session[:player_cards]
    @error = "You've busted!" if phv > 21
    @success = "Blackjack!" if phv == 21
    erb :player_turn
  else
    @alert = "You've already busted!"
    erb :player_turn
  end
end

post '/stay' do
  redirect '/end_of_round'
end