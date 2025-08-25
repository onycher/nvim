return {
  {
    "neovim/nvim-lspconfig",
    ---@class PluginLspOpts
    opts = {
      ---@type lspconfig.options
      servers = {
        pylsp = {},
        robotcode = {},
        cucumber_language_server = {
          settings = {
            cucumber = {
              glue = { "steps/**/*.py", "steps/*.py" }, 
            },
          },
        },
      },
    },
  },

}
