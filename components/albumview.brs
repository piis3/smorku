function init() 
    print "Starting albumview"
    m.top.panelSize = "full"

    m.uriFetcher = m.global.uriFetcher
    m.top.isFullScreen=true
    m.top.panelSize="full"
    m.imageList = m.top.findNode("AlbumImageContent")
    m.imageGrid = m.top.findNode("ImageGrid")
    m.top.grid = m.imageGrid
    m.top.createNextPanelOnItemFocus = false 
end function

function loadAlbumImages(msg as object) 
    reqUrl = m.global.apiUrl + m.top.albumUri + "!images?APIKey=" + m.global.apiKey
    ctx = createObject("RoSGNode", "Node")
    parameters = {
        uri: reqUrl,
        accept: "application/json"
    }
    ctx.addFields({parameters: parameters, response: {}})
    ctx.observeField("response", "handleImages")
    m.uriFetcher.request = {context: ctx}
end function

function handleImages(msg as object)
    print "Entered handleAlbumImages"
    mt = type(msg)
    if mt = "roSGNodeEvent"
        ctx = msg.getRoSGNode()
        response = msg.getData()
        json = ParseJSON(response.content)
        imageCount = json.Response.AlbumImage.Count()
        m.imageGrid.numRows = (imageCount / m.imageGrid.numColumns) + 1
        for each image in json.Response.AlbumImage
            i = m.imageList.createChild("ContentNode")
            if len(image.Caption) > 0
                i.shortdescriptionline1 = image.Caption
            end if
            i.addFields({imageUri: i.Uri})
            loadAlbumImageThumbnail(image.Uris.ImageSizes.Uri, i)
        end for
    end if
    m.imageGrid.setFocus(true)
end function

function loadAlbumImageThumbnail(sizesUri as String, i as object)
    reqUrl = m.global.apiUrl + sizesUri + "?APIKey=" + m.global.apiKey
    ctx = createObject("RoSGNode", "Node")
    parameters = {
        uri: reqUrl,
        accept: "application/json"
    }
    ctx.addFields({parameters: parameters, contentNode: i, response: {}})
    ctx.observeField("response", "handleAlbumImageThumbnail")
    m.uriFetcher.request = {context: ctx}
end function

function handleAlbumImageThumbnail(msg as object)
    print "Entered handleAlbumImageThumbnail"
    mt = type(msg)
    if mt = "roSGNodeEvent"
        ctx = msg.getRoSGNode()
        response = msg.getData()
        json = ParseJSON(response.content)
        node = ctx.contentNode
        node.fhdgridposterurl = json.Response.ImageSizes.MediumImageUrl
    end if
end function
