-------------------------------------------------
-- mpris based Arc Widget for Awesome Window Manager
-- Modelled after Pavel Makhov's work
-- @author Mohammed Gaber
-- requires - playerctl
-- @copyright 2020
-------------------------------------------------
local awful = require("awful")
local capi = {
  mouse = mouse,
  screen = screen,
}
local beautiful = require("beautiful")
local spawn = require("awful.spawn")
local watch = require("awful.widget.watch")
local timer = require("gears.timer")
local wibox = require("wibox")
local naughty = require("naughty")
local gears = require("gears")

local GET_MPD_CMD = "playerctl --player=%s -f '{{status}};{{xesam:artist}};{{xesam:title}};{{mpris:artUrl}}' metadata"

local TOGGLE_MPD_CMD = "playerctl --player=\"%s\" play-pause"
local PAUSE_MPD_CMD = "playerctl --player=\"%s\" pause"
local STOP_MPD_CMD = "playerctl --player=\"%s\" stop"
local NEXT_MPD_CMD = "playerctl --player=\"%s\" next"
local PREV_MPD_CMD = "playerctl --player=\"%s\" previous"
local LIST_PLAYERS_CMD = "playerctl -l"
local GET_CUR_PLAYER_CMD = "bash ~/.config/playerctl.sh"

local PATH_TO_ICONS = "/usr/share/icons/Arc"
local PAUSE_ICON_NAME = PATH_TO_ICONS .. "/actions/24/player_pause.png"
local PLAY_ICON_NAME = PATH_TO_ICONS .. "/actions/24/player_play.png"
local STOP_ICON_NAME = PATH_TO_ICONS .. "/actions/24/player_stop.png"
local LIBRARY_ICON_NAME = PATH_TO_ICONS .. "/actions/24/music-library.png"

local default_player = ''
local default_player_index = 0
local players_count = 0

local icon = wibox.widget {
  id = "icon",
  widget = wibox.widget.imagebox,
  image = PLAY_ICON_NAME
}

local mpris_widget = wibox.widget{
  icon,
  layout = wibox.layout.fixed.horizontal,
}

local rows  = { layout = wibox.layout.fixed.vertical }

local popup = awful.popup{
  bg = beautiful.bg_normal,
  ontop = true,
  visible = false,
  shape = gears.shape.rounded_rect,
  border_width = 1,
  border_color = beautiful.bg_focus,
  maximum_width = 400,
  offset = { y = 5 },
  widget = {}
}

local function rebuild_popup()
  for i = 0, #rows do rows[i]=nil end
  awful.spawn.easy_async(LIST_PLAYERS_CMD, function(stdout, _, _, _)
    local checkbox = wibox.widget{
      {
        checked       = default_player_index == 0,
        color         = beautiful.bg_normal,
        paddings      = 2,
        shape         = gears.shape.circle,
        forced_width = 20,
        forced_height = 20,
        check_color = beautiful.fg_urgent,
        widget        = wibox.widget.checkbox
      },
      valign = 'center',
      layout = wibox.container.place,
    }
    if player_name == default_player and default_player_index ~= 0 then
      default_player_index = players_count
    end

    checkbox:connect_signal("button::press", function()
      default_player_index = 0
      rebuild_popup()
      popup.visible = not popup.visible
    end)
    table.insert(rows, wibox.widget {
      {
        {
          checkbox,
          {
            {
              text = "Auto",
              align = 'left',
              widget = wibox.widget.textbox
            },
            left = 10,
            layout = wibox.container.margin
          },
          spacing = 8,
          layout = wibox.layout.align.horizontal
        },
        margins = 4,
        layout = wibox.container.margin
      },
      bg = beautiful.bg_normal,
      widget = wibox.container.background
    })
    if default_player_index == 0 then
      awful.spawn.easy_async_with_shell(GET_CUR_PLAYER_CMD, function(stdout, _, _, _)
        default_player = stdout
      end)
    end
    players_count = 1
    for player_name in stdout:gmatch("([^\n\r]+)") do
      if player_name ~='' or player_name ~=nil then
        local checkbox = wibox.widget{
          {
            checked       = (player_name == default_player and default_player_index ~= 0) or (players_count == default_player_index),
            color         = beautiful.bg_normal,
            paddings      = 2,
            shape         = gears.shape.circle,
            forced_width = 20,
            forced_height = 20,
            check_color = beautiful.fg_urgent,
            widget        = wibox.widget.checkbox
          },
          valign = 'center',
          layout = wibox.container.place,
        }
        if players_count == default_player_index then
          default_player = player_name
        end

        checkbox:connect_signal("button::press", function()
          default_player = player_name
          default_player_index = players_count
          rebuild_popup()
          popup.visible = not popup.visible
        end)
        table.insert(rows, wibox.widget {
          {
            {
              checkbox,
              {
                {
                  text = player_name,
                  align = 'left',
                  widget = wibox.widget.textbox
                },
                left = 10,
                layout = wibox.container.margin
              },
              spacing = 8,
              layout = wibox.layout.align.horizontal
            },
            margins = 4,
            layout = wibox.container.margin
          },
          bg = beautiful.bg_normal,
          widget = wibox.container.background
        })
        players_count = players_count + 1
      end
    end
    players_count = players_count - 1
    popup:setup(rows)
  end)
