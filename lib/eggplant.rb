require 'pstore'
require 'matrix'

class Eggplant

  class << self
    def games
      @@games ||= {}
    end

    def store
      @@store ||= PStore.new('eggplant_bot.pstore')
    end

    def user_data(chat_id, username)
      store.transaction(true) do
        store.fetch(chat_id, {}).fetch(username, 0)
      end
    end

    def chat_top(chat_id)
      text = "Top 10: \n\n"
      store.transaction(true) do
        users = (store.fetch(chat_id, {})).sort_by{|k, v| -v}.first(10)
        users.each{|user, wins| text << "#{user} (#{wins} 🍆)\n"} unless users.empty?
      end
      text
    end
  end

  def initialize(bot, chat_id)
    @bot = bot
    @chat_id = chat_id
    self.class.games[chat_id] = self
    @message_id = nil
    @matrix = Matrix.build(3, 3){'❓'}.to_a
    @point = [rand(3), rand(3)]
    @click_time = {}
  end

  def api(method, **params)
    begin
      @bot.api.send(method, params)
    rescue => e
      @bot.logger.error("Telegram error! #{e.message}") unless e.error_code === 400
    end
  end

  def start
    @message_id = api(
      :send_message,
      chat_id: @chat_id,
      text: 'Find the 🍆',
      reply_markup: build_buttons
    ).dig('result', 'message_id')
  end

  def build_buttons
    buttons = []
    @matrix.each_with_index do |r, x|
      row = []
      r.each_with_index do |cell, y|
        row << Telegram::Bot::Types::InlineKeyboardButton.new(
          text: cell,
          callback_data: "EggplantBotClick|#{x}|#{y}"
        )
      end
      buttons << row
    end
    Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: buttons)
  end

  def rebuild_buttons
    api(
      :edit_message_reply_markup,
      chat_id: @chat_id,
      message_id: @message_id,
      reply_markup: build_buttons
    )
  end

  def click(user, data, callback_query_id)
    if @click_time[user] && (Time.now.utc - @click_time[user]) < 1
      api(
        :answer_callback_query,
        callback_query_id: callback_query_id,
        text: "Pleas wait..."
      )
      return
    end

    a, x, y = data.split('|').map(&:to_i)

    if @point === [x, y]
      @matrix[x][y] = '🍆'
      rebuild_buttons
      sleep 1
      award(user)
    else
      @matrix[x][y] = '🍑'
      rebuild_buttons
    end

    @click_time[user] = Time.now.utc
  end

  def award(user)
    user_wins = update_balance(user)
    api(
      :edit_message_text,
      chat_id: @chat_id,
      message_id: @message_id,
      text: "#{user} won and now has #{user_wins} 🍆 !"
    )
    Eggplant.games[@chat_id] = nil
  end

  def update_balance(user)
    user_wins = nil
    store = self.class.store

    store.transaction do
      chat_data = store.fetch(@chat_id, {})
      user_wins = chat_data.fetch(user, 0) + 1
      chat_data[user] = user_wins
      store[@chat_id] = chat_data
    end

    user_wins
  end

end
