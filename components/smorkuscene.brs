function init()
    'm.top.setFocus(true)
    print "smorkuScene.brs INIT" 
    SetConfig()
    m.overhang = m.top.findNode("overhang")
    m.overhang.color = "0x111111ff"
    m.overhang.showClock = true
    m.overhang.showOptions = false
    m.overhang.logoUri = "pkg:/images/panel-logo.png"
    m.albumPanel = m.top.FindNode("AlbumPanel")
    m.imageView = createObject("roSGNode", "ImageView")
    m.videoPlayer = m.imageView.FindNode("videoPlayer")
    m.imageViewer = m.imageView.FindNode("imageViewer")

    m.top.appendChild(m.imageView)

    m.top.panelSet.appendChild(m.albumPanel)
    m.albumList = m.top.FindNode("AlbumListContent")
    m.listGrid = m.top.FindNode("AlbumList")
    m.albumPanel.grid = m.listGrid

    uriFetcher = createObject("roSGNode", "UriFetcher")
    m.uriFetcher = uriFetcher
    m.global.addFields({uriFetcher: uriFetcher})

    m.top.panelSet.observeField("focusedChild", "panelSwitch")
    
    m.listGrid.setFocus(true)

    m.listGrid.observeField("itemSelected", "selectAlbum")
    m.loadedUser = "zarrf"
    m.overhang.title = m.loadedUser
    AsyncLoadAlbums(m.loadedUser)
end function

Function SetConfig()
    m.global.addFields({
        apiUrl: "https://api.smugmug.com",
        apiKey: "smugmug api key"
    })
end Function

function panelSwitch(msg as Object) 
    'print "Panel being switched "; msg.getData().id
    
    if m.top.panelSet.isGoingBack
        'm.listGrid.setFocus(true)
        m.overhang.title = m.loadedUser
    end if
end function

Function selectAlbum(msg as object) 
    item = m.listGrid.content.getChild(m.listGrid.itemSelected)
    print "Selected item: " + item.albumUri
    if m.albumImagesView <> invalid and m.albumImagesView.albumUri = item.albumUri
        ' If we're returning to the same album, we shouldn't reload it because the event deduping will 
        ' break the event handling
        m.albumImagesView.setFocus(true)
    else 
        m.albumImagesView = createObject("RoSGNode", "AlbumImagesView")
        m.overhang.title = item.name

        m.albumPanel.nextPanel = m.albumImagesView
        m.albumImagesView.videoPlayer = m.videoPlayer
        m.albumImagesView.imageView = m.imageView
        m.albumImagesView.setFocus(true)
        m.albumImagesView.albumUri = item.albumUri
    end if
end function

Function AsyncLoadAlbums(SMUser as String, start = 1 as Integer) as Object
    ' This is a little json based filter language for smugmug which lets us only retrieve those fields we care about 
    ' and also chain a bunch of sub requests together so we do not need so many round trips.
    requestConfigJson = FormatJson({
        filter: ["Name", "Uri", "HighlightImage.Uri", "ImageCount"],
        filteruri: ["HighlightImage"],
        expand: {
            "HighlightImage": {
                filter: [], 
                filteruri: ["ImageSizes"],
                expand: {
                    "ImageSizes": {
                        filter: [], 
                        filteruri: ["ImageSizeCustom"],
                        expand: {
                            "ImageSizeCustom": {
                                args: {
                                    width: m.listGrid.basePosterSize[0],
                                    height: m.listGrid.basePosterSize[1]
                                },
                                filter: ["Url"]
                            }
                        }
                    }
                }
            }
        }
    }).escape()

    reqUrl = m.global.apiUrl + "/api/v2/user/" + SMUser + "!albums?APIKey=" + m.global.apiKey + "&_config=" + requestConfigJson + "&start=" + start.toStr()
    ctx = createObject("RoSGNode", "Node")
    parameters = {
        uri: reqUrl,
        accept: "application/json"
    }
    ctx.addFields({parameters: parameters, response: {}})
    ctx.observeField("response", "handleLoadAlbums")
    m.uriFetcher.request = {context: ctx}
end Function

Function handleLoadAlbums(msg as Object)
    print "Entered handleLoadAlbums"
    mt = type(msg)
    listGrid = m.listGrid
    listContent = m.albumList
    if mt="roSGNodeEvent"
        ctx = msg.getRoSGNode()
        response = msg.getData()
        json = ParseJSON(response.content)
        albums = parseLoadAlbums(json)
        loadedImagesCount = albums.Count() + listContent.getChildCount()
        listGrid.numRows = (loadedImagesCount / listGrid.numColumns) + 1
        for each album in albums
            a = listContent.createChild("ContentNode")
            a.shortdescriptionline1 = album.name
            a.addFields({
                albumUri: album.albumUri, 
                name: album.name,
            })
            a.fhdgridposterurl = album.thumbnailUrl
            a.hdgridposterurl = album.thumbnailUrl
        end for
        if json.Response.Pages.NextPage <> invalid
            newStart = json.Response.Pages.Start + json.Response.Pages.Count
            AsyncLoadAlbums(m.loadedUser, newStart)
        end if
    end if
end Function

Function parseLoadAlbums(json as Object) as Object
    dim albums[10]
    count = 0
    for each album in json.Response.Album
        if album.ImageCount <> invalid and album.ImageCount > 0
            ' TODO Remove, just limit the noise during debugging
            albumData = {}
            albumData.name = album.Name
            albumData.albumUri = album.Uri
            thumbRef = json.Expansions.lookup(album.Uris.HighlightImage.Uri)
            sizesRef = json.Expansions.lookup(thumbRef.Image.Uris.ImageSizes.Uri)
            customSizeRef = json.Expansions.lookup(sizesRef.ImageSizes.Uris.ImageSizeCustom.Uri)

            albumData.thumbnailUrl = customSizeRef.ImageSizeCustom.Url
            albums.push(albumData)
            count = count + 1
        end if
    end for
    return albums
end Function

