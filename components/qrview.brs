function init() 

    m.math = MathUtil()
    m.string = StringUtil()
    m.arrays = ArrayUtil()
    m.rspoly = rsPoly()

    m.constants = constants()
    m.top.visible = false

    m.errorCorrection = 0
    m.mode = m.constants.MODE_BYTES
end function

function renderQR(text as String)
    m.text = text
    m.top.txt = text
    m.version = findBestFit()
    print "Best fitting version is "; m.version
    m.modulesCount = m.version * 4 + 17
    dim modules [m.modulesCount - 1, m.modulesCount - 1]
    m.modules = modules
    m.mSize = 2
    m.outlineOffset = [16, 16]
    m.top.width = m.mSize * (m.modulesCount + 4) + m.outlineOffset[0]
    m.top.height = m.mSize * (m.modulesCount + 4) + m.outlineOffset[1]

    m.baseOffset = [m.outlineOffset[0] + m.mSize * 2, m.outlineOffset[1] + m.mSize * 2]

    
    ' There are four levels of error correction possible

    ' We should actually check a series of 8 mask values to see which produces the "best" code
    ' for now, let's just start with one
    m.maskPattern = 7

    initModules()

    drawProbe(0, 0)
    drawProbe(0, m.modulesCount - 7)
    drawProbe(m.modulesCount - 7, 0)
    drawPositionAdjust()
    drawTiming()
    drawTypeInfo()
    if m.version >= 7
        drawTypeNumber()
    end if

    data = calculateData()
    drawData(data, m.maskPattern)
    m.top.renderComplete = true
end function

function printRawModules()
    for r = 0 to m.modulesCount - 1
        row = ""
        for c = 0 to m.modulesCount -1
            rect = m.modules[c, r]
            if not rect.hasBeenSet
                row += "_ "
            else if rect.color = 255
                row += "1 "
            else 
                row += "0 "
            end if
        end for
        print row
    end for
end function

function constants() 
    consts = {
        MODE_NUMBER: 1 << 0,
        MODE_ALPHANUM: 1 << 1,
        MODE_BYTES: 1 << 2,
        ALPHANUM_LOOKUP: "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:",
        BIT_LIMIT_TABLE: [[0, 128, 224, 352, 512, 688, 864, 992, 1232, 1456, 1728, 2032, 2320, 2672, 2920, 3320, 3624, 4056, 4504, 5016, 5352, 5712, 6256, 6880, 7312, 8000, 8496, 9024, 9544, 10136, 10984, 11640, 12328, 13048, 13800, 14496, 15312, 15936, 16816, 17728, 18672], [0, 152, 272, 440, 640, 864, 1088, 1248, 1552, 1856, 2192, 2592, 2960, 3424, 3688, 4184, 4712, 5176, 5768, 6360, 6888, 7456, 8048, 8752, 9392, 10208, 10960, 11744, 12248, 13048, 13880, 14744, 15640, 16568, 17528, 18448, 19472, 20528, 21616, 22496, 23648], [0, 72, 128, 208, 288, 368, 480, 528, 688, 800, 976, 1120, 1264, 1440, 1576, 1784, 2024, 2264, 2504, 2728, 3080, 3248, 3536, 3712, 4112, 4304, 4768, 5024, 5288, 5608, 5960, 6344, 6760, 7208, 7688, 7888, 8432, 8768, 9136, 9776, 10208], [0, 104, 176, 272, 384, 496, 608, 704, 880, 1056, 1232, 1440, 1648, 1952, 2088, 2360, 2600, 2936, 3176, 3560, 3880, 4096, 4544, 4912, 5312, 5744, 6032, 6464, 6968, 7288, 7880, 8264, 8920, 9368, 9848, 10288, 10832, 11408, 12016, 12656, 13328]],
        PATTERN_POSITION_TABLE: ParseJSON(ReadAsciiFile("pkg:/json/patternPositionTable.json")),
    }

    ' There's a giant array in rsBlockTable.json to add here as well
    blockTable = ParseJSON(ReadAsciiFile("pkg:/json/rsBlockTable.json"))
    consts.RS_BLOCK_TABLE = blockTable

    dim expTable[255]
    for i = 0 to 255
        expTable[i] = i
    end for

    for i = 0 to 7
        expTable[i] = 1 << i
    end for

    for i = 8 to 255
        expTable[i] = m.math.xor(m.math.xor(m.math.xor(expTable[i - 4], expTable[i - 5]), expTable[i - 6]), expTable[i - 8])
    end for
    
    consts.EXP_TABLE = expTable
    return consts
end function

