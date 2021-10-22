require 'telegram/bot'
require 'logger'
require_relative 'lib/eggplant'

logger = Logger.new('eggplant_bot.log', level: :warn)
Telegram::Bot::Client.run(ENV['TOKEN'], logger: logger) do |bot|
  bot.logger.warn('Bot started')
  bot.listen do |message|

    case message
    when Telegram::Bot::Types::CallbackQuery
      if message.data['EggplantBotClick']
        game = Eggplant.games[message.message.chat.id]
        game.click(message.from.username, message.data, message.id) if game
      end

    when Telegram::Bot::Types::Message
      case message.text
      when /\/go\@FindEggplant/
        Eggplant.new(bot, message.chat.id).start unless Eggplant.games[message.chat.id]
      when /\/stat\@FindEggplant/
        user_wins = Eggplant.user_data(message.chat.id, message.from.username)
        text = "#{message.from.username} has #{user_wins} 🍆\n"
        bot.api.send_message(chat_id: message.chat.id, text: text)
      when /\/top\@FindEggplant/
        bot.api.send_message(chat_id: message.chat.id, text: Eggplant.chat_top(message.chat.id))
      end
    end
  end
end
