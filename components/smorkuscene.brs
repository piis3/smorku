function init()
    'm.top.setFocus(true)
    print "smorkuScene.brs INIT" 
    SetConfig()
    m.top.overhang.showClock = true
    m.top.overhang.showOptions = false
    m.top.overhang.title = "Zarrf"
    m.albumPanel = m.top.FindNode("AlbumPanel")

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
    AsyncLoadAlbums("zarrf")
end function

Function SetConfig()
    m.global.addFields({
        apiUrl: "https://api.smugmug.com",
        apiKey: "smugmug api key"
    })
end Function

function panelSwitch(msg as Object) 
    print "Panel being switched "; msg.getData().id
    
    if m.top.panelSet.isGoingBack
        'm.listGrid.setFocus(true)
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
        m.albumPanel.nextPanel = m.albumImagesView
        m.albumImagesView.setFocus(true)
        m.albumImagesView.albumUri = item.albumUri
    end if
end function

Function parseLoadAlbums(json as Object) as Object
    dim albums[10]
    count = 0
    for each album in json.Response.Album
        albumData = {}
        albumData.name = album.Name
        albumData.thumbRef = album.Uris.NodeCoverImage.Uri
        albumData.albumUri = album.Uri
        albums.push(albumData)
        count = count + 1
    end for
    return albums
end Function

Function AsyncLoadAlbums(SMUser as String) as Object
    reqUrl = m.global.apiUrl + "/api/v2/user/" + SMUser + "!albums?APIKey=" + m.global.apiKey
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
    print "Entered handleLoadAlbumbs"
    mt = type(msg)
    listGrid = m.listGrid
    listContent = m.albumList
    if mt="roSGNodeEvent"
        ctx = msg.getRoSGNode()
        response = msg.getData()
        json = ParseJSON(response.content)
        albums = parseLoadAlbums(json)
        listGrid.numRows = (albums.Count() / listGrid.numColumns) + 1
        for each album in albums
            a = listContent.createChild("ContentNode")
            a.shortdescriptionline1 = album.name
            a.addFields({albumUri: album.albumUri})
            ' a.albumUri = album.albumUri
            ' fire off async request to resolve the thumbnail and attach this content node so it can be rendered
            loadAlbumThumbnail(album.thumbRef, a)
        end for
    end if
end Function

Function loadAlbumThumbnail(uri as String, contentNode as Object) 
    reqUrl = m.global.apiUrl + uri + "?APIKey=" + m.global.apiKey
    ctx = createObject("RoSGNode", "Node")
    parameters = {
        uri: reqUrl,
        accept: "application/json"
    }
    ctx.addFields({parameters: parameters, contentNode: contentNode, response: {}})
    ctx.observeField("response", "handleAlbumThumbnail")
    m.uriFetcher.request = {context: ctx}
end Function

Function handleAlbumThumbnail(msg as Object)
    print "Entered handleAlbumThumbnail"
    mt = type(msg)
    if mt = "roSGNodeEvent"
        ctx = msg.getRoSGNode()
        response = msg.getData()
        node = ctx.contentNode
        json = ParseJSON(response.content)
        relativeUri = json.Response.Image.Uris.ImageSizes.Uri
        resolveImageThumbnail(relativeUri, node)
        'node.hdgridposterurl = json.Response.Image.ThumbnailUrl
    end if
end function

Function resolveImageThumbnail(uri as String, contentNode as Object)
    reqUrl = m.global.apiUrl + uri + "?APIKey=" + m.global.apiKey
    ctx = createObject("RoSGNode", "Node")
    parameters = {
        uri: reqUrl,
        accept: "application/json"
    }
    ctx.addFields({parameters: parameters, contentNode: contentNode, response: {}})
    ctx.observeField("response", "handleResolveThumbnail")
    m.uriFetcher.request = {context: ctx}
end function

function handleResolveThumbnail(msg as Object) 
    print "Entered handleResolveThumbnail"
    mt = type(msg)
    if mt = "roSGNodeEvent"
        ctx = msg.getRoSGNode()
        response = msg.getData()
        node = ctx.contentNode
        json = ParseJSON(response.content)
        node.fhdgridposterurl = json.Response.ImageSizes.MediumImageUrl
        node.hdgridposterurl = json.Response.ImageSizes.MediumImageUrl
        node.sdgridposterurl = json.Response.ImageSizes.SmallImageUrl
    end if
end function


