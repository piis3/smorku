function rsPoly() 
    arrays = ArrayUtil()
    math = MathUtil()

    expTable = arrays.fill(createObject("roArray", 256, false), 0, 256)
    logTable = arrays.fill(createObject("roArray", 256, false), 0, 256)

    for i = 0 to 255
        expTable[i] = i
    end for

    for i = 0 to 7
        expTable[i] = 1 << i
        logTable[expTable[i]] = i
    end for

    for i = 8 to 255
        expTable[i] = math.xor(math.xor(math.xor(expTable[i - 4], expTable[i - 5]), expTable[i - 6]), expTable[i - 8])
        logTable[expTable[i]] = i
    end for
    
    rs = {
        math: math,
        arrays: arrays,
        poly: function(num, shift)
            idx = 0
            for i = 0 to num.count() - 1
                if num[i] <> 0
                    exit for
                else
                    idx += 1
                end if
            end for
            shifted = m.arrays.fill(createObject("roArray", shift, true), 0, shift)

            n = invalid
            n = m.arrays.slice(num, idx, num.count() - 1)
            n.append(shifted)

            inst = {
                top: m,
                nums: n,
                mul: function(other as object)
                    size = m.nums.count() + other.nums.count() - 1
                    num = m.top.arrays.fill(createObject("roArray", size, true), 0, size)
                    
                    for i = 0 to m.nums.count() - 1
                        for j = 0 to other.nums.count() - 1
                            logsum = m.top.glog(m.nums[i]) + m.top.glog(other.nums[j])
                            val = m.top.gexp(logsum)
                            num[i + j] = m.top.math.xor(num[i + j], val)
                        end for
                    end for

                    return m.top.poly(num, 0)
                end function

                modulo: function(other as object)
                    difference = m.nums.count() - other.nums.count()
                    if difference < 0
                        return m
                    end if

                    ratio = m.top.LOG_TABLE[m.nums[0]] - m.top.LOG_TABLE[other.nums[0]]
                    pairs = m.top.arrays.zip(m.nums, other.nums)
                    out = []
                    for each pair in pairs
                        val = m.top.gexp(m.top.glog(pair[1]) + ratio)
                        out.push(m.top.math.xor(pair[0], val))
                    end for
                    for i = other.nums.count() to m.nums.count() - 1
                        out.push(m.nums[i])
                    end for

                    return m.top.poly(out, 0).modulo(other)
                end function
            }
            return inst
        end function

        rsBlockOffset: function(errorCorrection as Integer)
            if errorCorrection = 0
                return 1
            else if errorCorrection = 1
                return 0
            else if errorCorrection = 2
                return 3
            else if errorCorrection = 3
                return 2
            end if
        end function

        rsBlocks: function(version as Integer, errorCorrection as Integer)
            offset = m.rsBlockOffset(errorCorrection)
            rsBlock = m.RS_BLOCK_TABLE[(version - 1) * 4 + offset]
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

        createPolyBytes: function(rsb as object)
            dcCount = rsb[0].dataCount
            ecCount = rsb[0].totalCount - dcCount
            p = m.poly([1], 0)
            for i = 0 to ecCount - 1
                p = p.mul(m.poly([1, m.gexp(i)], 0))
            end for
            return [ecCount, p]
        end function

        gexp: function(n as Integer)
            return m.EXP_TABLE[m.math.modulo(n, 255)]
        end function

        glog: function(n as Integer)
            return m.LOG_TABLE[n]
        end function

        RS_BLOCK_TABLE: ParseJSON(ReadAsciiFile("pkg:/json/rsBlockTable.json")),
        BIT_LIMIT_TABLE: [[0, 128, 224, 352, 512, 688, 864, 992, 1232, 1456, 1728, 2032, 2320, 2672, 2920, 3320, 3624, 4056, 4504, 5016, 5352, 5712, 6256, 6880, 7312, 8000, 8496, 9024, 9544, 10136, 10984, 11640, 12328, 13048, 13800, 14496, 15312, 15936, 16816, 17728, 18672], [0, 152, 272, 440, 640, 864, 1088, 1248, 1552, 1856, 2192, 2592, 2960, 3424, 3688, 4184, 4712, 5176, 5768, 6360, 6888, 7456, 8048, 8752, 9392, 10208, 10960, 11744, 12248, 13048, 13880, 14744, 15640, 16568, 17528, 18448, 19472, 20528, 21616, 22496, 23648], [0, 72, 128, 208, 288, 368, 480, 528, 688, 800, 976, 1120, 1264, 1440, 1576, 1784, 2024, 2264, 2504, 2728, 3080, 3248, 3536, 3712, 4112, 4304, 4768, 5024, 5288, 5608, 5960, 6344, 6760, 7208, 7688, 7888, 8432, 8768, 9136, 9776, 10208], [0, 104, 176, 272, 384, 496, 608, 704, 880, 1056, 1232, 1440, 1648, 1952, 2088, 2360, 2600, 2936, 3176, 3560, 3880, 4096, 4544, 4912, 5312, 5744, 6032, 6464, 6968, 7288, 7880, 8264, 8920, 9368, 9848, 10288, 10832, 11408, 12016, 12656, 13328]],
        EXP_TABLE: expTable,
        LOG_TABLE: logTable,

        G15: ((1 << 10) or (1 << 8) or (1 << 5) or (1 << 4) or (1 << 2) or (1 << 1) or (1 << 0)),
        G18: ((1 << 12) or (1 << 11) or (1 << 10) or (1 << 9) or (1 << 8) or (1 << 5) or (1 << 2) or (1 << 0)),
        G15_MASK: (1 << 14) or (1 << 12) or (1 << 10) or (1 << 4) or (1 << 1),

        ' There are 8 different masking function used depending on which produces the fewest artifacts
        ' They are implemnented by index here
        MASK_PATTERNS: [
            ' 000
            function(i, j)
                return (i + j) mod 2 = 0
            end function

            ' 001
            function(i, j)
                return i mod 2 = 0
            end function

            ' 010
            function(i, j)
                return j mod 3 = 0
            end function

            ' 011
            function(i, j)
                return (i + j) mod 3 = 0
            end function
            
            ' 100
            function(i, j)
                return (m.math.floor(i / 2) + m.math.floor(j / 3)) mod 2 = 0
            end function

            ' 101
            function(i, j)
                return (i * j) mod 2 + (i * j) mod 3 = 0
            end function

            ' 110
            function(i, j)
                return ((i * j) mod 2 + (i * j) mod 3) mod 2 = 0
            end function

            ' 111
            function(i, j)
                return ((i * j) mod 3 + (i + j) mod 2) mod 2 = 0
            end function
        ],

        BCH_digit: function (d as integer)
            digit = 0
            data = d
            while data <> 0
                digit += 1
                data = data >> 1
            end while
            return digit
        end function

        BCH_typeInfo: function (data as integer)
            d = data << 10
            while (m.BCH_digit(d) - m.BCH_digit(m.G15)) >= 0
                d = m.math.xor(d, (m.G15 << (m.BCH_digit(d) - m.BCH_digit(m.G15))))
            end while
            return m.math.xor((data << 10) or d, m.G15_MASK)
        end function

        BCH_typeNumber: function (data as integer)
            d = data << 12
            while m.BCH_digit(d) - m.BCH_digit(m.G18) >= 0
                d = m.math.xor(d, (m.G18 << (m.BCH_digit(d) - m.BCH_digit(m.G18))))
            end while
            return (data << 12) or d
        end function

    }

    lookup = []
    for version = 1 to 40
        for errorCorrection = 0 to 3
            rsBlockList = rs.rsBlocks(version, errorCorrection)
            pair = rs.createPolyBytes(rsBlockList)
            lookup[pair[0]] = pair[1].nums
        end for
    end for
    rs.RS_POLY_LOOKUP = lookup
    
    return rs
end function
