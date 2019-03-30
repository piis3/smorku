' Library object for creating signed requests, either by appending the APIKey query argument, or
' by adding the authorization header to the request. The creds object should be an AA containing
' the keys apiKey and apiSecret and optionally if logged in, the keys token and tokenSecret should 
' added. 
function RequestSigner(myCreds as Object)
    _signedIn = myCreds.doesExist("tokenSecret")
    
    _signingKey = createObject("roByteArray")
    if _signedIn
        _signingKey.fromAsciiString(myCreds.apiSecret.escape() + "&" + myCreds.tokenSecret.escape())
    end if
    di = createObject("roDeviceInfo")
    signer = {
        signedIn: _signedIn,
        creds: myCreds,
        signingKey: _signingKey,
        deviceInfo: di,
        
        sign: function(ctx as object) 
            dt = createObject("roDateTime")
            if not m.signedIn
                queryStartIdx = ctx.uri.instr("?")
                if queryStartIdx < 0
                    ' we don't have a query string, so we can definitely just append the api key
                    ctx.uri = ctx.uri + "?APIKey="+m.creds.apiKey
                else if ctx.uri.instr(queryStartIdx, "APIKey=") < 0
                    ctx.uri = ctx.uri + "&APIKey="+m.creds.apiKey
                end if 

                return ctx
            end if
            
            params = {
                oauth_consumer_key: m.creds.apiKey,
                oauth_nonce: m.deviceInfo.getRandomUUID(),
                oauth_signature_method: "HMAC-SHA1",
                oauth_timestamp: dt.asSeconds().toStr(),
                oauth_version: "1.0",
                oauth_token: m.creds.token
            }

            ' the signature also needs to treat unrelated query parameters in the special sort by name and don't have a question mark mode
            ' and query parameters need to be sorted WITH the oauth header parameters in the signature string
            queryStartIdx = ctx.uri.instr("?")
            baseUrl = ""
            if queryStartIdx < 0
                baseUrl = ctx.uri
            else
                baseUrl = ctx.uri.mid(0, queryStartIdx)
                qs = ctx.uri.mid(queryStartIdx + 1)
                for each qsParam in qs.split("&")
                    pair = qsParam.split("=")
                    params[pair[0]] = pair[1]
                end for
            end if

            keys = params.keys()
            keys.sort()
            dim kvs[keys.count() -1]
            for each key in keys
                kvs.push(key + "=" + params[key])
            end for

            urlToSign = baseUrl.escape() + "&" + kvs.join("&").escape()

            hmac = createObject("roHMAC")
            messageBytes = createObject("roByteArray")
            messageBytes.fromAsciiString("GET&" + urlToSign)

            'print "Signing message: " + messageBytes.toAsciiString()
            hmac.setup("sha1", m.signingKey)

            signature = hmac.process(messageBytes).toBase64String()
            params.oauth_signature = signature

            ' Now we have to rebuild kvs because we need to format the header differently than the signature
            dim headerKvs[params.count() - 1]
            for each key in params.keys()
                if key.instr("oauth_") <> -1
                    ' 34 is the " character
                    headerKvs.push(key + "=" + chr(34) + params[key].escape() + chr(34))
                end if
            end for

            oauthParamString = headerKvs.join(",")
            ctx["Authorization"] = "OAuth " + oauthParamString
            'print "Auth header: "; ctx["Authorization"]
            return ctx
        end function
    }

    return signer
end function
