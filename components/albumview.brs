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
    m.signer = RequestSigner(m.global.creds)
    actualLoadAlbumImages()
end function

function actualLoadAlbumImages(start = 1 as Integer) 
    requestConfigJson = FormatJson({
        filter: ["Uri", "Caption", "FileName"],
        filteruri: ["ImageSizes"],
        expand: {
            "ImageSizes": {
                filter: [], 
                filteruri: ["ImageSizeCustom"],
                expand: {
                    "ImageSizeCustom": {
                        multiargs: [
                            { 
                                width: m.imageGrid.basePosterSize[0],
                                height: m.imageGrid.basePosterSize[1]
                            },
                            {
                                width: 1920,
                                height: 1080
                            }
                        ],
                        filter: ["Url", "RequestedHeight", "RequestedWidth"]
                    }
                }
            }
        }
    }).escape()

    reqUrl = m.global.apiUrl + m.top.albumUri + "!images?_config=" + requestConfigJson + "&start=" + start.toStr()
    ctx = createObject("RoSGNode", "Node")
    parameters = {
        uri: reqUrl,
        accept: "application/json"
    }
    ctx.addFields({parameters: m.signer.sign(parameters), response: {}})
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
        imageCount = json.Response.Pages.Total
        m.imageGrid.numRows = (imageCount / m.imageGrid.numColumns) + 1
        count = 0
        for each image in json.Response.AlbumImage
            i = m.imageList.createChild("ContentNode")
            if len(image.Caption) > 0
                i.shortdescriptionline1 = image.Caption
            end if
            i.addFields({imageUri: i.Uri})
            sizesRef = json.Expansions.lookup(image.Uris.ImageSizes.Uri)
            customSizesRef = json.Expansions.lookup(sizesRef.ImageSizes.Uris.ImageSizeCustom.Uri)
            for each imageSize in customSizesRef.ImageSizeCustom
                if imageSize.RequestedWidth = 1920
                    i.addFields({image2kUrl: imageSize.Url})
                else if imageSize.RequestedWidth = m.imageGrid.basePosterSize[0]
                    i.fhdgridposterurl = imageSize.Url
                end if
            end for
            count = count + 1
        end for
        if json.Response.Pages.NextPage <> invalid
            newStart = json.Response.Pages.Start + json.Response.Pages.Count
            print "Requesting page starting at "; newStart
            actualLoadAlbumImages(newStart)
        end if
    end if
    m.imageGrid.setFocus(true)
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
