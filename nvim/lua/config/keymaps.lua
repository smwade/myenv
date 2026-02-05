-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
vim.keymap.set("n", "<leader>ex", "<cmd>term python3 %<cr>", { desc = "Execute Current Python File" })

-- Terminal mode: easy escape
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- Better split navigation (works with terminal panes too)
vim.keymap.set('n', '<C-h>', '<C-w>h', { desc = 'Move to left split' })
vim.keymap.set('n', '<C-j>', '<C-w>j', { desc = 'Move to lower split' })
vim.keymap.set('n', '<C-k>', '<C-w>k', { desc = 'Move to upper split' })
vim.keymap.set('n', '<C-l>', '<C-w>l', { desc = 'Move to right split' })

-- Terminal navigation
vim.keymap.set('t', '<C-h>', '<C-\\><C-n><C-w>h', { desc = 'Move to left split from terminal' })
vim.keymap.set('t', '<C-j>', '<C-\\><C-n><C-w>j', { desc = 'Move to lower split from terminal' })
vim.keymap.set('t', '<C-k>', '<C-\\><C-n><C-w>k', { desc = 'Move to upper split from terminal' })
vim.keymap.set('t', '<C-l>', '<C-\\><C-n><C-w>l', { desc = 'Move to right split from terminal' })