function findBestFit(startVersion = 1)
    modeSize = modeSizesForVersion(startVersion)
    buffer = createObject("roByteArray")
    bitIndex = 0
    bitIndex = putNum(buffer, modeSize, 4, bitIndex)
    bitIndex = putNum(buffer, m.text.len(), modeSize, bitIndex)
    bitIndex = putText(buffer, m.text, bitIndex, m.constants.MODE_BYTES)

    table = m.constants.BIT_LIMIT_TABLE[m.errorCorrection]
    foundSize = -1
    i = 0
    for each size in table
        if size >= bitIndex
            foundSize = i
            exit for
        else
            i += 1
        end if
    end for

    if foundSize < 0
        print "Unable to fit data in a QR code version"
    end if
    ' If the mode sizes for the found version aren't the same as we used in our estimation, then we may need a different version
    if modeSize <> modeSizesForVersion(foundSize)
        return findBestFit(foundSize)
    else
        return foundSize
    end if
end function

function rsBlockOffset()
    if m.errorCorrection = 0
        return 1
    else if m.errorCorrection = 1
        return 0
    else if m.errorCorrection = 2
        return 3
    else if m.errorCorrection = 3
        return 2
    end if
end function

function rsBlocks()
    offset = rsBlockOffset()
    rsBlock = m.constants.RS_BLOCK_TABLE[(m.version - 1) * 4 + offset]
    blocks = []
    for i = 0 to rsBlock.Count() - 1 step 3
        count = rsBlock[i]
        totalCount = rsBlock[i + 1]
        dataCount = rsBlock[i + 2]
        for j = 0 to count -1
            blocks.push({totalCount: totalCount, dataCount: dataCount})
        end for
    end for
    return blocks
end function

function modeSizesForVersion(version as Integer) 
    if version < 10
        if m.mode = m.constants.MODE_ALPHANUM
            return 10
        else if m.mode = m.constants.MODE_NUMBER
            return 9
        else if m.mode = m.constants.MODE_BYTES
            return 8
        else
            print "Mode size not found for version"
        end if
    else if version < 27
        if m.mode = m.constants.MODE_ALPHANUM
            return 11
        else if m.mode = m.constants.MODE_NUMBER
            return 12
        else if m.mode = m.constants.MODE_BYTES
            return 16
        end if
    else
        if m.mode = m.constants.MODE_ALPHANUM
            return 13
        else if m.mode = m.constants.MODE_NUMBER
            return 14
        else if m.mode = m.constants.MODE_BYTES
            return 16
        end if
    end if
end function

function initModules() 

    m.outlineRect = createObject("roSgNode", "Rectangle")
    m.top.appendChild(m.outlineRect)
    m.outlineRect.color = "0xFFFFFFFF"
    m.outlineRect.width = m.mSize * (m.modulesCount + 4)
    m.outlineRect.height = m.mSize * (m.modulesCount + 4)
    m.inheritParentTransform = true
    m.outlineRect.translation = m.outlineOffset
    xOffset = m.baseOffset[0]
    yOffset = m.baseOffset[1]

    for x = 0 to m.modulesCount - 1
        for y = 0 to m.modulesCount - 1
            rect = createObject("roSgNode", "Rectangle")
            m.top.appendChild(rect)
            rect.inheritParentTransform = true
            rect.color = "0xFFFFFFFF"
            rect.width = m.mSize
            rect.height = m.mSize
            rect.translation = [xOffset, yOffset]
            rect.addFields({hasBeenSet: False})
            m.modules[x, y] = rect
            yOffset += m.mSize
        end for
        yOffset = m.baseOffSet[1]
        xOffset += m.mSize
    end for
end function

function setModule(val as boolean, xPos as integer, yPos as integer)
    if val
        m.modules[xPos, yPos].color = "0x000000FF"
    else
        m.modules[xPos, yPos].color = "0xFFFFFFFF"
    end if
    m.modules[xPos, yPos].hasBeenSet = True
end function

function drawProbe(xPos as Integer, yPos as Integer)
    for r = -1 to 7
        if not (yPos + r <= -1 or m.modulesCount <= yPos + r)
            for c = -1 to 7
                if not (xPos + c <= -1 or m.modulesCount <= xPos + c)
                    if (not (not ((0 <= r and r <= 6) and (c = 0 or c = 6)) and not ((0 <= c and c <= 6) and (r = 0 or r =6))) or ((2 <= r and r <= 4) and (2 <= c and c <= 4)))
                        setModule(True, c + xPos, r + yPos)
                    else
                        setModule(False, c + xPos, r + yPos)
                    end if
                end if
            end for
        end if
    end for
