return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    delay = 300,
  },
  config = function(_, opts)
    local wk = require("which-key")
    wk.setup(opts)
    wk.add({
      { "<leader>r", group = "Run" },
      { "<leader>s", group = "Save / Session" },
    })
  end,
}
