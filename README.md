# Hubot Messenger Platform Adapter

Facebook has just announced its new [platform for messenger](https://developers.facebook.com/docs/messenger-platform). This is a hubot adapter for the new bot api.

![https://raw.githubusercontent.com/MohamedBassem/hubot-messenger-platform/master/imgs/bot.png](https://raw.githubusercontent.com/MohamedBassem/hubot-messenger-platform/master/imgs/bot.png)

## Installation

- `npm install --save hubot-messenger-platform`

## Requirement

- For this to work you'll need the following:
  1. Facebook page.
  2. Facbook Group.
  3. Reverse proxy with SSL setup ( i.e Nginx + letsencrypt ).

## Steps

1. Create the facebook page if you don't have one.
2. Create the facebook app if you don't have one.
3. Generate a random verification token of any length and note it with you.
4. From the facebook app's setting, go to the new messenger tab. In the token generation part, choose your page and note the page access token.
5. Start your bot with `HUBOT_MESSENGER_VERIFICATION_TOKEN=<verification_code> HUBOT_MESSENGER_PAGE_ACCESS_TOKEN=<page_access_code> ./bin/hubot -a messenger-platform -n ""`.
6. In the messenger's tab webhook section, add a new webhook. The endpoint should be `https://<your_domain>/webhook`. Choose all the events and verify.
7. Execute `curl -ik -X POST "https://graph.facebook.com/v2.6/me/subscribed_apps?access_token=<page_access_token>"` to subscribe your app to get updates from this page.

And Done. Now whenever you send a message to your bot's page inbox, hubot will process it and send the response back.

For more info, check [facebook's official guide](https://developers.facebook.com/docs/messenger-platform/quickstart).

## Important Notes

- The server should be running a reverse proxy that forwards the https traffic after SSL termination to `http://localhost:8080` assuming that the reverse proxy is running on the same host as hubot. If you started hubot specifying the `PORT` env var, this will override the default `8080` port.
- Self signed certificates won't be accepted by facebook. Letsencrypt certificates works perfectly.
- The `-n ""` flag when starting hubot, doesn't give the bot a name. So instead of sending `Hubot ping` to it, you'll just send `ping`.

## Contributions

Your contributions are welcome through pull requests or issues.
