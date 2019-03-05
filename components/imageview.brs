function init() 
    m.loadingPoster = m.top.findNode("loadingPoster")

    m.imageViewer = m.top.findNode("imageViewer1")
    m.switchImageViewer = m.top.findNode("imageViewer2")
    m.cachingPoster = m.top.findNode("cachingPoster")

    m.imageViewer.observeField("loadStatus", "onImageLoaded")
    m.switchImageViewer.observeField("loadStatus", "onImageLoaded")
    m.cachingPoster.observeField("loadStatus", "onImageLoaded")

end function

' We're doing async image loading and trying to do the loading behind the scenes, when the image is loaded
' show the switch viewer, hide the loading poster and the old viewer
' then swap the references
function onImageLoaded(msg as object)
    if msg.getNode() <> m.cachingPoster.id
        if msg.getData() = "ready" 
            switchViewers()
        else if msg.getData() = "loading" 
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
end function

function close()
    m.currentUri = invalid
    m.imageViewer.visible = false
    m.switchImageViewer.visible = false
    m.loadingPoster.visible = false
    m.top.setFocus(false)
end function

function displayContent(item as object)
    idx = item.getData()

    item = m.top.contentList.getChild(idx)
    if item = invalid
        print "Invalid index "; idx
        close()
    else 
        ' The alternate viewer might already have the image we want, in which case we just swap them
        if m.switchImageViewer.uri = item.image2kUrl
            print "Alternate poster already has url"
            switchViewers()
        else if m.cachingPoster.uri = item.image2kUrl
            print "Swapping in cached poster for image"
            tmp = m.cachingPoster
            m.cachingPoster = m.switchImageViewer
            m.switchImageViewer = tmp
            switchViewers()
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
            close()
            m.top.setFocus(false)
            return true
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
        end if
    else
        return false
    end if      
end function
