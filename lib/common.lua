--Common function used basically everywhere

function fileRead(filename)
	local file = io.open(filename, "r");
	local text = file:read("*a");
	file:close();
	return text;
end

function os.executef(command, ...)
	os.execute(string.format(command, ...));
end

function printf(str, ...)
	print(string.format(str, ...));
end
