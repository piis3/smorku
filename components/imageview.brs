function init() 
    m.loadingPoster = m.top.findNode("loadingPoster")

    m.imageViewer = m.top.findNode("imageViewer1")
    m.switchImageViewer = m.top.findNode("imageViewer2")
    m.cachingPoster = m.top.findNode("cachingPoster")

    m.imageViewer.observeField("loadStatus", "onImageLoaded")
    m.switchImageViewer.observeField("loadStatus", "onImageLoaded")
    m.cachingPoster.observeField("loadStatus", "onImageLoaded")

    m.videoIndicator = m.top.findNode("videoIndicator")
    m.videoPlayer = m.top.findNode("videoPlayer")
    m.videoPlayer.observeField("state", "videoState")

end function

' We're doing async image loading and trying to do the loading behind the scenes, when the image is loaded
' show the switch viewer, hide the loading poster and the old viewer
' then swap the references
function onImageLoaded(msg as object)
    if msg.getNode() <> m.cachingPoster.id
        if msg.getData() = "ready" 
            switchViewers()
        else if msg.getData() = "loading" and msg.getNode() = m.switchImageViewer.id
            m.loadingPoster.visible = true
        end if
    end if
end function

function switchViewers()
        current = m.imageViewer
        m.loadingPoster.visible = false   
        current.visible = false
        m.switchImageViewer.visible = true
        m.imageViewer = m.switchImageViewer
        m.switchImageViewer = current

        item = m.top.contentList.getChild(m.top.contentIndex)
        if item <> invalid and item.IsVideo
            m.videoIndicator.visible = true
        end if
end function

function videoState(msg as object)
    state = msg.getData()
    if state = "finished" or state = "stopped"
        m.videoPlayer.visible = false
        m.top.setFocus(true)
    else if state = "error"
        print "Got video error"
        m.top.setFocus(true)
        m.videoPlayer.visible = false
    end if
end function

function close()
    m.currentUri = invalid
    m.imageViewer.visible = false
    m.switchImageViewer.visible = false
    m.loadingPoster.visible = false
    m.top.setFocus(false)
    m.videoIndicator.visible = false
end function

function playVideo()
        item = m.top.contentList.getChild(m.top.contentIndex)
        if item <> invalid and item.IsVideo
            print "Ok we can play video at "; item.videoUrl
            content = createObject("roSGNode", "ContentNode")
            content.setFields({
                url: item.videoUrl,
                hdposterurl: item.image2kurl,
                title: item.shortdescriptionline1
            })
            m.videoPlayer.content = content
            m.videoPlayer.visible = true
            m.videoPlayer.control = "play"
        else 
            print "Nope, can't play this"
        end if
end function    

function displayContent(item as object)
    idx = item.getData()

    item = m.top.contentList.getChild(idx)
    if item = invalid
        ' print "Invalid index "; idx
        close()
    else 
        m.videoIndicator.visible = false
        ' The alternate viewer might already have the image we want, in which case we just swap them
        if m.switchImageViewer.uri = item.image2kUrl
            ' print "Alternate poster already has url"
            switchViewers()
        else if m.cachingPoster.uri = item.image2kUrl
            ' print "Swapping in cached poster for image"
            tmp = m.cachingPoster
            m.cachingPoster = m.switchImageViewer
            m.switchImageViewer = tmp
            if m.switchImageViewer.loadStatus <> "ready"
                m.loadingPoster.visible = true
            else 
                switchViewers()
            end if
        else     
            m.switchImageViewer.uri = item.image2kUrl
        end if
        m.top.setFocus(true)
    end if
end function

function cacheIndex(idx as Integer)
    item = m.top.contentList.getChild(idx)
    if item <> invalid
        m.cachingPoster.uri = item.image2kUrl
    end if
end function

function onKeyEvent(key as String, press as boolean) as boolean
    if not press
        return false
    end if

    if m.imageViewer.visible = true
        print "key press! "; key 
        if key = "back" 
            if m.videoPlayer.visible = true
                m.videoPlayer.control = "stop"
                return true
            else 
                close()
                m.top.setFocus(false)
                return true
            end if
        else if key = "left"
            m.top.contentIndex = m.top.contentIndex - 1
            ' already decremented, now cache one more down
            cacheIndex(m.top.contentIndex - 1)
            return true
        else if key = "right"
            m.top.contentIndex = m.top.contentIndex + 1
            ' already incremented, now cache one more up
            cacheIndex(m.top.contentIndex + 1)
            return true
        else if key = "OK"
            playVideo()
            return true
        end if
    else
        return false
    end if      
end function
