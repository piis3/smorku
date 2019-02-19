function init()
    'm.top.setFocus(true)
    m.albumList = m.top.FindNode("AlbumListContent")
    m.listGrid = m.top.FindNode("AlbumList")
    uriFetcher = createObject("roSGNode", "UriFetcher")
    m.uriFetcher = uriFetcher
    SetConfig()
    AsyncLoadAlbums("zarrf")
end function

Function SetConfig()
    m.apiUrl = "https://api.smugmug.com"
    m.apiKey = "smugmug api key"
end Function

Function parseLoadAlbums(json as Object) as Object
    dim albums[10]
    count = 0
    for each album in json.Response.Album
        albumData = {}
        albumData.name = album.Name
        albumData.thumbRef = album.Uris.NodeCoverImage.Uri
        albums.push(albumData)
        count = count + 1
    end for
    return albums
end Function

Function AsyncLoadAlbums(SMUser as String) as Object
    reqUrl = m.apiUrl + "/api/v2/user/" + SMUser + "!albums?APIKey=" + m.apiKey
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
            ' fire off async request to resolve the thumbnail and attach this content node so it can be rendered
            loadAlbumThumbnail(album.thumbRef, a)
        end for
    end if
end Function

Function loadAlbumThumbnail(uri as String, contentNode as Object) 
    reqUrl = m.apiUrl + uri + "?APIKey=" + m.apiKey
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
    reqUrl = m.apiUrl + uri + "?APIKey=" + m.apiKey
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


