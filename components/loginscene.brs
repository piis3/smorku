function init() 
    setConfig()
    m.arrays = ArrayUtil()
    m.math = MathUtil()
    m.baseUrl = "https://api.smugmug.com/services/oauth/1.0a/getRequestToken"
    m.authUrl = "https://api.smugmug.com/services/oauth/1.0a/authorize"
    m.tokenUrl = "https://api.smugmug.com/services/oauth/1.0a/getAccessToken"

    m.registry = RegistryUtil()
    m.authData = m.registry.readSection("auth")
    
    loggedIn = m.authData <> invalid and m.authData.oauthTokenSecret <> invalid
    'stop 
    if loggedIn
        creds = {
            user: m.authData.user,
            apiKey: m.global.apiKey,
            apiSecret: m.global.apiSecret,
            token: m.authData.oauthToken,
            tokenSecret: m.authData.oauthTokenSecret
        }
        m.signer = RequestSigner(creds)
    else
        setAnonymousCreds()
        m.top.loggedIn = false
    end if

    m.global.addFields({creds:  m.signer.creds})

    'm.top.visible = not loggedIn
    m.loginGroup = m.top.findNode("loginGroup")
    m.loginGroup.visible = true
    
    m.loginGroup.translation = [
        1280 / 2 ,
        (720 / 2) - 115
    ]

    'stop
    m.lookupButton = m.loginGroup.findNode("lookup")
    m.lookupButton.observeField("buttonSelected", "showSelectUser")

    m.loginButton = m.loginGroup.findNode("loginButton")
    m.loginButton.observeField("buttonSelected", "performLogin")
     
    if loggedIn
        requestAuthedUser("selectLoggedInUser")
    end if
end function

function SetConfig()
    m.global.addFields({
        apiUrl: "https://api.smugmug.com",
        apiKey: "smugmug api key",
        apiSecret: "smugmug api secret",
    })

    uriFetcher = createObject("roSGNode", "UriFetcher")
    m.global.addFields({uriFetcher: uriFetcher})
end function

function setAnonymousCreds()
    creds = {
        apiKey: m.global.apiKey,
        apiSecret: m.global.apiSecret
    }
    m.signer = RequestSigner(creds)
end function

function showLoginScreen(msg as object)
    if msg.getData()
        m.top.visible = true
        m.loginGroup.setFocus(true)
    else
        m.top.visible = false
        m.loginGroup.setFocus(false)
    end if
end function

function selectLoggedInUser(msg as object)
    if msg.getData().code = 401
        ' That means our token is invalid, so we should clear it out
        setAnonymousCreds()
        m.top.loggedIn = false
        print "Got not authorized on authed user, assume our token is invalid"
        m.top.visible = true
        return invalid
    end if

    js = ParseJSON(msg.getData().content)
    user = js.Response.User.Name
    print "Logged in user is "; user
    m.top.loggedIn = true
    m.top.selectedUser = user
end function

function showSelectUser(msg as object)
    dialog = createObject("roSGNode", "userLookupDialog")
    dialog.observeField("selectedUser", "selectOtherUser")
    m.top.getScene().dialog = dialog
end function

function selectOtherUser(msg as object)
    print "Selected other user: "; msg.getData()
    m.top.selectedUser = msg.getData() 
end function

function showEnterPinDialog(msg as object)
    m.pinDialog = createObject("roSGNode", "PinDialog")
    m.pinDialog.title = "Enter verification code"
    m.pinDialog.pinPad.pinLength = 6
    m.pinDialog.pinPad.secureMode = false
    m.pinDialog.buttons = ["OK", "Cancel"]
    m.pinDialog.observeField("buttonSelected", "gotUserVerficationCode")
    m.top.getScene().dialog = m.pinDialog
end function

function performLogin(msg as object) 
    loginDialog = createObject("roSGNode", "LoginURLDialog")
    loginDialog.observeField("enterPinSelected", "showEnterPinDialog")
    m.top.getScene().dialog = loginDialog

    tokenReq = tokenRequest(m.baseUrl)
    m.tokenRequestData = {}
    reqUrl = m.baseUrl + "?" + tokenReq  
    ctx = createObject("RoSGNode", "Node")
    params = {
        uri: reqUrl,
        accept: "application/json"
    }
    ctx.addFields({parameters: params, response: {}})
    ctx.observeField("response", "onTokenRequest")
    m.global.uriFetcher.request = {context: ctx}
    
end function

' Generates oauth query string to generate an access token request
function tokenRequest(baseUrl as String) as String
    deviceInfo = createObject("roDeviceInfo")
    dateTime = createObject("roDateTime")
    params = {
        oauth_callback: "oob",
        oauth_consumer_key: m.global.apiKey,
        oauth_nonce: deviceInfo.getRandomUUID(),
        oauth_signature_method: "HMAC-SHA1",
        oauth_timestamp: dateTime.asSeconds().toStr(),
        oauth_version: "1.0",
        Access: "Full",
        Permissions: "Read"
    }

    keys = params.keys()
    keys.sort()
    dim kvs[keys.count() - 1]
    for each key in keys
        kvs.push(key + "=" + params.lookup(key).escape())
    end for

    paramString = kvs.join("&").escape()
    hmac = createObject("roHMAC")
    keyBytes = createObject("roByteArray")
    keyBytes.fromAsciiString(m.global.apiSecret + "&")
    
    messageBytes = createObject("roByteArray")
    messageBytes.fromAsciiString("GET&" + baseUrl.escape() + "&" + paramString)

    print "Signing message: " + messageBytes.toAsciiString()
    hmac.setup("sha1", keyBytes)
   
    signature = hmac.process(messageBytes).toBase64String()
    kvs.push("oauth_signature=" + signature.escape())
    return kvs.join("&")
