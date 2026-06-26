# obsidian-addon.nvim

Лёгкий плагин для Neovim на Lua, добавляющий управление заголовками в стиле Obsidian и навигацию по викиссылкам с помощью [Telescope](https://github.com/nvim-telescope/telescope.nvim).

Меня не устраивает скорость работы lsp obsidian-nvim/obsidian.nvim, по этому было создан этот плагин. А так же дополнительные функции которых мне не хватает.

## Возможности

- **Управление заголовками** — устанавливает, повышает или понижает уровень Markdown-заголовка на текущей строке
- **Вставка имени файла / викиссылки** — нечёткий поиск `.md`-файлов в хранилище с вставкой как простого имени или `[[викиссылки]]`
- **Открытие викиссылки** — переход к заметке по `[[ссылке]]` под курсором или в визуальном выделении

## Требования

- Neovim >= 0.8.0
- [nvim-telescope/telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [BurntSushi/ripgrep](https://github.com/BurntSushi/ripgrep) (`rg`) в `$PATH`

## Установка

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "Cipher-Void/obsidian-addon.nvim",
  dependencies = { "nvim-telescope/telescope.nvim" },
  opts = {},
  keys = {
    { "<leader>oif", function() require("obsidian-addon").telescope_insert_filename() end,    desc = "[I]nsert [f]ilename (Telescope)" },
    { "<leader>ogd", function()
        require("obsidian-addon").telescope_open_wikilink()
    end, mode = { "n", "v" },                                                                 desc = "Obsidian: [g]o [t]o wikilink" },
    { "gd", function()
        require("obsidian-addon").telescope_open_wikilink()
    end, mode = { "n", "v" }, ft = "markdown",                                                desc = "Obsidian: [g]o [t]o wikilink" },
    -- Работа с заголовками
    { "<leader>oh0", function() require("obsidian-addon").heading_set(0)() end,     	      desc = "Obsidian MD: Remove heading" },
    { "<leader>oh1", function() require("obsidian-addon").heading_set(1)() end,     	      desc = "Obsidian MD: Heading 1" },
    { "<leader>oh2", function() require("obsidian-addon").heading_set(2)() end,     	      desc = "Obsidian MD: Heading 2" },
    { "<leader>oh3", function() require("obsidian-addon").heading_set(3)() end,             desc = "Obsidian MD: Heading 3" },
    { "<leader>oh4", function() require("obsidian-addon").heading_set(4)() end,             desc = "Obsidian MD: Heading 4" },
    { "<leader>oh5", function() require("obsidian-addon").heading_set(5)() end,             desc = "Obsidian MD: Heading 5" },
    { "<leader>oh6", function() require("obsidian-addon").heading_set(6)() end,             desc = "Obsidian MD: Heading 6" },
    { "<leader>oh=", function() require("obsidian-addon").heading_increase() end, 		      desc = "Obsidian MD: Heading increase" },
    { "<leader>oh-", function() require("obsidian-addon").heading_decrease() end,   	      desc = "Obsidian MD: Heading decrease" },
  },
}
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "Cipher-Void/obsidian-addon.nvim",
  requires = { "nvim-telescope/telescope.nvim" },
  config = function()
    require("obsidian-addon").setup({
      vault_path = "~/notes",
    })
  end,
}
```

## Конфигурация

```lua
require("obsidian-addon").setup({
  enabled    = true,  -- включить плагин (по умолчанию: true)
  vault_path = nil,   -- абсолютный путь к хранилищу, например "~/notes"
})
```

`vault_path` используется как корневая директория при поиске `.md`-файлов. Если не задан, используется текущая рабочая директория.

## Использование

Плагин предоставляет функции через `require("obsidian-addon")`. Привяжите их к удобным для вас клавишам.

### Заголовки

```lua
local oa = require("obsidian-addon")

-- Установить конкретный уровень заголовка (1–6) или 0 для удаления
vim.keymap.set("n", "<leader>oh1", oa.heading_set(1))
vim.keymap.set("n", "<leader>oh2", oa.heading_set(2))
vim.keymap.set("n", "<leader>oh3", oa.heading_set(3))
vim.keymap.set("n", "<leader>oh0", oa.heading_set(0)) -- убрать заголовок

-- Повысить / понизить уровень заголовка
vim.keymap.set("n", "<leader>oh=", oa.heading_increase)
vim.keymap.set("n", "<leader>oh-", oa.heading_decrease)
```

| Функция | Описание |
|---|---|
| `heading_set(level)` | Устанавливает уровень заголовка на текущей строке. `0` удаляет любой заголовок. Максимальный уровень — 6. |
| `heading_increase()` | Повышает уровень на один (например `## → ###`). На `######` ничего не делает. |
| `heading_decrease()` | Понижает уровень на один (например `## → #`). На `#` полностью убирает заголовок. |

### Вставка имени файла / викиссылки

Открывает пикер Telescope, который ищет все `.md`-файлы в `vault_path`.

```lua
vim.keymap.set("n", "<leader>oif", function()
  require("obsidian-addon").telescope_insert_filename()
end)
```

Можно переопределить директорию поиска для отдельного вызова через `cwd`:

```lua
vim.keymap.set("n", "<leader>oif", function()
  require("obsidian-addon").telescope_insert_filename({ cwd = "~/work/notes" })
end)
```

`cwd` имеет приоритет над глобальным `vault_path`, заданным в `setup()`.

Управление внутри пикера:

| Клавиша | Действие |
|---|---|
| `<CR>` | Вставить имя файла (без расширения) в позицию курсора |
| `<C-l>` | Вставить викиссылку `[[имя_файла]]` в позицию курсора |

### Открытие викиссылки

Открывает пикер Telescope для перехода к заметке. Автоматически определяет `[[ссылку]]` под курсором или в визуальном выделении и предзаполняет строку поиска.

Поддерживает алиасы — `[[Title|alias]]` корректно раскрывается как `Title`.

```lua
vim.keymap.set("n", "<leader>ogd", function()
  require("obsidian-addon").telescope_open_wikilink()
end)
vim.keymap.set("v", "<leader>ogd", function()
  require("obsidian-addon").telescope_open_wikilink()
end)
```

Можно переопределить директорию поиска для отдельного вызова через `cwd`:

```lua
vim.keymap.set("n", "<leader>ogd", function()
  require("obsidian-addon").telescope_open_wikilink({ cwd = "~/work/notes" })
end)
```

`cwd` имеет приоритет над глобальным `vault_path`, заданным в `setup()`.

## Лицензия

MIT — см. [LICENSE](LICENSE).
