-- lsp.lua - 2025-10-29 - jwh
-- LSP configuration using built-in vim.lsp.config API

-- LSP keymaps (attached when LSP attaches to buffer)
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('UserLspConfig', {}),
  callback = function(args)
    local opts = { buffer = args.buf, noremap = true, silent = true }

    -- Navigation
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
    vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
    vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
    vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)

    -- Hover documentation
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)

    -- Code actions
    vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
    vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)

    -- Formatting
    vim.keymap.set('n', '<leader>f', function()
      vim.lsp.buf.format({ async = true })
    end, opts)

    -- Diagnostics
    vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, opts)
    vim.keymap.set('n', ']d', vim.diagnostic.goto_next, opts)
    vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, opts)
  end,
})

-- Rust LSP Configuration
vim.lsp.config.rust_analyzer = {
  cmd = { 'rust-analyzer' },
  filetypes = { 'rust' },
  root_markers = { 'Cargo.toml', '.git' },
  settings = {
    ['rust-analyzer'] = {
      cargo = {
        allFeatures = true,
      },
      checkOnSave = {
        command = 'clippy',
      },
    }
  }
}
vim.lsp.enable('rust_analyzer')

-- Python LSP Configuration (pyright)
vim.lsp.config.pyright = {
  cmd = { 'pyright-langserver', '--stdio' },
  filetypes = { 'python' },
  root_markers = { 'pyproject.toml', 'setup.py', 'setup.cfg', 'requirements.txt', '.git' },
  settings = {
    python = {
      analysis = {
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        diagnosticMode = 'workspace',
      }
    }
  }
}
vim.lsp.enable('pyright')

-- Go LSP Configuration
vim.lsp.config.gopls = {
  cmd = { 'gopls' },
  filetypes = { 'go', 'gomod', 'gowork', 'gotmpl' },
  root_markers = { 'go.work', 'go.mod', '.git' },
  settings = {
    gopls = {
      analyses = {
        unusedparams = true,
      },
      staticcheck = true,
      gofumpt = true,
    }
  }
}
vim.lsp.enable('gopls')

-- Bash LSP Configuration
vim.lsp.config.bashls = {
  cmd = { 'bash-language-server', 'start' },
  filetypes = { 'sh', 'bash' },
  root_markers = { '.git' },
}
vim.lsp.enable('bashls')

-- Lua LSP Configuration
-- Generic settings for all Lua files
-- Neovim-specific settings (vim global, runtime files) are in .luarc.json at nvim config root
vim.lsp.config.lua_ls = {
  cmd = { 'lua-language-server' },
  filetypes = { 'lua' },
  root_markers = { '.luarc.json', '.luarc.jsonc', '.luacheckrc', '.stylua.toml', 'stylua.toml', 'selene.toml', 'selene.yml', '.git' },
  settings = {
    Lua = {
      runtime = {
        version = 'LuaJIT',
      },
      workspace = {
        checkThirdParty = false,
      },
      telemetry = {
        enable = false,
      },
    }
  }
}
vim.lsp.enable('lua_ls')

-- Markdown LSP Configuration (rumdl: markdownlint-compatible linter)
vim.lsp.config.rumdl = {
  cmd = { 'rumdl', 'server' },
  filetypes = { 'markdown' },
  root_markers = { '.rumdl.toml', 'rumdl.toml', '.markdownlint.json', '.git' },
}
vim.lsp.enable('rumdl')
