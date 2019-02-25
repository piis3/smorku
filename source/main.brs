
sub Main()
    print "Started"

    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.setMessagePort(port)
    scene = screen.CreateScene("SmorkuScene")
    screen.show()
    scene.setFocus(true)

    while(true)
        msg = wait(0, port)
        msgType = type(msg)
        if msgType = "roSGScreenEvent"
            if msg.isScreenClosed() then 
                return
            end if
        else if msgType = "roUrlEvent"
            print "Leaked a URL event to the main thread"; msg
        end if
    end while
end sub
