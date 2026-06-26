local M = {}

M.defaults = {
    enabled = true,
    vault_path = nil
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.defaults, opts or {})
end


-- heading
function M.heading_set(level)
	return function()
		local line = vim.api.nvim_get_current_line()
		if level == 0 then
			line = line:gsub("^#*%s*", "")
		else
			line = line:gsub("^#*%s*", ("#"):rep(level) .. " ")
		end
		vim.api.nvim_set_current_line(line)
	end
end

function M.heading_increase()
	local line = vim.api.nvim_get_current_line()
	local head = line:match("^#*")
	if #head < 6 then
		line = line:gsub("^#*%s*", ("#"):rep(#head + 1) .. " ")
		vim.api.nvim_set_current_line(line)
	end
end


function M.heading_decrease()
	local line = vim.api.nvim_get_current_line()
	local head = line:match("^#+")
	if not head then return end
	if #head == 1 then
		line = line:gsub("^#*%s*", "")
	else
		line = line:gsub("^#*%s*", ("#"):rep(#head - 1) .. " ")
	end
	vim.api.nvim_set_current_line(line)
end


-- links
function M.telescope_insert_filename(opts)
    opts = opts or {}
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    pickers.new(opts, {
        prompt_title = "Insert filename",
        finder = finders.new_oneshot_job(
            { "rg", "--files", "--type", "md" }, -- только .md файлы
            { cwd = opts.cwd or M.config.vault_path }
        ),
        sorter = conf.file_sorter(opts),
        previewer = conf.file_previewer(opts),
        attach_mappings = function(prompt_bufnr, map)
            local function insert_plain(close_after)
                local entry = action_state.get_selected_entry()
                if close_after then
                    actions.close(prompt_bufnr)
                end
                local filename = vim.fn.fnamemodify(entry[1], ":t:r") -- имя без пути и расширения
                vim.api.nvim_put({ filename }, "c", true, true)
            end

            local function insert_wikilink(close_after)
                local entry = action_state.get_selected_entry()
                if close_after then
                    actions.close(prompt_bufnr)
                end
                local filename = vim.fn.fnamemodify(entry[1], ":t:r")
                vim.api.nvim_put({ "[[" .. filename .. "]]" }, "c", true, true)
            end

            -- <CR> — обычная вставка имени файла
            map("i", "<CR>", function() insert_plain(true) end)
            map("n", "<CR>", function() insert_plain(true) end)

            -- <C-l> — вставка как wiki-ссылку [[Title]]
            map("i", "<C-l>", function() insert_wikilink(true) end)
            map("n", "<C-l>", function() insert_wikilink(true) end)

            return true
        end,
    }):find()
end


function M.telescope_open_wikilink(opts)
    opts = opts or {}
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    -- Извлекаем [[link]] из visual-выделения или из текста под курсором
    local function get_link_under_cursor()
        local mode = vim.fn.mode()

        -- Visual-выделение
        if mode == "v" or mode == "V" then
            local _, ls, cs = unpack(vim.fn.getpos("v"))  -- line/column start/end
            local _, le, ce = unpack(vim.fn.getpos("."))
            -- Нормализуем порядок (начало < конец). Выделять можно задом наперёд
            if ls > le or (ls == le and cs > ce) then
                ls, le, cs, ce = le, ls, ce, cs
            end
            local lines = vim.api.nvim_buf_get_text(0, ls - 1, cs - 1, le - 1, ce, {})
            local selected = table.concat(lines, "")
            -- Если выделен [[link]] целиком — вырезаем, иначе берём как есть
            return selected:match("^%[%[(.-)%]%]$") or selected
        end

        -- Под курсором — ищем [[...]] вокруг позиции
        local line = vim.api.nvim_get_current_line()
        local col  = vim.api.nvim_win_get_cursor(0)[2] + 1 -- 1-based

        -- Ищем все [[...]] на строке и проверяем, попадает ли курсор внутрь
        for link in line:gmatch("%[%[(.-)%]%]") do
            local start_pos, end_pos = line:find("%[%[" .. vim.pesc(link) .. "%]%]", 1, false)
            if start_pos then
                if col >= start_pos and col <= end_pos then
                    -- Убираем alias: [[Title|alias]] → Title
                    return link:match("^(.-)%|") or link
                end
            end
        end

        return nil
    end

    local link_text = get_link_under_cursor()


    pickers.new(opts, {
        prompt_title = link_text and ('Open: "' .. link_text .. '"') or "Open note",
        default_text = link_text or "", -- предзаполняем запрос (работает и как фолбэк если не нашли)
        finder = finders.new_oneshot_job(
            { "rg", "--files", "--type", "md" },
            { cwd = opts.cwd or M.config.vault_path }
        ),
        sorter = conf.file_sorter(opts),
        previewer = conf.file_previewer(opts),
        attach_mappings = function(prompt_bufnr)
            -- Экранируем спец символы
            actions.select_default:replace(function()
                actions.close(prompt_bufnr)
                local entry = action_state.get_selected_entry()
                if entry then
                    vim.cmd("edit " .. vim.fn.fnameescape(entry[1]))
                end
            end)
            return true
        end,
    }):find()
end


function M.test()

end


return M