end function

function drawTiming()
    for r = 8 to m.modulesCount - 8
        if not m.modules[6, r].hasBeenSet
            setModule(r MOD 2 = 0, 6, r)
        end if
    end for
    for c = 8 to m.modulesCount - 8
        if not m.modules[c, 6].hasBeenSet
            setModule(c MOD 2 = 0, c, 6)
        end if
    end for
end function

function drawPositionAdjust()
    p = m.constants.PATTERN_POSITION_TABLE[m.version - 1]

    if p.count() = 0
        return invalid
    end if
    for i = 0 to p.count() - 1
        for j = 0 to p.count() - 1
            row = p[i]
            col = p[j]
            if not m.modules[col, row].hasBeenSet
                for r = -2 to 2
                    for c = -2 to 2
                        if (r = -2 or r = 2 or c = -2 or c = 2 or (r = 0 and c = 0))
                            setModule(True, col + c, row + r)
                        else
                            setModule(False, col + c, row + r)
                        end if
                    end for
                end for
            end if
        end for
    end for 
end function

function drawTypeInfo()
    data = (m.errorCorrection << 3) or m.maskPattern
    bits = m.rspoly.BCH_typeInfo(data)

    for i = 0 to 14
        mod = ((bits >> i) and 1) = 1

        if i < 6
            setModule(mod, 8, i)
        else if i < 8
            setModule(mod, 8, i + 1)
        else
            setModule(mod, 8, m.modulesCount - 15 + i)
        end if
    end for

    for i = 0 to 14
        mod = ((bits >> i) and 1) = 1
        
        if i < 8
            setModule(mod, m.modulesCount - i - 1, 8)
        else if i < 9
            setModule(mod, 15 -i - 1 + 1, 8)
        else
            setModule(mod, 15 - i - 1, 8)
        end if
    end for
    setModule(true, 8, m.modulesCount - 8)
end function

function drawTypeNumber()
    bits = m.rspoly.BCH_typeNumber(m.version)

    for i = 0 to 17
        mod = ((bits >> i) and 1) = 1
        setModule(mod, m.math.modulo(i, 3) + m.modulesCount - 8 - 3, m.math.floor(i / 3))
        ' now the inverse coodinates
        setModule(mod, m.math.floor(i / 3), m.math.modulo(i, 3) + m.modulesCount - 8 - 3)
    end for

end function

function putBit(buffer as object, bit as boolean, bitIndex as integer)
    index = bitIndex >> 3
    if buffer.count() <= index 
        buffer.setEntry(index, 0)
    end if
    cur = buffer[index]

    if bit
        buffer[index] = cur or (&H80 >> (bitIndex mod 8))
    else
        buffer[index] = cur and (not (&H80 >> (bitIndex mod 8)))
    end if
    return bitIndex + 1
end function

function putNum(buffer as object, num as integer, length as integer, startBitIndex as Integer)
    for i = 0 to length - 1
        putBit(buffer, (((num >> (length - i - 1)) and 1) = 1), startBitIndex + i)
    end for
    return length + startBitIndex
end function

function putText(buffer as object, text as String, bitIndex as Integer, mode as Integer)
    ' Skip implementation of number and byte modes for now
    if mode = m.constants.MODE_ALPHANUM
        for i = 0 to m.text.len() step 2
            char1 = m.string.charAt(m.text, i)
            char2 = m.string.charAt(m.text, i + 1)
            if char2.len() > 0
                bitIndex = putNum(buffer,  m.constants.ALPHANUM_LOOKUP.instr(char1) * 45 + m.constants.ALPHANUM_LOOKUP.instr(char2), 11, bitIndex)
            else
                bitIndex = putNum(buffer, m.constants.ALPHANUM_LOOKUP.instr(char1), 6, bitIndex)
            end if
        end for
    else if mode = m.constants.MODE_BYTES
        for i = 0 to m.text.len() - 1
            bitIndex = putNum(buffer, asc(m.string.charAt(m.text, i)), 8, bitIndex)
        end for
    end if
    return bitIndex
end function

