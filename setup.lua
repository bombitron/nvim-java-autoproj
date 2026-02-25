local M = {}

-- Semantic tokens server capability is not requested by jdtls on a hot reload,
-- so it has to be manually injected from the value of a healthy session

local semantic_tokens_capability = {
  full = { delta = false },
  range = false,
  legend = {
    tokenTypes = {
      'namespace', 'class', 'interface', 'enum', 'enumMember', 'type',
      'typeParameter', 'method', 'property', 'variable', 'parameter',
      'modifier', 'keyword', 'annotation', 'annotationMember', 'record',
      'recordComponent',
    },
    tokenModifiers = {
      'abstract', 'static', 'readonly', 'deprecated', 'declaration',
      'documentation', 'public', 'private', 'protected', 'native',
      'generic', 'typeArgument', 'importDeclaration', 'constructor',
    },
  },
  documentSelector = {
    { language = 'java', scheme = 'file' },
    { language = 'java', scheme = 'jdt' },
  },
}

function M.init()
  local current = vim.lsp.config['jdtls']
  local project_markers = current.root_markers[2]

  if type(project_markers) == 'table' and not vim.list_contains(project_markers, '.project') then
    table.insert(project_markers, '.project')
  end

  vim.lsp.config('jdtls', { root_markers = project_markers })

  vim.lsp.enable('jdtls')

  local prompted = false

  local handler_installed_for = nil

  vim.api.nvim_create_autocmd('LspAttach', {
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if not client or client.name ~= 'jdtls' then return end
      if handler_installed_for == client.id then return end
      handler_installed_for = client.id
      local original_handler = client.handlers['textDocument/publishDiagnostics']
      client.handlers['textDocument/publishDiagnostics'] = function(err, result, ctx, config)
        if original_handler then
          original_handler(err, result, ctx, config)
        else
          vim.lsp.diagnostic.on_publish_diagnostics(err, result, ctx)
        end

        if prompted then return end

        local found = false
        if not result or not result.diagnostics then return end
        for _, diagnostic in ipairs(result.diagnostics) do
          if diagnostic.message:match('non%-project file') or diagnostic.message:match('not on the classpath of project') then
            found = true
            break
          end
        end

        if not found then return end

        local bufnr = ctx.bufnr or vim.api.nvim_get_current_buf()

        prompted = true

        local filepath = vim.api.nvim_buf_get_name(bufnr)
        local src_needed = not vim.fs.root(filepath, { 'src' })

        vim.schedule(function()
          vim.ui.select(
            { 'Yes', 'No' },
            {
              prompt = "Current workspace is not a Java project.\n" ..
                       (src_needed and "If ok, the program will now create a " ..
                       "src folder and put this java file into it.\n" or "") ..
                       "Do you want to turn it into a Java project?"
            },
            function(choice)
              if choice ~= 'Yes' then
                client.handlers['textDocument/publishDiagnostics'] = original_handler or vim.lsp.diagnostic.on_publish_diagnostics
                return
              end

              if src_needed then
                local src_dir = vim.fs.joinpath(vim.fn.fnamemodify(filepath, ':h'), 'src')
                vim.fn.mkdir(src_dir, 'p')
                local new_path = vim.fs.joinpath(src_dir, vim.fn.fnamemodify(filepath, ':t'))
                vim.fn.rename(filepath, new_path)
                vim.cmd('edit ' .. vim.fn.fnameescape(new_path))
                vim.cmd('bdelete! ' .. bufnr)
                bufnr = vim.api.nvim_get_current_buf()
              end

              local root = vim.fs.root(vim.api.nvim_buf_get_name(bufnr), { 'src' })
              if not root then
                vim.notify('Could not determine project root.', vim.log.levels.ERROR)
                client.handlers['textDocument/publishDiagnostics'] = original_handler or vim.lsp.diagnostic.on_publish_diagnostics
                return
              end

              vim.fn.writefile({
                '<?xml version="1.0" encoding="UTF-8"?>',
                '<projectDescription>',
                '  <name>' .. vim.fs.basename(root) .. '</name>',
                '  <buildSpec><buildCommand><name>org.eclipse.jdt.core.javabuilder</name></buildCommand></buildSpec>',
                '  <natures><nature>org.eclipse.jdt.core.javanature</nature></natures>',
                '</projectDescription>',
              }, vim.fs.joinpath(root, '.project'))

              vim.fn.writefile({
                '<?xml version="1.0" encoding="UTF-8"?>',
                '<classpath>',
                '  <classpathentry kind="src" path="src"/>',
                '  <classpathentry kind="con" path="org.eclipse.jdt.launching.JRE_CONTAINER"/>',
                '  <classpathentry kind="output" path="bin"/>',
                '</classpath>',
              }, vim.fs.joinpath(root, '.classpath'))

              vim.notify('Java project files created. Restarting jdtls...')

              local orig_notify = vim.notify
              rawset(vim, 'notify', function(msg, ...)
                if type(msg) == 'string' and msg:match('exit code 143') then return end
                orig_notify(msg, ...)
              end)

              local orig_select = vim.ui.select
              rawset(vim.ui, 'select', function(items, opts, on_choice)
                if type(opts) == 'table' and opts.prompt and opts.prompt:match('delete') then
                  on_choice(items[1])
                else
                  orig_select(items, opts, on_choice)
                end
              end)

              local restored = false

              local reattach_id
              reattach_id = vim.api.nvim_create_autocmd('LspAttach', {
                callback = function(reattach_args)
                  local new_client = vim.lsp.get_client_by_id(reattach_args.data.client_id)
                  if not new_client or new_client.name ~= 'jdtls' then return end
                  vim.api.nvim_del_autocmd(reattach_id)
                  rawset(vim, 'notify', orig_notify)
                  rawset(vim.ui, 'select', orig_select)
                  restored = true
                  prompted = false
                  new_client.server_capabilities.semanticTokensProvider = semantic_tokens_capability
                end,
              })

              vim.cmd('JavaBuildCleanWorkspace')

              handler_installed_for = nil

              vim.defer_fn(function()
                if not restored then
                  rawset(vim, 'notify', orig_notify)
                  rawset(vim.ui, 'select', orig_select)
                  pcall(vim.api.nvim_del_autocmd, reattach_id)
                end
              end, 15000)
            end
          )
        end)
      end
    end
  })
end

return M
