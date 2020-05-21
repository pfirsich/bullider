local bit = require("bit")
local band, bor, lshift = bit.band, bit.bor, bit.lshift

local bullider = {}

bullider.midphase = true
bullider.continuous = true

local colliders = {}
local maxColliders = 0
local maxInUseIndex = 0
local groupId = 0

function bullider.init(maxColliders_)
    maxColliders = maxColliders_
    for i = 1, maxColliders do
        colliders[i] = {
            index = i,
            inUse = false,
            x = 0, y = 0,
            lastX = 0, lastY = 0,
            radius = 0,
            group = nil,
            sweptBoundsX = 0,
            sweptBoundsY = 0,
            sweptBoundsRadius = 0,
        }
    end
end

function bullider.group()
    if groupId == 0 then
        groupId = 1
        return groupId
    end

    local nextId = lshift(groupId, 1)
    if nextId < groupId then
        error("Too many groups", 2)
    end
    groupId = nextId
    return groupId
end

function bullider.joinGroups(...)
    local joined = 0
    for i = 1, select("#", ...) do
        local group = select(i, ...)
        joined = bor(joined, group)
    end
    return joined
end

function bullider.spawn(x, y, radius, group) --> table (collider)
    if maxInUseIndex == maxColliders then
        error("Too many colliders", 2)
    end
    local index = maxInUseIndex + 1
    maxInUseIndex = index

    -- We need to make sure to overwrite every field
    local collider = colliders[index]
    collider.index = index
    collider.inUse = true
    collider.x = assert(x)
    collider.y = assert(y)
    collider.lastX = collider.x
    collider.lastY = collider.y
    collider.radius = assert(radius)
    collider.group = assert(group)
    collider.sweptBoundsX = collider.x
    collider.sweptBoundsY = collider.y
    collider.sweptBoundsRadius = collider.radius

    return collider
end

function bullider.despawn(collider)
    assert(collider and collider.inUse)
    collider.inUse = false
    -- swap collider to end and pop
    colliders[collider.index], colliders[maxInUseIndex] =
        colliders[maxInUseIndex], colliders[collider.index]
    maxInUseIndex = maxInUseIndex - 1
    -- fix the swapped in collider
    colliders[collider.index].index = collider.index
end

function bullider.update(collider, x, y)
    assert(collider and collider.inUse)
    collider.lastX = collider.x
    collider.lastY = collider.y
    collider.x = x
    collider.y = y

    if bullider.continuous and bullider.midphase then
        collider.sweptBoundsX = (collider.lastX + collider.x) / 2
        collider.sweptBoundsY = (collider.lastY + collider.y) / 2
        local relX = collider.x - collider.lastX
        local relY = collider.y - collider.lastY
        local relLen = math.sqrt(relX*relX + relY*relY)
        collider.sweptBoundsRadius = relLen / 2.0 + collider.radius
    end
end

local function circleCircle(x1, y1, r1, x2, y2, r2)
    local relx, rely = x1 - x2, y1 - y2
    local rsum = r1 + r2
    return relx*relx + rely*rely <= rsum*rsum
end

local function clamp(x, lo, hi)
    return math.max(lo, math.min(hi, x))
end

local function checkSweptCollision(collider, other) --> boolean
    -- We move to the reference frame of `collider` and then determine the
    -- collision between a static circle at 0, 0 (`collider`)
    -- and a swept circle (`other`) from
    local sX = other.lastX - collider.lastX -- sweep start
    local sY = other.lastY - collider.lastY
    -- to
    local eX = other.x - collider.x -- sweep end
    local eY = other.y - collider.y

    local rX = eX - sX -- relative sweep vector
    local rY = eY - sY

    -- project collider position (0, 0) onto relative sweep vector:
    -- dot(0 - s, r) / dot(r, r) = -dot(s, r) / dot(r, r)
    local t = clamp(-(sX*rX + sY*rY) / (rX*rX + rY*rY), 0, 1)
    local cX = sX + t * rX -- closest point on line segment of sweep
    local cY = sY + t * rY
    local rsum = collider.radius + other.radius
    return cX*cX + cY*cY <= rsum*rsum
end

local function checkCollision(collider, other) --> boolean
    if bullider.continuous then
        if bullider.midphase then
            if not circleCircle(collider.x, collider.y, collider.radius,
                                other.sweptBoundsX, other.sweptBoundsY,
                                other.sweptBoundsRadius) then
                return false
            end
        end
        return checkSweptCollision(collider, other)
    else
        return circleCircle(collider.x, collider.y, collider.radius,
                            other.x, other.y, other.radius)
    end
end

local collisions = {}
function bullider.getCollisions(collider, group) --> list { collider1, collider2, ... }
    assert(collider and collider.inUse)

    local numCollisions = 0
    for i = 1, maxInUseIndex do
        local other = colliders[i]
        if band(other.group, group) ~= 0 then
            if checkCollision(collider, other) then
                collisions[numCollisions + 1] = other
                numCollisions = numCollisions + 1
            end
        end
    end

    for i = numCollisions + 1, #collisions do
        collisions[i] = nil
    end

    return collisions
end

return bullider