function calculateData()
    buffer = createObject("roByteArray")
    bitIndex = 0
    bitIndex = putNum(buffer, m.constants.MODE_BYTES, 4, bitIndex)
    bitIndex = putNum(buffer, m.text.len(), modeSizesForVersion(m.version), bitIndex)
    bitIndex = putText(buffer, m.text, bitIndex, m.constants.MODE_BYTES)       

    blocks = rsBlocks()
    bitLimit = 0
    for each block in blocks
        bitLimit += block.dataCount * 8
    end for
    
    if bitIndex > bitLimit
        print "Code length overflow data size "; bitIndex; " larger than bit limit "; bitLimit
        return invalid
    end if
    
    for i = 0 to m.math.min(bitLimit - bitIndex, 4) - 1
        bitIndex = putBit(buffer, False, bitIndex)
    end for

    delimit = bitIndex mod 8
    if delimit > 0
        for i = 0 to (8 - delimit) - 1
            bitIndex = putBit(buffer, False, bitIndex)
        end for
    end if
    
    bytesToFill = (bitLimit - bitIndex) >> 3
    for i = 0 to bytesToFill - 1
        if i mod 2 = 0
            buffer.push(&hEC)
        else
            buffer.push(&h11)
        end if
    end for
    return createBytes(buffer, blocks)
end function 

function generatePoly(ecCount as Integer)
    num = [1]
    shift = 0
    'for i = 0 to ecCount - 1
        
end function

function createBytes(buffer as object, blocks as object)
    offset = 0
    maxDcCount = 0
    maxEcCount = 0

    dim dcData[blocks.count() - 0]
    dim ecData[blocks.count() - 0]
    
    for r = 0 to blocks.count() - 1
        dcCount = blocks[r].dataCount
        ecCount = blocks[r].totalCount - dcCount

        maxDcCount = m.math.max(maxDcCount, dcCount)
        maxEcCount = m.math.max(maxEcCount, ecCount)

        row = m.arrays.fill(createObject("roArray", dcCount, false), 0, dcCount)

        for i = 0 to dcCount - 1
            row[i] = &HFF and buffer[i + offset]
        end for

        dcData[r] = row
        offset += dcCount
        rsPolynomial = m.rspoly.RS_POLY_LOOKUP[ecCount]
        if rsPolynomial <> invalid
            rsPolynomial = m.rspoly.poly(rsPolynomial, 0)
        else
            rsPolynomial = m.rspoly.poly([1], 0)
            for i = 0 to ecCount - 1
                rsPolynomial = rsPolynomial.mul(m.rspoly.poly([1, m.rspoly.gexp(i)], 0))
            end for
        end if

        rawPoly = m.rspoly.poly(dcData[r], rsPolynomial.nums.count() - 1)
        modPoly = rawPoly.modulo(rsPolynomial)
        ecData[r] = m.arrays.fill(createObject("roArray", rsPolynomial.nums.count() - 1, true), 0, rsPolynomial.nums.count() -1)
        
        for i = 0 to rsPolynomial.nums.count() - 1
            modIndex = i + modPoly.nums.count() - ecData[r].count()
            if modIndex >= 0
                ecData[r][i] = modPoly.nums[modIndex]
            else
                ecData[r][i] = 0
            end if
        end for
    end for

    totalCodeCount = 0
    for each block in blocks
        totalCodeCount += block.totalCount
    end for
        
    outBuffer = createObject("roByteArray")

    for i = 0 to maxDcCount - 1
        for r = 0 to blocks.count() - 1
            if i < dcData[r].count()
                outBuffer.push(dcData[r][i])
            end if
        end for
    end for

    for i = 0 to maxEcCount - 1
        for r = 0 to blocks.count() - 1
            if i < ecData[r].count()
                outBuffer.push(ecData[r][i])
            end if
        end for
    end for

    dataStr = ""
    for each byte in outBuffer
        dataStr += byte.toStr() + ", "
    end for
    return outBuffer
end function

function drawData(data as object, maskPattern as integer)
    inc = -1
    row = m.modulesCount - 1
    bitIndex = 7
    byteIndex = 0

    maskFunc = m.rspoly.MASK_PATTERNS[maskPattern]
    dataLen = data.count()

    for col = m.modulesCount - 1 to 1 step -2
        myCol = col
        ' Don't actually modify the index in the for loop, just our local version
        if myCol <= 6
            myCol -= 1
        end if

        colRange = [myCol, myCol-1]

        while True
            for each c in colRange
                if not m.modules[c][row].hasBeenSet
                    dark = False
                    if byteIndex < dataLen
                        dark = (((data[byteIndex] >> bitIndex) and 1) = 1)
                        
                    end if
                    if maskFunc(row, c)
                        dark = not dark
                    end if

                    setModule(dark, c, row)
                    bitIndex -= 1
                    
                    if bitIndex = -1
                        byteIndex += 1
                        bitIndex = 7
                    end if
                end if
            end for

            row += inc
            if row < 0 or m.modulesCount <= row
                row -= inc
                inc = -inc
                exit while
            end if
        end while
    end for

end function
                    
