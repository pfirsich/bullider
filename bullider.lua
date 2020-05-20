local bullider = {}

bullider.midphase = true
bullider.continuous = true

local colliders = {}
local maxColliders = 0
local freeList = {}
local inUseList = {}

function bullider.init(maxColliders_)
    maxColliders = maxColliders_
    for i = 1, maxColliders do
        colliders[i] = {
            inUse = false,
            inUseListIndex = 0,
            x = 0, y = 0,
            lastX = 0, lastY = 0,
            radius = 0,
            group = nil,
            sweptBoundsX = 0,
            sweptBoundsY = 0,
            sweptBoundsRadius = 0,
        }
    end

    -- inUseList is filled here to preallocate the whole array.
    for i = 1, maxColliders do
        freeList[i] = i
        inUseList[i] = 0 -- to preallocate
    end
    freeList.n = maxColliders
    inUseList.n = 0
end

function bullider.spawn(x, y, radius, group) --> number (colliderId)
    if freeList.n == 0 then
        error("Too many colliders", 2)
    end
    local id = freeList[freeList.n]
    freeList.n = freeList.n - 1
    inUseList[inUseList.n + 1] = id
    inUseList.n = inUseList.n + 1

    -- We need to make sure to overwrite every field
    local collider = colliders[id]
    collider.inUse = true
    collider.inUseListIndex = inUseList.n
    collider.x = assert(x)
    collider.y = assert(y)
    collider.lastX = collider.x
    collider.lastY = collider.y
    collider.radius = assert(radius)
    collider.group = assert(group)
    collider.sweptBoundsX = collider.x
    collider.sweptBoundsY = collider.y
    collider.sweptBoundsRadius = collider.radius

    return id
end

function bullider.despawn(colliderId)
    local collider = colliders[colliderId]
    assert(collider and collider.inUse)
    collider.inUse = false
    freeList[freeList.n + 1] = colliderId
    freeList.n = freeList.n + 1
    inUseList[collider.inUseListIndex] = inUseList[inUseList.n]
    colliders[inUseList[inUseList.n]].inUseListIndex = collider.inUseListIndex
    inUseList.n = inUseList.n - 1
end

function bullider.update(colliderId, x, y)
    local collider = colliders[colliderId]
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

function bullider.getCollider(colliderId)
    local collider = colliders[colliderId]
    assert(collider and collider.inUse)
    return collider
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
local groupMatch = {}
function bullider.getCollisions(colliderId, ...) --> list { colliderId1, colliderId2, ... }
    local collider = colliders[colliderId]
    assert(collider and collider.inUse)

    for k, _ in pairs(groupMatch) do
        groupMatch[k] = nil
    end
    for i = 1, select("#", ...) do
        local group = select(i, ...)
        groupMatch[group] = true
    end

    local numCollisions = 0
    for i = 1, inUseList.n do
        local id = inUseList[i]
        local other = colliders[id]
        if groupMatch[other.group] then
            if checkCollision(collider, other) then
                collisions[numCollisions + 1] = id
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