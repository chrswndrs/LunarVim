local M = {}

local Log = require "core.log"
local lsp_utils = require "lsp.utils"

function M.init_defaults(languages)
  for _, entry in ipairs(languages) do
    if not lvim.lang[entry] then
      lvim.lang[entry] = {
        formatters = {},
        linters = {},
      }
    end
  end
end

local function is_overridden(server)
  local overrides = lvim.lsp.override
  if type(overrides) == "table" then
    if vim.tbl_contains(overrides, server) then
      return
    end
  end
end

function M.setup_by_ft(server, default_config)
  vim.validate {
    name = { server.name, "string" },
    default_config = { default_config, "table" },
  }
  if lsp_utils.is_client_active(server) or is_overridden(server.name) then
    return
  end
  local status_ok, custom_config = pcall(require, "lsp/providers/" .. server.name)
  local new_config
  if status_ok then
    new_config = vim.tbl_deep_extend("keep", vim.empty_dict(), custom_config)
    new_config = vim.tbl_deep_extend("keep", new_config, default_config)
    -- Log:debug("Using custom configuration for server: " .. server.name .. "with .. \n" .. vim.inspect(new_config))
    --TODO: make sure these are actually applied
    server:setup(new_config)
  else
    -- Log:debug("Using the default configuration for server: " .. server.name)
    server:setup(default_config)
  end
  vim.cmd [[ do User LspAttachBuffers ]]
end

function M.ensure_configured(servers, default_config)
  default_config = default_config or require("lsp").get_common_opts()
  local status_ok, ls_installer = pcall(require, "nvim-lsp-installer")
  if not status_ok then
    return
  end
  local lsp_installer_servers = require "nvim-lsp-installer.servers"

  Log:debug("Loading " .. #servers .. " language(s): " .. vim.inspect(servers))
  for _, server in pairs(servers) do
    local ok, requested_server = lsp_installer_servers.get_server(server)
    if ok then
      if not requested_server:is_installed() then
        requested_server:install()
      end
    end
  end
  ls_installer.on_server_ready(function(server)
    M.setup_by_ft(server, default_config)
  end)
end

return M
