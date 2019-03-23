'
'   array.brs
'
'
function ArrayUtil() as Object

    util = {
        contains: function(arr as Object, element as Dynamic) as Boolean
            return m.indexOf(arr, element) >= 0
        end function

        indexOf: function(arr as Object, element as Dynamic) as Integer
            if not m._isArray(arr) then return -1

            size = arr.count()

            if size = 0 then return -1

            for i = 0 to size - 1
                if arr[i] = element then return i
            end for

            return -1
        end function

        lastIndexOf: function(arr as Object, element as Dynamic) as Integer
            if not m._isArray(arr) then return -1

            size = arr.count()

            if size = 0 then return -1

            for i = size - 1 to 0 step -1
                if arr[i] = element then return i
            end for

            return -1
        end function

        slice: function(arr as Object, fromIndex as Integer, toIndex as Integer)
            if not m._isArray(arr) then return invalid

            size = arr.count()
            slicedArr = []
            
            if fromIndex < 0 then fromIndex = 0
            if toIndex >= size then toIndex = size - 1

            if fromIndex >= size OR fromIndex > toIndex then return slicedArr

            for i=fromIndex to toIndex
                slicedArr.push(arr[i])
            end for

            return slicedArr
        end function

        map: function(arr as Object, func as Function)
            if not m._isArray(arr) then return invalid

            size = arr.count()
            mappedArr = []

            if size = 0 then return mappedArr

            for i = 0 to size - 1
                mappedArr.push(func(arr[i], i, arr))
            end for

            return mappedArr
        end function

        filter: function(arr as Object, func as Function)
            if not m._isArray(arr) then return invalid

            size = arr.count()
            filtered = []

            if size = 0 then return filtered

            for i = 0 to size - 1
                if func(arr[i], i, arr) then filtered.push(arr[i])
            end for

            return filtered
        end function

        reduce: function(arr as Object, func as Function, initialValue=invalid as Dynamic)
            if not m._isArray(arr) then return invalid

            size = arr.count()
            startAt = 0
            accumulator = initialValue

            if size = 0 then return accumulator

            if accumulator = invalid then 
                accumulator = arr[0]
                startAt = 1
            end if

            for i = startAt to size - 1
                accumulator = func(accumulator, arr[i], i, arr)
            end for
            
            return accumulator
        end function

        zip: function(arr1 as Object, arr2 as Object)
            len1 = arr1.count()
            len2 = arr2.count()
            len = 0
            if len1 > len2
                len = len2
            else
                len = len1
            end if

            dim out[len - 1]
            for i = 0 to len - 1
                out[i] = [arr1[i], arr2[i]]
            end for
            return out
        end function

        _isArray: function(arr)
            return type(arr) = "roArray"
        end function

        fill: function(arr as Object, value as Dynamic, count as integer)
            for i = 0 to count - 1
                arr[i] = value
            end for
            return arr
        end function
    }

    return util

end function
