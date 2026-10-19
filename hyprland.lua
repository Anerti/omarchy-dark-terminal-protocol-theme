local active_border_color = "rgba(2cae2eff)"
local inactive_border_color = "rgba(114116ff)"
local active_shadow_color = "rgba(2cae2e40)"
local inactive_shadow_color = "rgba(000000b8)"

hl.config({
  general = {
    col = {
      active_border = active_border_color,
      inactive_border = inactive_border_color,
    },
  },

  group = {
    col = {
      border_active = active_border_color,
      border_inactive = inactive_border_color,
    },

    groupbar = {
      text_color = "rgb(04160b)",
      text_color_inactive = "rgb(2cae2e)",
      col = {
        active = "rgba(2cae2eff)",
        inactive = "rgba(165717cc)",
      },
    },
  },

  decoration = {
    rounding = 4,

    shadow = {
      enabled = true,
      range = 20,
      render_power = 3,
      color = active_shadow_color,
      color_inactive = inactive_shadow_color,
    },
  },
})

local home = os.getenv("HOME") or ""
local crt_flag = io.open(home .. "/.local/state/omarchy/toggles/vault-tec-crt", "r")

if crt_flag then
  crt_flag:close()
  hl.config({
    decoration = {
      screen_shader = home .. "/.local/state/omarchy/current/theme/crt.frag",
    },
  })
end
