{Adapter,TextMessage,User} = require 'hubot'
async = require 'async'
Mime = require 'mime'

FB_MESSAGING_ENDPOINT = "https://graph.facebook.com/v2.6/me/messages"

class Messenger extends Adapter

  constructor: (@robot) ->
    super @robot

  send: (envelope, messages...) ->
    for msg in messages
      @_prepareAndSendMessage(envelope, msg)

  reply: @prototype.send


  _deliverMessages: (envelope, msgs) ->
    async.eachSeries msgs, (msg, callback) =>
      data = {
        recipient : {
          id: envelope.user.id
        },
        message : {}
      }

# From : https://github.com/chen-ye/hubot-fb/blob/master/src/fb.coffee#L55
      mime = Mime.lookup(msg)
      if mime is "image/jpeg" or mime is "image/png" or mime is "image/gif"
        data.message.attachment = { type: "image", payload: { url: msg }}
      else
        data.message.text = msg

      data = JSON.stringify(data)

      @robot.http(FB_MESSAGING_ENDPOINT + "?access_token=" + @options.pageAccessToken)
        .header('Content-Type', 'application/json')
        .post(data) (err, res, body) =>
          if err
            @robot.logger.error "Failed to send response : " + err
          else if res.statusCode != 200
            @robot.logger.error "Failed to send response : " + body
          callback()

  _deliverJsonMessage: (envelope, msg) ->
    data = {
      recipient : {
        id: envelope.user.id
      },
      message : {}
    }
    data.message.attachment = {
      "type": "template",
      "payload": msg
    }
    data = JSON.stringify(data)
    @robot.http(FB_MESSAGING_ENDPOINT + "?access_token=" + @options.pageAccessToken)
      .header('Content-Type', 'application/json')
      .post(data) (err, res, body) =>
        if err
          @robot.logger.error "Failed to send response : " + err
        else if res.statusCode != 200
          @robot.logger.error "Failed to send response : " + body

  _prepareAndSendMessage: (envelope, msg) ->
    jsonMsg = null
    try
      jsonMsg = JSON.parse(msg)
    catch error
    if jsonMsg
      @_deliverJsonMessage(envelope, jsonMsg)
    else if @options.longMessageAction == "truncate"
      @_deliverMessages(envelope, [msg.substring(0,317) + "..."])
    else if @options.longMessageAction == "split"
      lines = msg.split("\n")
      i = 0
      while i < lines.length
        if lines[i] > 320
          mime = Mime.lookup(lines[i])
          unless mime is "image/jpeg" or mime is "image/png" or mime is "image/gif"
            lines[i] = lines[i].substring(0,316) + "...\n"
        else
          lines[i] += "\n"
        i++
      toDeliver = ""
      chuncks = []
      i = 0
      while i < lines.length
        if toDeliver.length + lines[i].length <= 320
          toDeliver += lines[i]
          i++
        else
          chuncks.push(toDeliver.trim())
          toDeliver = ""
      if toDeliver.length > 0
          chuncks.push(toDeliver.trim())
          toDeliver = ""
      @_deliverMessages(envelope, chuncks)

  _extractLocationFromAttachment: (attachment) ->
    locationObj = null
    if attachment.type == "location"
      locationObj = {source: "facebook", lat: attachment.payload.coordinates.lat, long: attachment.payload.coordinates.long}
    else if attachment.title == 'Google Maps'
      try
        url = attachment.url
        locationParts = url.split("?u=")[1].split("q%3D")[1].split("%26")[0].split("%252C")
        locationObj = {source: "google", lat: locationParts[0], long: locationParts[1]}
      catch error
    if locationObj
      return "Sharing Location: #{JSON.stringify(locationObj)}"
    else
      return null

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
        if event.message
          @robot.logger.error JSON.stringify(event.message)
          if event.message.attachments and event.message.attachments.length > 0
            attachment =  event.message.attachments[0]
            @robot.logger.error JSON.stringify(attachment)
            text = @_extractLocationFromAttachment(attachment)
            if text
              user = new User senderId.toString(), room: senderId.toString()
              @robot.logger.info "Received message: '#{text}' from '#{senderId}'"
              @robot.receive new TextMessage(user, text)
          else if event.message.text
            text = event.message.text
            user = new User senderId.toString(), room: senderId.toString()
            @robot.logger.info "Received message: '#{text}' from '#{senderId}'"
            @robot.receive new TextMessage(user, text)
        if event.postback and event.postback.payload
          text = event.postback.payload
          user = new User senderId.toString(), room: senderId.toString()
          @robot.logger.info "Received message: '#{text}' from '#{senderId}'"
          @robot.receive new TextMessage(user, text)
        i++
      res.send 'OK'

    @robot.logger.info "Ready to receive messages .."

exports.use = (robot) ->
  new Messenger robot
