{Adapter,TextMessage,User} = require 'hubot'

FB_MESSAGING_ENDPOINT = "https://graph.facebook.com/v2.6/me/messages"

class Messenger extends Adapter

  constructor: (@robot) ->
    super @robot

  send: (envelope, messages...) ->
    for msg in messages
      @_prepareAndSendMessage(envelope, msg)

  reply: @prototype.send


  _deliverMessage: (envelope, msg) ->
    data = JSON.stringify({
      recipient : {
        id: envelope.user.id
      },
      message : {
        text : msg
      }
    })
    @robot.http(FB_MESSAGING_ENDPOINT + "?access_token=" + @options.pageAccessToken)
      .header('Content-Type', 'application/json')
      .post(data) (err, res, body) =>
        if err
          @robot.logger.error "Failed to send response : " + err
        else if res.statusCode != 200
          @robot.logger.error "Failed to send response : " + body

  _prepareAndSendMessage: (envelope, msg) ->
    if @options.longMessageAction == "truncate"
      @_deliverMessage(envelope, msg.substring(0,317) + "...")
    else if @options.longMessageAction == "split"
      lines = msg.split("\n")
      i = 0
      while i < 0
        if lines[i] > 320
          lines[i] = lines[i].substring(0,316) + "...\n"
        else
          lines[i] += "\n"
        i++
      toDeliver = ""
      i = 0
      while i < lines.length
        if toDeliver.length + lines[i].length <= 320
          toDeliver += lines[i]
          i++
        else
          @_deliverMessage(envelope, toDeliver.trim())
          toDeliver = ""
      if toDeliver.length > 0
          @_deliverMessage(envelope, toDeliver.trim())
          toDeliver = ""

  run: ->
    @options =
      verificationToken : process.env.HUBOT_MESSENGER_VERIFICATION_TOKEN
      pageAccessToken : process.env.HUBOT_MESSENGER_PAGE_ACCESS_TOKEN
      longMessageAction : process.env.HUBOT_MESSENGER_LONG_MESSAGE_ACTION

    return @robot.logger.error "No messenger verification token was provided" unless @options.verificationToken
    return @robot.logger.error "No messenger page access token was provided" unless @options.pageAccessToken

    @options.longMessageAction = "truncate" unless @options.longMessageAction

    @emit 'connected'

    @robot.router.get '/webhook', (req, res) =>
      @robot.logger.debug "Received a validation request"
      if req.query['hub.verify_token'] == @options.verificationToken
        res.send req.query['hub.challenge']
      else
        res.send "Error, wrong validation token"

    @robot.router.post '/webhook', (req,res) =>
      messaging_events = req.body.entry[0].messaging
      i = 0
      while i < messaging_events.length
        event = req.body.entry[0].messaging[i]
        senderId = event.sender.id
        if event.message and event.message.text
          text = event.message.text
          user = new User senderId, room: senderId
          @robot.logger.info "Received message: '#{text}' from '#{senderId}'"
          @robot.receive new TextMessage(user, text)
        i++
      res.send 'OK'

    @robot.logger.info "Ready to receive messages .."

exports.use = (robot) ->
  new Messenger robot
