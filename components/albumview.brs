function init() 
    print "Starting albumview"
    m.top.panelSize = "full"

    m.uriFetcher = m.global.uriFetcher
    m.top.isFullScreen=true
    m.top.panelSize="full"
    m.imageList = m.top.findNode("AlbumImageContent")
    m.imageGrid = m.top.findNode("ImageGrid")
    m.top.grid = m.imageGrid
    m.imageGrid.observeField("itemSelected", "handleViewImage")
end function

' Called when the image view is set on this node, we need to then set ourselves up to get notified when we stop viewing images
function setupFocusHandler(msg as object)
    msg.getData().observeField("focusedChild", "handleEndViewing")
end function

function handleEndViewing(msg as object)
    if m.top.imageView <> invalid and not m.top.imageView.isInFocusChain() 
        m.top.setFocus(true)
    end if
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
        count = 0
        for each image in json.Response.AlbumImage
            i = m.imageList.createChild("ContentNode")
            if len(image.Caption) > 0
                i.shortdescriptionline1 = image.Caption
            end if
            i.addFields({imageUri: i.Uri})
            loadAlbumImageThumbnail(image.Uris.ImageSizes.Uri, i)
            count = count + 1
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
        if json.Response.ImageSizes.lookup("4KImageUrl") <> invalid
            node.addFields({image4kUrl: json.Response.ImageSizes.lookup("4KImageUrl")})
        else
            node.addFields({image4kUrl: json.Response.ImageSizes.LargestImageUrl})
        end if

        if json.Response.ImageSizes.lookup("X3LargeImageUrl") <> invalid
            node.addFields({image2kUrl: json.Response.ImageSizes.lookup("X3LargeImageUrl")})
        else
            node.addFields({image2kUrl: json.Response.ImageSizes.LargestImageUrl})
        end if
    end if
end function

function handleViewImage(msg as object)
    'selected = m.imageGrid.content.getChild(m.imageGrid.itemSelected)
    m.top.imageView.contentList = m.imageGrid.content
    m.top.imageView.contentIndex = m.imageGrid.itemSelected
    print "Set content index to "; m.top.imageView.contentIndex

end function



' Leaving this here temporarily for when we deal with video again
function handleVideo(msg as object)
    selected = m.imageGrid.content.getChild(m.imageGrid.itemSelected)
    'm.imageView = createObject("RoSGNode", "ImageView")
    'm.top.nextPanel = m.imageView
    content = createObject("roSGNode", "ContentNode")
    http = createObject("roHttpAgent")
    m.top.videoPlayer.setHttpAgent(http)
    content.setFields({
        url: "http://192.168.7.241:8080/3R8A1320-4k.mkv",
        'url: selected.image4kUrl,
        title: "monkey",
        'description: "monkeys",
        'hdposterurl: "http://s2.content.video.llnw.net/lovs/images-prod/59021fabe3b645968e382ac726cd6c7b/media/f8de8daf2ba34aeb90edc55b2d380c3f/ZLh.540x304.jpeg",
        'streamFormat: "mkv",
    })
    'm.top.videoPlayer = m.top.findNode("videoPlayer")
    m.top.videoPlayer.content = content
    m.top.videoPlayer.visible = true
    m.top.videoPlayer.setFocus(true)
    m.top.videoPlayer.observeField("state", "videoState")
    m.top.videoPlayer.control = "play"
    'm.imageView.setFocus(true)
    print "monkey"
end function

function videoState(msg as object)
    print "state: "; m.top.videoPlayer.state
    if m.top.videoPlayer.state = "error"
        print m.top.videoPlayer.completedStreamInfo
        print m.top.videoPlayer.errorMsg; " code "; m.top.videoPlayer.errorCode; " "; m.top.videoPlayer.errorStr
        stop
    end if
end function
