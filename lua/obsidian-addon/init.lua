local M = {}

M.defaults = {
    enabled = true,
    vault_path = nil,
    picker = "snacks", -- "snacks" | "telescope"
}

function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", M.defaults, opts or {})
end


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


local function get_link_under_cursor()
    local mode = vim.fn.mode()

    if mode == "v" or mode == "V" then
        local _, ls, cs = unpack(vim.fn.getpos("v"))
        local _, le, ce = unpack(vim.fn.getpos("."))
        if ls > le or (ls == le and cs > ce) then
            ls, le, cs, ce = le, ls, ce, cs
        end
        local lines = vim.api.nvim_buf_get_text(0, ls - 1, cs - 1, le - 1, ce, {})
        local selected = table.concat(lines, "")
        return selected:match("^%[%[(.-)%]%]$") or selected
    end

    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2] + 1

    for link in line:gmatch("%[%[(.-)%]%]") do
        local start_pos, end_pos = line:find("%[%[" .. vim.pesc(link) .. "%]%]", 1, false)
        if start_pos then
            if col >= start_pos and col <= end_pos then
                return link:match("^(.-)%|") or link
            end
        end
    end

    return nil
end

-- ==========================================================================
-- Backend: snacks.picker
-- ==========================================================================

local function snacks_insert_filename(opts)
    Snacks.picker.pick({
        source = "obsidian_insert_filename",
        title = "Insert filename",
        cwd = opts.cwd or M.config.vault_path,
        finder = function(finder_opts, ctx)
            return require("snacks.picker.source.proc").proc({
                cmd = "rg",
                args = { "--files", "--type", "md" },
                cwd = finder_opts.cwd,
            }, ctx)
        end,
        format = "file",
        preview = "file",
        confirm = function(picker, item)
            picker:close()
            if item then
                vim.api.nvim_put({ vim.fn.fnamemodify(item.file, ":t:r") }, "c", true, true)
            end
        end,
        actions = {
            insert_wikilink = function(picker, item)
                picker:close()
                if item then
                    local filename = vim.fn.fnamemodify(item.file, ":t:r")
                    vim.api.nvim_put({ "[[" .. filename .. "]]" }, "c", true, true)
                end
            end,
        },
        win = {
            input = { keys = { ["<C-l>"] = { "insert_wikilink", mode = { "i", "n" } } } },
        },
    })
end

local function snacks_open_wikilink(opts, link_text)
    Snacks.picker.pick({
        source = "obsidian_open_wikilink",
        title = link_text and ('Open: "' .. link_text .. '"') or "Open note",
        cwd = opts.cwd or M.config.vault_path,
        search = link_text or "",
        finder = function(finder_opts, ctx)
            return require("snacks.picker.source.proc").proc({
                cmd = "rg",
                args = { "--files", "--type", "md" },
                cwd = finder_opts.cwd,
            }, ctx)
        end,
        format = "file",
        preview = "file",
        confirm = function(picker, item)
            picker:close()
            if item then
                vim.cmd("edit " .. vim.fn.fnameescape(item.file))
            end
        end,
    })
end

-- ==========================================================================
-- Backend: telescope.nvim
-- ==========================================================================

local function telescope_insert_filename(opts)
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    pickers.new(opts, {
        prompt_title = "Insert filename",
        finder = finders.new_oneshot_job(
            { "rg", "--files", "--type", "md" },
            { cwd = opts.cwd or M.config.vault_path }
        ),
        sorter = conf.file_sorter(opts),
        previewer = conf.file_previewer(opts),
        attach_mappings = function(prompt_bufnr, map)
            local function insert_plain(close_after)
                local entry = action_state.get_selected_entry()
                if close_after then actions.close(prompt_bufnr) end
                local filename = vim.fn.fnamemodify(entry[1], ":t:r")
                vim.api.nvim_put({ filename }, "c", true, true)
            end

            local function insert_wikilink(close_after)
                local entry = action_state.get_selected_entry()
                if close_after then actions.close(prompt_bufnr) end
                local filename = vim.fn.fnamemodify(entry[1], ":t:r")
                vim.api.nvim_put({ "[[" .. filename .. "]]" }, "c", true, true)
            end

            map("i", "<CR>", function() insert_plain(true) end)
            map("n", "<CR>", function() insert_plain(true) end)
            map("i", "<C-l>", function() insert_wikilink(true) end)
            map("n", "<C-l>", function() insert_wikilink(true) end)

            return true
        end,
    }):find()
end

local function telescope_open_wikilink(opts, link_text)
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    pickers.new(opts, {
        prompt_title = link_text and ('Open: "' .. link_text .. '"') or "Open note",
        default_text = link_text or "",
        finder = finders.new_oneshot_job(
            { "rg", "--files", "--type", "md" },
            { cwd = opts.cwd or M.config.vault_path }
        ),
        sorter = conf.file_sorter(opts),
        previewer = conf.file_previewer(opts),
        attach_mappings = function(prompt_bufnr)
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

-- ==========================================================================
-- Публичное API — диспетчер по M.config.picker
-- ==========================================================================

function M.insert_filename(opts)
    opts = opts or {}
    if M.config.picker == "telescope" then
        telescope_insert_filename(opts)
    else
        snacks_insert_filename(opts)
    end
end

function M.open_wikilink(opts)
    opts = opts or {}
    local link_text = get_link_under_cursor()
    if M.config.picker == "telescope" then
        telescope_open_wikilink(opts, link_text)
    else
        snacks_open_wikilink(opts, link_text)
    end
end

function M.test()
end

return M
