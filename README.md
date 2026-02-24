## Installation Steps

1. Install [Neovim 0.11.5+](https://github.com/neovim/neovim/releases/latest)

2. Clone this repo into the directory of your plugin configuration. (Example for [NvChad](https://github.com/NvChad/NvChad))
```sh
   git clone https://github.com/bombitron/nvim-java-autoproj.git ~/.config/nvim/lua/plugins/
```

3. Add [nvim-java](https://github.com/nvim-java/nvim-java) to your plugins as you normally would, but instead of just enabling [jdtls](https://github.com/eclipse-jdtls/eclipse.jdt.ls) after calling to its setup, call to the init function of the nvim-java-autoproj module (you may need to modify the require call depending on the directory in which you cloned it):

### Using `vim.pack`
```lua
vim.pack.add({
  {
    src = 'https://github.com/JavaHello/spring-boot.nvim',
    version = '218c0c26c14d99feca778e4d13f5ec3e8b1b60f0',
  },
  'https://github.com/MunifTanjim/nui.nvim',
  'https://github.com/mfussenegger/nvim-dap',

  'https://github.com/nvim-java/nvim-java',
})

require('java').setup()
require('plugins.nvim-java-autoproj.setup').init()
```

### Using `lazy.nvim`

Install using [lazy.nvim](https://github.com/folke/lazy.nvim):
```lua
{
  'nvim-java/nvim-java',
  config = function()
    require('java').setup()
    require('plugins.nvim-java-autoproj.setup').init()
  end,
}
```

4. Enjoy

## Usage

When opening a project without a valid project metadata file, jdtls will fire a warning saying that only syntax errors will be reported for the file. With this module, the user will instead be asked if they want the workspace to be turned into a valid java project.

For that, if allowed, it will generate the .project and .classpath XMLs needed by jdtls, then clear the workspace cache and restart the client. If no src folder is found, it will create one and move the current java file inside.

## Why?

When working with a non-indexed java project, imports of local classes and package declarations do not work, and this module aims to make that work in small projects where gradle, maven or git are unnecessary.

## Thanks

Thanks to the [nvim-java](https://github.com/nvim-java/nvim-java) devs for their amazing work at making programming java in nvim such a smooth experience. Make sure to give their work a look!
