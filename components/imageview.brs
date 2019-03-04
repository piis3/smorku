function init() 
    m.imageViewer = m.top.findNode("imageViewer1")
    m.switchImageViewer = m.top.findNode("imageViewer2")
end function

function displayContent(item as object)
    idx = item.getData()

    item = m.top.contentList.getChild(idx)
    if item = invalid
        print "Invalid index "; idx
        m.imageViewer.visible = false
        m.top.setFocus(false)
    else 
        m.imageViewer.uri = item.image2kUrl
        if not m.imageViewer.visible
            m.imageViewer.visible = true
        end if
        m.top.setFocus(true)
    end if
end function

function onKeyEvent(key as String, press as boolean) as boolean
    if not press
        return false
    end if

    if m.imageViewer.visible = true
        print "key press! "; key 
        if key = "back" 
            m.imageViewer.visible = false
            m.top.setFocus(false)
            return true
        else if key = "left"
            m.top.contentIndex = m.top.contentIndex - 1
            return true
        else if key = "right"
            m.top.contentIndex = m.top.contentIndex + 1
            return true
        end if
    else
        return false
    end if      
end function
