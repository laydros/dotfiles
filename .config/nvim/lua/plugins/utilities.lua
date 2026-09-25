-- Utility plugins
return {
  { 'dense-analysis/ale' },
  { 'wellle/context.vim', event = 'VeryLazy' },
  {
    'dhruvasagar/vim-table-mode',
    ft = 'markdown',
    init = function()
      vim.g.table_mode_corner = '|'
      vim.g.table_mode_corner_corner = '|'
      vim.g.table_mode_header_fillchar = '-'
    end,
  },
  { 'nvim-lua/plenary.nvim' },
}
