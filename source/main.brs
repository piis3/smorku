
sub Main()
    print "Started"

    SetConfig()

    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)

    scene = screen.CreateScene("SmorkuScene")
    screen.show()

    listGrid = scene.findNode("AlbumList")
    listContent = scene.findNode("AlbumListContent")
    albums = LoadAlbums("zarrf")
    listGrid.numRows = (albums.Count() / listGrid.numColumns) + 1
    print albums
    for each album in albums
        a = listContent.createChild("ContentNode")
        a.shortdescriptionline1 = album.name
        a.hdgridposterurl = album.thumbRef
        print "Added album " + album.name
    end for
    listContent.setFocus(true)

    while(true)
        msg = wait(0, m.port)
        msgType = type(msg)
        if msgType = "roSGScreenEvent"
            if msg.isScreenClosed() then 
                return
            end if
        else if msgType = "roUrlEvent"
            print "Got response"
            print msg.GetResponseHeaders()
        end if
    end while
end sub

Function SetConfig()
    m.apiUrl = "https://api.smugmug.com"
    m.apiKey = "smugmug api key"
end Function

Function AlbumThumb(APIUri as String) as String
    url = createObject("roUrlTransfer")
    url.SetCertificatesFile("common:/certs/ca-bundle.crt")
    url.AddHeader("Accept", "application/json")
    reqUrl = m.apiUrl + APIUri + "?APIKey=" + m.apiKey

    url.SetUrl(reqUrl)
    data = url.GetToString()
    json = ParseJSON(data)
    return json.Response.Image.ThumbnailUrl
end Function

Function LoadAlbums(SMUser as String) as object
    url = createObject("roUrlTransfer")
    url.SetCertificatesFile("common:/certs/ca-bundle.crt")
    url.AddHeader("Accept", "application/json")
    reqUrl = m.apiUrl + "/api/v2/user/" + SMUser + "!albums" + "?APIKey=" + m.apiKey
    print "Fetching URL: " + reqUrl
    url.SetUrl(reqUrl)
    data = url.GetToString()
    m.json = ParseJSON(data)
    dim albums[10]
    for each album in m.json.Response.Album
         albumData = {}
         albumData.name = album.Name
         albumData.thumbRef = AlbumThumb(album.Uris.NodeCoverImage.Uri)
         albums.Push(albumData)
    end for
    return albums
End Function
