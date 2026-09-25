-- Utility plugins
return {
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
}
