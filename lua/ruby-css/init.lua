local Source = {}
local config = require("cmp.config")
local a = require("plenary.async")
local Job = require("plenary.job")
local l = require("ruby-css.local")

local ts = vim.treesitter

local scan = require("plenary.scandir")
local rootDir = scan.scan_dir(".", {
	hidden = true,
	add_dirs = true,
	depth = 1,
	respect_gitignore = true,
	search_pattern = function(entry_path)
		local entry = entry_path:sub(3) -- remove ./
		local patterns = { ".git$", "package.json", "Gemfile" }
		for _, pattern in ipairs(patterns) do
			if entry:match(pattern) then
				return true
			end
		end
		return false
	end,
})

function Source:setup()
	require("cmp").register_source(self.source_name, Source)
end

function Source:new()
	self.source_name = "ruby_css"
	self.items = {}

	-- reading user config
	self.user_config = config.get_source_config(self.source_name) or {}
	self.option = self.user_config.option or {}
	self.globs = self.option.globs or {}
	self.style_sheets = self.option.style_sheets or {}
	self.enable_on = self.option.enable_on or {}

	-- Get the current working directory
	local current_directory = vim.fn.getcwd()

	-- Check if the current directory contains a .git folder
	local git_folder_exists = vim.fn.isdirectory(current_directory .. "/.git")

	-- if git_folder_exists == 1 then
	if vim.tbl_count(rootDir) ~= 0 then
		-- read all local files on start
		a.run(function()
			l.read_local_files(self.globs, function(classes)
				for _, class in ipairs(classes) do
					table.insert(self.items, class)
				end
			end)
		end)
	end

	return self
end

function Source:complete(_, callback)
	-- Get the current working directory
	local current_directory = vim.fn.getcwd()

	-- Check if the current directory contains a .git folder
	local git_folder_exists = vim.fn.isdirectory(current_directory .. "/.git")

	-- if git_folder_exists == 1 then
	if vim.tbl_count(rootDir) ~= 0 then
		self.items = {}

		-- read all local files on start
		a.run(function()
			l.read_local_files(self.globs, function(classes)
				for _, class in ipairs(classes) do
					table.insert(self.items, class)
				end
			end)
		end)

		callback({ items = self.items, isComplete = false })
	end
end

function is_available_html()
	local node = ts.get_node({ bfnr = 0, lang = "html" })

	if node == nil then
		return false
	end

 	local type = node:type()
	local prev_sibling = node:prev_named_sibling()

	if prev_sibling == nil then
		return false
	end

	local prev_sibling_name = ts.get_node_text(prev_sibling, 0)

	return prev_sibling_name == "class" and type == "quoted_attribute_value"
end

function is_available_ruby()
  local node = ts.get_node({ bfnr = 0, lang = 'ruby' })

	if node == nil then
		return false
	end

	local status, hash_key_symbol_node = pcall(function(n)
		local ntype = n:type()
		if ntype == 'string_content' then
			return n:parent():parent():named_child(0)
		elseif ntype == 'string' then
			return n:parent():named_child(0)
		else
			return nil
		end
	end, node)

	if not status then
		return false
	end

	if hash_key_symbol_node == nil then
		return false
	end

	local type = hash_key_symbol_node:type()
  local text = ts.get_node_text(hash_key_symbol_node, 0)

  return text == 'class' and type == 'hash_key_symbol'
end

function is_available_eruby()
	local node = ts.get_node({ bfnr = 0, lang = 'embedded_template' })

	if node == nil then
		return false
	end

	local type = node:type()

	if type == 'content' then
		return is_available_html()
	elseif type == 'code' then
		return is_available_ruby()
	else
		return false
	end
end

function Source:is_available()
	if not next(self.user_config) then
		return false
	end

  local ft = vim.bo.filetype

	if not vim.tbl_contains({ 'ruby', 'eruby' }, ft) then
		return false
	end

  if ft == 'ruby' then
    return is_available_ruby()
  elseif ft == 'eruby' then
    return is_available_eruby()
  end
end

return Source:new()
