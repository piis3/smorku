function init()
	m.port = createObject("roMessagePort")
	m.top.observeField("request", m.port)
	m.top.functionName = "go"
	m.top.control = "RUN"
    m.urlTransferPool = [
                          createObject( "roUrlTransfer" )
                          createObject( "roUrlTransfer" )
                          createObject( "roUrlTransfer" )
                          createObject( "roUrlTransfer" )
                          createObject( "roUrlTransfer" )
                          createObject( "roUrlTransfer" )
                          createObject( "roUrlTransfer" )
                          createObject( "roUrlTransfer" )
                          createObject( "roUrlTransfer" )
                          createObject( "roUrlTransfer" )
                        ]
    m.workQueue = []
    ' Use a standard SSL trust store
    for each xfer in m.urlTransferPool
        xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
        xfer.SetMessagePort(m.port)
    end for
    m.ret = true
end function

function go() as Void
	m.jobsById = {}
	m.top.setField("urlTransferPoolField", m.urlTransferPool.count())
	while true
		msg = wait(0, m.port)
		mt = type(msg)
		if mt="roSGNodeEvent"
			if msg.getField()="request"
				m.ret = addRequest(msg.getData())
                if not m.ret
                    m.workQueue.push(msg)
                end if
			else
				print "UriFetcher: unrecognized field '"; msg.getField(); "'"
			end if
		else if mt="roUrlEvent"
			processResponse(msg)
            oldWork = m.workQueue.shift()
            if oldWork<>invalid
                if type(oldWork) = "roSGNodeEvent"
                    m.ret = addRequest(oldWork.getData())
                    if not m.ret
                        m.workQueue.push(oldWork)
                    end if
                else 
                    print "ERROR: What is this: " + type(oldWork)
                end if
            end if
		else
			print "UriFetcher: unrecognized event type '"; mt; "'"
		end if
        if m.ret = false
            ? "too many requests"
        end if
	end while
end function

function addRequest(request as Object) as Boolean
	if type(request) = "roAssociativeArray"
        context = request.context
        if type(context)="roSGNode"
            parameters = context.parameters
            if type(parameters)="roAssociativeArray"
		        uri = parameters.uri
		        if type(uri) = "roString"
                    xfer = m.urlTransferPool.Pop()
                    if xfer = invalid
                        ? "Pool empty, queuing"
                        return false
                    else 
                        xfer.setUrl(uri)
                        xfer.setPort(m.port)
                        ' I know we need to set the accept header, so we'll start with that.
                        if type(parameters.accept) = "roString"
                            xfer.AddHeader("Accept", parameters.accept)
                        end if

                        ' should transfer more stuff from parameters to urlXfer
                        idKey = stri(xfer.getIdentity()).trim()

                        m.jobsById[idKey] = {context: context, xfer: xfer}
                       '  print "UriFetcher: initiating transfer '"; idkey; "' for URI '"; uri; "'";
                        m.top.setField("JobsByIdField", m.jobsById.count())
                        
                        ok = xfer.AsyncGetToString()
                        if not ok
                            print "ERROR: Unable to use supposedly free xfer in pool " stri(xfer.getIdentity()).trim()
                            return false
                        end if
                    end if
		        end if
            end if
	    end if
	end if
    return true
end function

function processResponse(msg as Object)
	idKey = stri(msg.GetSourceIdentity()).trim()
	job = m.jobsById[idKey]

    ' print "Work queue size: "; m.workQueue.count()
    ' print "Number of jobs in flight: "; m.jobsById.count()
    ' print "Number of urlXfer objects in pool: " m.urlTransferPool.count()

    if job<>invalid
        m.ret = true
        context = job.context
        xfer = job.xfer
        parameters = context.parameters
        uri = parameters.uri
		' print "UriFetcher: response for transfer "; idkey; " status:"; msg.getResponseCode(); " for URI "; uri
'        if instr(1, uri, "!images")
'            stop
'        end if
		result = {code: msg.getResponseCode(), content: msg.getString()}

		' could handle various error codes, retry, etc.
		m.jobsById.delete(idKey)
		m.top.setField("JobsByIdField", m.jobsById.count())
        job.context.response = result
        m.urlTransferPool.push(xfer)
	else
		print "UriFetcher: event for unknown job "; idkey
	end if
end function
