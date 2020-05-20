local bullider = {}

bullider.midphase = true
bullider.continuous = true

local colliders = {}
local maxColliders = 0
local nextColliderId = 1

-- I thought of keeping track of a region of in-use collider ids that would move through
-- the whole range (assuming only a small portion of it is used at a time), but sadly
-- the player will keep a fixed id for a long time and outlive almost all of the bullets
-- and will make this optimization almost useless. I think this could be improved though.
-- Maybe have each collider save the next in-use collider id? (Bookkeeping might be too much)

function bullider.init(maxColliders_)
    maxColliders = maxColliders_
    for i = 1, maxColliders do
        colliders[i] = {
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

function bullider.spawn(x, y, radius, group) --> number (colliderId)
    local id = nextColliderId
    local startId = id
    while colliders[id].inUse do
        id = id + 1
        if id > maxColliders then
            id = 1
        end
        if id == startId then
            error("Too many colliders", 2)
        end
        print(id)
    end

    local collider = colliders[id]
    collider.inUse = true
    collider.x = assert(x)
    collider.y = assert(y)
    collider.lastX = collider.x
    collider.lastY = collider.y
    collider.sweptBoundsX = collider.x
    collider.sweptBoundsY = collider.y
    collider.sweptBoundsRadius = collider.radius
    collider.radius = assert(radius)
    collider.group = assert(group)

    nextColliderId = id + 1
    if nextColliderId > maxColliders then
        nextColliderId = 1
    end

    return id
end

function bullider.despawn(colliderId)
    local collider = colliders[colliderId]
    assert(collider and collider.inUse)
    collider.inUse = false
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
function bullider.getCollisions(colliderId, ...) --> list { colliderId1, colliderId2, ... }
    local collider = colliders[colliderId]
    assert(collider and collider.inUse)

    local groupMatch = {}
    for i = 1, select("#", ...) do
        local group = select(i, ...)
        groupMatch[group] = true
    end

    local numCollisions = 0
    for id = 1, maxColliders do
        local other = colliders[id]
        if other.inUse and groupMatch[other.group] then
            if checkCollision(collider, other) then
                collisions[numCollisions+1] = id
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