end function

function onTokenRequest(msg as object)
    print "Entered onTokenRequest"
    content = msg.getData().content

    params = content.split("&")
    for each param in params
        parts = param.split("=")
        m.tokenRequestData.AddReplace(parts[0], parts[1])
    end for

    fullUrl =  m.authUrl + "?" + content

    print "Get authorization URL: "; fullUrl
    loginDialog = m.top.getScene().dialog
    if loginDialog <> invalid then loginDialog.authUrl = fullUrl

end function

function gotUserVerficationCode(msg as object)
    if msg.getData() = 1
        ' cancel route
        m.pinDialog.close = true
        return invalid
    end if 

    print "Got code "; m.pinDialog.pin
    pin = m.pinDialog.pin

    m.pinDialog.close = true

    deviceInfo = createObject("roDeviceInfo")
    dateTime = createObject("roDateTime")
    params = {
        oauth_consumer_key: m.global.apiKey,
        oauth_nonce: deviceInfo.getRandomUUID(),
        oauth_signature_method: "HMAC-SHA1",
        oauth_timestamp: dateTime.asSeconds().toStr(),
        oauth_version: "1.0",
        oauth_verifier: pin,
        oauth_token: m.tokenRequestData.lookup("oauth_token")
        Access: "Full",
        Permissions: "Read"
    }

    keys = params.keys()
    keys.sort()
    dim kvs[keys.count() - 1]
    for each key in keys
        kvs.push(key + "=" + params.lookup(key).escape())
    end for

    paramString = kvs.join("&").escape()
    hmac = createObject("roHMAC")
    keyBytes = createObject("roByteArray")
    keyBytes.fromAsciiString(m.global.apiSecret + "&" + m.tokenRequestData.lookup("oauth_token_secret"))

    messageBytes = createObject("roByteArray")
    messageBytes.fromAsciiString("GET&" + m.tokenUrl.escape() + "&" + paramString)

    print "Signing message: " + messageBytes.toAsciiString()
    hmac.setup("sha1", keyBytes)
   
    signature = hmac.process(messageBytes).toBase64String()
    kvs.push("oauth_signature=" + signature.escape())
    queryString = kvs.join("&")

    reqUrl = m.tokenUrl + "?" + queryString

    print "Token request URL: "; reqUrl
    ctx = createObject("roSGNode", "Node")
    reqParams = {
        uri: reqUrl,
        accept: "application/json"
    }

    ctx.addFields({parameters: reqParams, response: {}})
    ctx.observeField("response", "onAccessToken")
    m.global.uriFetcher.request = {context: ctx}
end function

function onErrorOk(msg as object)
    if m.top.getScene().dialog <> invalid then m.top.getScene().dialog.close = true
end function

function showErrorDialog()
    dialog = createObject("roSgNode", "Dialog")
    dialog.title = "Login Failed"
    dialog.message = "Login to SmugMug failed"
    dialog.buttons = ["OK"]
    dialog.observeField("buttonSelected", "onErrorOk")
    m.top.getScene().dialog = dialog
    return invalid
end function

function onAccessToken(msg as Object)
    code = msg.getData().code
    if code <> 200
        showErrorDialog()
    end if
    data = msg.getData().content

    print "Got access token response"; msg.getData()

    tokenData = {}
    params = data.split("&")
    for each param in params
        parts = param.split("=")
        tokenData.AddReplace(parts[0], parts[1])
    end for

    creds = {
        apiKey: m.global.apiKey,
        apiSecret: m.global.apiSecret,
        token: tokenData.oauth_token.trim(),
        tokenSecret: tokenData.oauth_token_secret.trim()
    }
    m.signer = RequestSigner(creds)
    m.global.creds = m.signer.creds
    requestAuthedUser("onGotAuthedUser")
end function

function requestAuthedUser(callBackName as String)
    ' as a test, lookup the authenticated user
    reqParams = {
        uri: m.global.apiUrl + "/api/v2!authuser?_filter=Name",
        accept: "application/json"
    }

    ctx = createObject("roSGNode", "Node")
    ctx.addFields({parameters: m.signer.sign(reqParams), response: {}})
    ctx.observeField("response", callBackName)
    m.global.uriFetcher.request = {context: ctx}
end function

function onGotAuthedUser(msg as object)
    if msg.getData().code = 401
        showErrorDialog()
    else
        js = ParseJSON(msg.getData().content)
        user = js.Response.User.Name
        m.registry.writeKeys({
            oauthToken: m.signer.creds.token,
            oauthTokenSecret: m.signer.creds.tokenSecret,
            user: user
        }, "auth")
        print "Logged in user is "; user
        m.top.selectedUser = user
    end if
end function
