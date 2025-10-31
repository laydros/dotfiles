-- Syntax and language support
return {
  { 'sheerun/vim-polyglot' },
  {
    'preservim/vim-markdown',
    ft = 'markdown',
    init = function()
      vim.g.vim_markdown_no_default_key_mappings = 1
      vim.g.vim_markdown_folding_disabled = 1
      vim.g.vim_markdown_strikethrough = 1
      vim.g.tex_conceal = ""
      vim.g.vim_markdown_math = 1
      vim.g.vim_markdown_frontmatter = 1
    end,
  },
}
