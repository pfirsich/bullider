return function(count)
	local values = {}
	local nextIndex = 1

	for i = 1, count do
		values[i] = 0
	end

	return function(val)
		if val then
			values[nextIndex] = val
			nextIndex = nextIndex + 1
			if nextIndex > count then
				nextIndex = 1
			end
		else
			local sum = 0
			for i = 1, count do
				sum = sum + values[i]
			end
			return sum / count
		end
	end
end