end

local function worker()

  -- retriving song info
  local current_song, artist, mpdstatus, art, artUrl
  local update_graphic = function(widget, stdout, _, _, _)
    -- mpdstatus, artist, current_song = stdout:match("(%w+)%;+(.-)%;(.*)")
    local words = {}
    for w in stdout:gmatch("([^;]+)") do table.insert(words, w) end

    mpdstatus = words[1]
    artist = words[2]
    current_song = words[3]
    art = words[4]

    if art ~= nil then 
      artUrl = art:match "^%s*(.-)%s*$" -- trim
    end

    if mpdstatus == "Playing" then
      icon.image = PLAY_ICON_NAME
      widget.colors = {beautiful.widget_main_color}
    elseif mpdstatus == "Paused" then
      icon.image = PAUSE_ICON_NAME
      widget.colors = {beautiful.widget_main_color}
    elseif mpdstatus == "Stopped" then
      icon.image = STOP_ICON_NAME
    else -- no player is running
      icon.image = LIBRARY_ICON_NAME
      widget.colors = {beautiful.widget_red}
    end
    rebuild_popup()
  end

  icon:connect_signal("button::release", function(_, _, _, button)
    if button == 1 then -- 左键点击
      -- 继续/暂停
      awful.spawn(string.format(TOGGLE_MPD_CMD, default_player), false)
      return
    end
    if button == 2 then -- 中键点击
      -- 快速切换当前Player
      rebuild_popup()
      if players_count == 0 then
        return
      end
      if default_player_index >= players_count then
        default_player_index = 0
      else
        default_player_index = default_player_index + 1
      end
      rebuild_popup()
      return
    end
    if button == 3 then -- 右键点击
      -- 选择当前Player
      if popup.visible then
        popup.visible = not popup.visible
      else
        rebuild_popup()
        popup:move_next_to(mouse.current_widget_geometry)
      end
      return
    end
    if button == 4 then -- 滚轮向上
      -- 上一曲
      awful.spawn(string.format(PREV_MPD_CMD, default_player), false)
      return
    end
    if button == 5 then -- 滚轮向下
      -- 下一曲
      awful.spawn(string.format(NEXT_MPD_CMD, default_player), false)
      return
    end
  end)

  local notification
  local function show_MPD_status()
    notification = naughty.notify {
      margin = 10,
      timeout = 0,
      hover_timeout = 0.5,
      screen = capi.mouse.screen,
      width = 800,
      height = 200,
      title = mpdstatus,
      text = "\"" .. current_song .. "\" <b>by</b> \"" .. artist .. "\"",
      icon = artUrl,
      icon_size = 300
    }
  end

  local t = timer { timeout = 1 }
  icon:connect_signal("mouse::enter", function()
    t:emit_signal("timeout")
    if current_song ~= nil and artist ~= nil then show_MPD_status() end
  end)
  icon:connect_signal("mouse::leave", function() naughty.destroy(notification) end)

  t:connect_signal("timeout", function()
    t:stop()
    spawn.easy_async(string.format(GET_MPD_CMD, "'" .. default_player .. "'"), function(stdout, stderr, exitreason, exitcode)
      update_graphic(mpris_widget, stdout, stderr, exitreason, exitcode)
      t:again()
    end)
  end)
  t:start()
  t:emit_signal("timeout")

  return mpris_widget

end

return setmetatable(mpris_widget, {__call = function(_, ...) return worker(...) end})
