#!/bin/bash

# Set up the Vault-Tec look on top of the theme. It sets the theme and the cursors,
# then asks, with one yes/no question each, whether to use the Vault-Tec version or
# Omarchy's built-in one of:
#   - the menu: the Pip-Boy menu plugin,
#   - the bar: the workspaces wedge and every status panel plugin,
#   - the login: the Omarchy terminal boot screen (sudo, rebuilds the initramfs) and lock screen,
# and whether to turn on the CRT screen effect (scanlines and vignette, bin/vault-tec-crt).
# Nothing changes until the summary is confirmed. Built-in disables the plugins, which
# stay installed so switching back is quick, and returns the boot screen to Omarchy's own.
# It signs off with the Vault-Tec Omarchy logo.
#
# Usage: full-theme.sh            ask, then apply
#        full-theme.sh --status   show what is in use
#        full-theme.sh --unset    switch every part back to built-in and check that it took:
#                                 plugins and CRT effect off, Omarchy's menu, bar, boot and
#                                 lock screens on

ROOT="$(cd "$(dirname "$0")" && pwd)"
SELF="$ROOT/$(basename "$0")"
THEMES="$HOME/.config/omarchy/themes"
CURRENT="$HOME/.local/state/omarchy/current/theme"
ICONS="$HOME/.local/share/icons/VaultTec"
HOOKS="$HOME/.config/omarchy/hooks"
PLUGINS="$HOME/.config/omarchy/plugins"
SHELL_JSON="$HOME/.config/omarchy/shell.json"
BOOT_THEME=/usr/share/plymouth/themes/vault-tec
LOGO="$ROOT/logo/vaulttec-omarchy.svg"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/vault-tec"
LOG="$CACHE/full-theme.log"

# The palette (colors.toml).
GREEN="#2cae2e" BRIGHT="#d6ffe3" MUTED="#7c9480" AMBER="#ffcc33" RED="#ff5a3c" PANEL="#0c2a18"

# The theme's slug: the theme folder that is this checkout, else one named after it.
theme_slug() {
  local dir
  for dir in "$THEMES"/*/; do
    [[ $(realpath "$dir") == "$ROOT" ]] && { basename "$dir"; return; }
  done
  for dir in "$THEMES"/*dark-terminal-protocol*/; do
    [[ -d $dir ]] && { basename "$dir"; return; }
  done
}

THEME="${VAULT_TEC_THEME:-$(theme_slug)}"

plugin_ids() {
  for dir in "$ROOT"/plugins/*/; do basename "$dir"; done
}

# The plugins behind each question; the bar is everything else.
MENU_IDS=(anerti.menu)
LOGIN_IDS=(anerti.lock)
BAR_IDS=()
for id in $(plugin_ids); do
  [[ " ${MENU_IDS[*]} ${LOGIN_IDS[*]} " == *" $id "* ]] || BAR_IDS+=("$id")
done

current_theme() {
  cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null
}

theme_current() {
  [[ $(current_theme) == "$THEME" && -d $CURRENT ]] &&
    ! diff -rq --exclude='.*' "$ROOT" "$CURRENT" 2>/dev/null | grep -qv "^Only in $CURRENT"
}

current_cursor() {
  gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null | tr -d "'"
}

plugin_json() {
  omarchy plugin list --json 2>/dev/null || echo '[]'
}

# missing | enabled | disabled
plugin_state() {
  local json="$1" id="$2"
  [[ -d $PLUGINS/$id ]] || { echo missing; return; }
  jq -r --arg id "$id" 'first(.[] | select(.id == $id) | if .enabled then "enabled" else "disabled" end) // "disabled"' <<<"$json"
}

# The built-in a plugin replaces (manifest.json omarchy.clonedFrom).
builtin_of() {
  jq -r '.omarchy.clonedFrom // ""' "$ROOT/plugins/$1/manifest.json"
}

# Built-ins live outside $PLUGINS, so ask the shell directly.
builtin_enabled() {
  jq -e --arg id "$2" 'any(.[]; .id == $id and .enabled)' <<<"$1" >/dev/null
}

# vault (every plugin enabled) | builtin (none) | mixed
group_state() {
  local json="$1" id on=0 n=0
  shift
  for id; do
    ((n++))
    [[ $(plugin_state "$json" "$id") == enabled ]] && ((on++))
  done
  if ((on == n)); then echo vault
  elif ((on == 0)); then echo builtin
  else echo mixed
  fi
}

# Hooks are installed as copies, so a stale copy counts as not installed.
cursor_installed() {
  [[ -d $ICONS ]] &&
    cmp -s "$ROOT/hooks/vault-tec-cursor" "$HOOKS/theme-set.d/vault-tec-cursor" &&
    cmp -s "$ROOT/hooks/vault-tec-cursor" "$HOOKS/post-boot.d/vault-tec-cursor"
}

boot_active() {
  [[ $(plymouth-set-default-theme 2>/dev/null) == vault-tec ]]
}

# Active and the same as this checkout's build, so there is nothing to rebuild.
boot_current() {
  boot_active && diff -rq -x footer.png -x 'banner-*.png' "$ROOT/plymouth/vault-tec" "$BOOT_THEME" >/dev/null 2>&1
}

login_state() {
  local lock
  lock=$(group_state "$1" "${LOGIN_IDS[@]}")
  if boot_active && [[ $lock == vault ]]; then echo vault
  elif ! boot_active && [[ $lock == builtin ]]; then echo builtin
  else echo mixed
  fi
}

# Plugin display names without the brand, joined: "workspaces, clock, ...".
plugin_names() {
  local id names=()
  for id; do
    names+=("$(jq -r '.name | sub("^Vault-Tec "; "")' "$ROOT/plugins/$id/manifest.json")")
  done
  local IFS=,
  echo "${names[*]}" | sed 's/,/, /g'
}

#--------------------------------------------- Steps ---------------------------------
# Each runs from step() through "$SELF __run", its output going to the log.

set_theme() {
  theme_current || omarchy theme set "$THEME"
}

set_cursors() {
  if cursor_installed; then
    "$ROOT/hooks/vault-tec-cursor" "$THEME"
  else
    "$ROOT/bin/vault-tec-cursor" install
  fi
}

# Install the given plugins, or update them; vault-tec-plugins enables new ones.
install_plugins() {
  "$ROOT/bin/vault-tec-plugins" install "$@"
}

# set_plugins on|off id...
set_plugins() {
  local want="$1" json id st
  shift
  json=$(plugin_json)
  for id; do
    st=$(plugin_state "$json" "$id")
    if [[ $want == on && $st == disabled ]]; then
      omarchy plugin enable "$id" || return
    elif [[ $want == off && $st == enabled ]]; then
      omarchy plugin disable "$id" || return
    fi
  done
}

# Lay the bar out for one menu or the other; the right side is left alone.
#   vault:   the wedge alone in the centre, anchored there, and every other left or
#            centre widget (clock, weather, indicators...) on the left.
#   builtin: Omarchy's menu button and workspaces alone on the left, and every other
#            widget in the centre, anchored on the clock when there is one.
# Enabling or disabling a clone only swaps its id where it sits, and the wedge stands in
# for the menu button too, so the layout is set here. The menu button is placed only with
# the built-in menu: omarchy.menu is both, and is off while the Pip-Boy menu is in use.
# Usage: place_bar vault | place_bar builtin [on|off: the Pip-Boy menu]
place_bar() {
  local layout="$1" pipboy="${2:-off}"
  (
    source omarchy-shell-config
    commit "$NORMALIZE
      | ((.bar.layout.left + .bar.layout.center)
          | map(select(.id | IN(\"omarchy.menu\", \"omarchy.workspaces\", \"anerti.workspaces\") | not))) as \$rest
      | if \$layout == \"vault\" then
          .bar.layout.left = \$rest
          | .bar.layout.center = [{id: \"anerti.workspaces\"}]
          | .bar.centerAnchor = \"anerti.workspaces\"
        else
          .bar.layout.left = (if \$pipboy == \"on\" then [] else [{id: \"omarchy.menu\"}] end)
            + [{id: \"omarchy.workspaces\"}]
          | .bar.layout.center = \$rest
          | .bar.centerAnchor = (first(\$rest[].id | select(endswith(\".clock\"))) // \"\")
        end" --arg layout "$layout" --arg pipboy "$pipboy"
  )
}

# The layout place_bar builtin makes: only the menu button (unless the Pip-Boy menu is in
# use) and workspaces on the left, and no Vault-Tec widget or anchor anywhere.
bar_is_builtin() {
  jq -e --arg pipboy "${1:-off}" '
    (if $pipboy == "on" then ["omarchy.workspaces"] else ["omarchy.menu", "omarchy.workspaces"] end) as $want
    | [.bar.layout.left[]?.id] == $want
    and ([.bar.layout[][]?.id] | any(startswith("anerti.")) | not)
    and ((.bar.centerAnchor // "") | startswith("anerti.") | not)
  ' "$SHELL_JSON" >/dev/null 2>&1
}

set_boot() {
  if [[ $1 == on ]]; then
    boot_current || "$ROOT/bin/vault-tec-plymouth" install
  elif [[ -d $BOOT_THEME ]]; then
    "$ROOT/bin/vault-tec-plymouth" uninstall
  fi
}

# Enable the built-in behind each given plugin if the shell did not bring it back when
# the plugin was disabled.
enable_builtins() {
  local json id source
  json=$(plugin_json)
  for id; do
    source=$(builtin_of "$id")
    [[ -z $source ]] || builtin_enabled "$json" "$source" || omarchy plugin enable "$source" || return
  done
}

# Restart the shell and wait until it answers again, so its plugin list is current.
restart_shell() {
  omarchy restart shell || return
  for _ in {1..20}; do
    sleep 0.5
    [[ $(plugin_json) != "[]" ]] && return
  done
  return 1
}

#--------------------------------------------- TUI -----------------------------------

esc() {
  local h=${1#\#}
  printf '\e[38;2;%d;%d;%dm' "0x${h:0:2}" "0x${h:2:2}" "0x${h:4:2}"
}

C_GREEN=$(esc "$GREEN") C_BRIGHT=$(esc "$BRIGHT") C_MUTED=$(esc "$MUTED")
C_AMBER=$(esc "$AMBER") C_RED=$(esc "$RED") BOLD=$'\e[1m' RESET=$'\e[0m'

export GUM_CONFIRM_PROMPT_FOREGROUND="$BRIGHT"
export GUM_CONFIRM_SELECTED_FOREGROUND="#06170d" GUM_CONFIRM_SELECTED_BACKGROUND="$GREEN"
export GUM_CONFIRM_UNSELECTED_FOREGROUND="$MUTED" GUM_CONFIRM_UNSELECTED_BACKGROUND="$PANEL"
export GUM_SPIN_SPINNER_FOREGROUND="$GREEN" GUM_SPIN_TITLE_FOREGROUND="$BRIGHT"

WIDTH=64
FAILED=()

banner() {
  clear
  gum style --border double --border-foreground "$GREEN" --align center --width "$WIDTH" \
    --padding "1 2" --margin "1 2 0 2" \
    "$(gum style --foreground "$BRIGHT" --bold "OMARCHY QUATTRO")" \
    "$(gum style --foreground "$GREEN" "OMARCHY TERMINAL  ·  $1")"
}

# Wrapped muted text, indented like the cards.
note() {
  gum style --foreground "$MUTED" --width "$WIDTH" --margin "0 4" "$@"
}

heading() {
  printf '\n  %s%s%s  %s%s%s%s\n' "$C_AMBER" "$1" "$RESET" "$BOLD" "$C_BRIGHT" "$2" "$RESET"
}

cancelled() {
  printf '\n  %s%s%s\n\n' "$C_MUTED" "${1:-Setup cancelled. No changes were made.}" "$RESET"
  exit 130
}

# confirm <default yes|no> <prompt> [affirmative] [negative]: 0 yes, 1 no; Ctrl+C cancels.
confirm() {
  local rc
  gum confirm --default="$([[ $1 == yes ]] && echo true || echo false)" \
    --affirmative "${3:-Yes}" --negative "${4:-No}" --padding "0 4" "$2"
  rc=$?
  ((rc == 130)) && cancelled
  return "$rc"
}

describe() {
  case "$1" in
    vault) echo "Vault-Tec" ;;
    builtin) echo "Built-in" ;;
    on) echo "On" ;;
    off) echo "Off" ;;
    *) echo "Mixed" ;;
  esac
}

# ask <n> <title> <state> <prompt> <vault label> <built-in label> <description...>
# Sets ANSWER to on or off and records the line left on screen.
ask() {
  local n="$1" title="$2" state="$3" prompt="$4" yes="$5" no="$6" default=yes
  shift 6
  heading "[$n/4]" "$title"
  note "$@" "" "Currently: $(describe "$state")"
  [[ $state == builtin || $state == off ]] && default=no
  printf '\n'
  if confirm "$default" "$prompt"; then ANSWER=on; else ANSWER=off; fi
  if [[ $ANSWER == on ]]; then
    printf '    %s›%s %s\n' "$C_GREEN" "$RESET" "$yes"
  else
    printf '    %s›%s %s\n' "$C_GREEN" "$RESET" "$no"
  fi
}

# step <title> <function> [args...]: runs it under a spinner, then leaves a ✓ or ✗ line.
step() {
  local title="$1"
  shift
  printf '\n=== %s\n' "$title" >>"$LOG"
  if gum spin --spinner minidot --title " $title..." -- bash "$SELF" __run "$@"; then
    printf '  %s✓%s %s\n' "$C_GREEN" "$RESET" "$title"
  else
    printf '  %s✗%s %s %s(see the log)%s\n' "$C_RED" "$RESET" "$title" "$C_MUTED" "$RESET"
    FAILED+=("$title")
  fi
}

# Ask for the password up front: the steps run under a spinner, which hides prompts.
sudo_ready() {
  heading "!" "Administrator rights"
  note "The boot screen is changed system-wide and the initramfs is rebuilt."
  printf '\n'
  sudo -v -p "    Password for %u: " || cancelled "Setup cancelled: administrator rights are needed."
}

#--------------------------------------------- Logo ----------------------------------
# logo/vaulttec-omarchy.svg as truecolor half-block art: two pixels per cell, its alpha
# blended from the background to the phosphor green, cached per width. Each row is also
# kept in bright phosphor for the beam that draws it in.

logo_art() {
  local w="$1" file="$CACHE/logo-$1.ansi" h
  if [[ ! -s $file || $LOGO -nt $file || $SELF -nt $file ]]; then
    h=$(((w * 360 / 930 + 1) / 2 * 2))
    mkdir -p "$CACHE"
    magick -background none -density 300 "$LOGO" -resize "${w}x${h}!" -alpha extract \
      -depth 8 txt:- 2>/dev/null | awk -v w="$w" -v h="$h" '
      function col(t, r, g, b) {
        return sprintf("%d;%d;%d", 6 + (r - 6) * t, 23 + (g - 23) * t, 13 + (b - 13) * t)
      }
      function rows(r, g, b,   x, y, t, u, line) {
        for (y = 0; y < h; y += 2) {
          line = ""
          for (x = 0; x < w; x++) {
            t = a[x, y]; u = a[x, y + 1]
            if (t < 0.12 && u < 0.12) line = line "\033[0m "
            else if (u < 0.12) line = line "\033[0;38;2;" col(t, r, g, b) "m▀"
            else if (t < 0.12) line = line "\033[0;38;2;" col(u, r, g, b) "m▄"
            else line = line "\033[0;38;2;" col(t, r, g, b) ";48;2;" col(u, r, g, b) "m▀"
          }
          print line "\033[0m"
        }
      }
      /^#/ { next }
      {
        split($1, xy, /[,:]/)
        v = $2; gsub(/[()]/, "", v); split(v, c, ",")
        a[xy[1], xy[2]] = c[1] / 255
      }
      END { rows(44, 174, 46); rows(214, 255, 227) }' >"$file.tmp" && mv "$file.tmp" "$file"
  fi
  [[ -s $file ]] && echo "$file"
}

# The logo's width for this terminal; 0 if it is too small.
logo_width() {
  local w=$(($(tput cols) - 8))
  ((w > 96)) && w=96
  ((w < 40 || $(tput lines) < 20)) && w=0
  echo "$w"
}

# Draws the logo a row at a time under a bright beam, like a CRT warming up; any key
# finishes it at once.
play_logo() {
  local w="$1" file="$2" lines rows pad i fast=
  mapfile -t lines <"$file"
  rows=$((${#lines[@]} / 2))
  pad=$((($(tput cols) - w) / 2))
  printf '\e[?25l'
  for ((i = 0; i < rows; i++)); do
    if [[ -z $fast ]]; then
      printf '%*s%s\n' "$pad" '' "${lines[rows + i]}"
      read -rsn1 -t 0.05 && fast=1
      printf '\e[1A'
    fi
    printf '%*s%s\n' "$pad" '' "${lines[i]}"
  done
  printf '\e[?25h'
}

# sign_off <title> <lines...>
sign_off() {
  local w file
  clear
  printf '\n\n'
  w=$(logo_width)
  if ((w)) && file=$(logo_art "$w"); then
    play_logo "$w" "$file"
  fi
  printf '\n'
  gum style --align center --width "$(tput cols)" --foreground "$GREEN" --bold "$1"
  shift
  gum style --align center --width "$(tput cols)" --foreground "$MUTED" "$@"
  if ((${#FAILED[@]})); then
    printf '\n'
    gum style --align center --width "$(tput cols)" --foreground "$RED" \
      "Did not complete: $(printf '%s; ' "${FAILED[@]}" | sed 's/; $//')." "Details: $LOG"
  fi
  printf '\n'
}

#--------------------------------------------- Commands ------------------------------

status() {
  local json crt
  json=$(plugin_json)
  crt=$("$ROOT/bin/vault-tec-crt" status)

  row() {
    local mark="$C_MUTED·$RESET"
    [[ $2 == ok ]] && mark="$C_GREEN✓$RESET"
    printf '  %s %-14s %s\n' "$mark" "$1" "$3"
  }

  printf '\n  %s%sVAULT-TEC%s %s· status%s\n\n' "$BOLD" "$C_GREEN" "$RESET" "$C_MUTED" "$RESET"
  local changed=
  [[ $(current_theme) == "$THEME" ]] && ! theme_current && changed=", changed since it was set"
  row Theme "$(theme_current && echo ok)" "$(current_theme) (this theme: ${THEME:-not installed}$changed)"
  row Cursors "$(cursor_installed && [[ $(current_cursor) == VaultTec ]] && echo ok)" \
    "$(current_cursor)$(cursor_installed || echo ", VaultTec not installed")"
  local s
  s=$(group_state "$json" "${MENU_IDS[@]}")
  row Menu "$([[ $s == vault ]] && echo ok)" "$(describe "$s")"
  s=$(group_state "$json" "${BAR_IDS[@]}")
  row Bar "$([[ $s == vault ]] && echo ok)" "$(describe "$s")"
  s=$(login_state "$json")
  row Login "$([[ $s == vault ]] && echo ok)" \
    "$(describe "$s") (boot screen: $(plymouth-set-default-theme 2>/dev/null), lock screen: $(describe "$(group_state "$json" "${LOGIN_IDS[@]}")"))"
  row "CRT shader" "$([[ $crt == on ]] && echo ok)" "$crt (optional, bin/vault-tec-crt)"
  printf '\n'
}

setup() {
  [[ -n $THEME ]] || { echo "No dark-terminal-protocol theme in $THEMES; see README.md › Installation" >&2; exit 1; }

  local json menu bar login crt

  json=$(plugin_json)
  banner "THEME CONFIGURATION"
  printf '\n'
  note "Choose, for each part of the desktop, the Vault-Tec version or Omarchy's built-in one. The theme and the VaultTec cursors are always applied." \
    "" "Nothing changes until you confirm the summary. Press Ctrl+C at any time to cancel."

  ask 1 "Menu" "$(group_state "$json" "${MENU_IDS[@]}")" \
    "Use the Vault-Tec Pip-Boy menu?" "Vault-Tec Pip-Boy menu" "Built-in Omarchy menu" \
    "Super + Space opens the Pip-Boy menu in place of the Omarchy menu."
  menu=$ANSWER

  ask 2 "Bar" "$(group_state "$json" "${BAR_IDS[@]}")" \
    "Use the Vault-Tec bar, with every Vault-Tec panel?" "Vault-Tec bar" "Built-in bar" \
    "The bar's widgets are replaced by their Vault-Tec versions: $(plugin_names "${BAR_IDS[@]}")."
  bar=$ANSWER

  ask 3 "Login" "$(login_state "$json")" \
    "Use the Vault-Tec login screens?" "Vault-Tec boot and lock screens" "Built-in boot and lock screens" \
    "The Omarchy terminal boot screen, where the disk passphrase is entered at power-on, and the matching lock screen." \
    "Changing the boot screen requires administrator rights and rebuilds the initramfs."
  login=$ANSWER

  ask 4 "CRT effect" "$("$ROOT/bin/vault-tec-crt" status)" \
    "Turn on the CRT screen effect?" "CRT effect on" "CRT effect off" \
    "Scanlines and a vignette over the whole screen, like an old CRT terminal's glass. It is a Hyprland screen shader, so it also shows in screenshots and recordings."
  crt=$ANSWER

  heading "»" "Summary"
  printf '\n'
  summary_row() {
    printf '    %-8s %s%s%s\n' "$1" "$C_BRIGHT" "$([[ $2 == on ]] && echo "$3" || echo "$4")" "$RESET"
  }
  summary_row Theme on "Dark Terminal Protocol, VaultTec cursors"
  summary_row Menu "$menu" "Vault-Tec Pip-Boy menu" "Built-in Omarchy menu"
  summary_row Bar "$bar" "Vault-Tec bar" "Built-in bar"
  summary_row Login "$login" "Vault-Tec boot and lock screens" "Built-in boot and lock screens"
  summary_row CRT "$crt" "CRT effect on" "CRT effect off"
  printf '\n'
  confirm yes "Apply this configuration?" "Apply" "Cancel" || cancelled

  if [[ $login == on ]] && ! boot_current || [[ $login == off && -d $BOOT_THEME ]]; then
    sudo_ready
  fi

  mkdir -p "$CACHE"
  : >"$LOG"
  heading "»" "Applying"
  printf '\n'
  step "Setting the Dark Terminal Protocol theme" set_theme
  step "Applying the VaultTec cursors" set_cursors

  local want=()
  [[ $menu == on ]] && want+=("${MENU_IDS[@]}")
  [[ $bar == on ]] && want+=("${BAR_IDS[@]}")
  [[ $login == on ]] && want+=("${LOGIN_IDS[@]}")
  ((${#want[@]})) && step "Installing the Vault-Tec plugins" install_plugins "${want[@]}"

  local off=()
  if [[ $menu == on ]]; then
    step "Enabling the Pip-Boy menu" set_plugins on "${MENU_IDS[@]}"
  else
    step "Restoring the built-in menu" set_plugins off "${MENU_IDS[@]}"
    off+=("${MENU_IDS[@]}")
  fi

  if [[ $bar == on ]]; then
    step "Enabling the Vault-Tec bar" set_plugins on "${BAR_IDS[@]}"
  else
    step "Restoring the built-in bar" set_plugins off "${BAR_IDS[@]}"
    off+=("${BAR_IDS[@]}")
  fi

  if [[ $login == on ]]; then
    step "Enabling the Vault-Tec lock screen" set_plugins on "${LOGIN_IDS[@]}"
    step "Installing the Vault-Tec boot screen" set_boot on
  else
    step "Restoring the built-in lock screen" set_plugins off "${LOGIN_IDS[@]}"
    step "Restoring the built-in boot screen" set_boot off
    off+=("${LOGIN_IDS[@]}")
  fi

  ((${#off[@]})) && step "Enabling the built-ins they replace" enable_builtins "${off[@]}"
  if [[ $bar == on ]]; then
    step "Centring the Vault-Tec wedge in the bar" place_bar vault
  else
    step "Moving the menu and workspaces to the left of the bar" place_bar builtin "$menu"
  fi

  if [[ $crt == on ]]; then
    step "Turning on the CRT effect" "$ROOT/bin/vault-tec-crt" on
  else
    step "Turning off the CRT effect" "$ROOT/bin/vault-tec-crt" off
  fi

  step "Restarting the Omarchy shell" restart_shell

  sign_off "WELCOME HOME, OPERATOR" \
    "Your Vault-Tec configuration is in place." \
    "Run full-theme.sh again to change it, or full-theme.sh --unset to go back to Omarchy's built-ins."
}

# Prints one line per check and returns 1 if any failed.
verify_unset() {
  local json id source failed=0
  json=$(plugin_json)

  check() {
    if [[ $2 == ok ]]; then
      printf '  %s✓%s %s\n' "$C_GREEN" "$RESET" "$1"
    else
      printf '  %s✗%s %s %s(%s)%s\n' "$C_RED" "$RESET" "$1" "$C_MUTED" "$2" "$RESET"
      failed=1
      FAILED+=("$1")
    fi
  }

  for id in $(plugin_ids); do
    [[ $(plugin_state "$json" "$id") == enabled ]] &&
      check "$id is off" "still enabled" || check "$id is off" ok
  done
  for id in "${MENU_IDS[@]}" "${BAR_IDS[@]}" "${LOGIN_IDS[@]}"; do
    source=$(builtin_of "$id")
    [[ -n $source ]] || continue
    builtin_enabled "$json" "$source" && check "$source is on" ok || check "$source is on" "still disabled"
  done
  bar_is_builtin && check "Menu button and workspaces on the left of the bar" ok ||
    check "Menu button and workspaces on the left of the bar" "layout still Vault-Tec"
  boot_active && check "Boot screen is Omarchy's" "vault-tec is still the default" ||
    check "Boot screen is Omarchy's" ok
  [[ $("$ROOT/bin/vault-tec-crt" status) == on ]] && check "CRT effect is off" "still on" ||
    check "CRT effect is off" ok
  return "$failed"
}

unset_all() {
  banner "RESTORE BUILT-INS"
  printf '\n'
  note "This switches every Vault-Tec part back to Omarchy's built-in one:" \
    "" \
    "  · menu: the Omarchy menu replaces the Pip-Boy menu" \
    "  · bar: the built-in widgets replace every Vault-Tec panel, with the menu button and workspaces back on the left" \
    "  · login: Omarchy's boot screen (administrator rights, rebuilds the initramfs)" \
    "  · unlock: Omarchy's lock screen" \
    "  · CRT effect: turned off" \
    "" \
    "The plugins stay installed but disabled. The theme and cursors are left as they are. Everything is checked afterwards."
  printf '\n'
  confirm yes "Restore Omarchy's built-ins?" "Restore" "Cancel" || cancelled "Cancelled. No changes were made."

  [[ -d $BOOT_THEME ]] && sudo_ready

  mkdir -p "$CACHE"
  : >"$LOG"
  heading "»" "Restoring"
  printf '\n'
  step "Restoring the built-in Omarchy menu" set_plugins off "${MENU_IDS[@]}"
  step "Restoring the built-in bar" set_plugins off "${BAR_IDS[@]}"
  step "Restoring the built-in lock screen" set_plugins off "${LOGIN_IDS[@]}"
  step "Restoring the built-in boot screen" set_boot off
  step "Enabling any built-in left off" enable_builtins "${MENU_IDS[@]}" "${BAR_IDS[@]}" "${LOGIN_IDS[@]}"
  step "Moving the menu and workspaces to the left of the bar" place_bar builtin
  step "Turning off the CRT effect" "$ROOT/bin/vault-tec-crt" off
  step "Restarting the Omarchy shell" restart_shell

  heading "»" "Verifying"
  printf '\n'
  verify_unset

  if ((${#FAILED[@]})); then
    sign_off "BUILT-INS PARTLY RESTORED" \
      "Run full-theme.sh --unset again, or full-theme.sh --status to see what is in use."
  else
    sign_off "OMARCHY BUILT-INS RESTORED" \
      "Every Vault-Tec plugin and the CRT effect are off; Omarchy's menu, bar, boot and lock screens are in use." \
      "Run full-theme.sh at any time to set Vault-Tec up again."
  fi
}

case "${1:-}" in
  __run)
    shift
    "$@" >>"$LOG" 2>&1
    ;;
  --status) status ;;
  --unset | "")
    for tool in gum jq; do
      command -v "$tool" >/dev/null || { echo "full-theme.sh needs $tool" >&2; exit 1; }
    done
    [[ -t 0 && -t 1 ]] || { echo "full-theme.sh asks questions: run it in a terminal" >&2; exit 1; }
    trap 'printf "\e[?25h"' EXIT
    if [[ $1 == --unset ]]; then unset_all; else setup; fi
    ;;
  -h | --help)
    sed -n '3,18p' "$SELF" | sed 's/^# \{0,1\}//'
    ;;
  *)
    echo "Usage: full-theme.sh [--status|--unset|--help]" >&2
    exit 1
    ;;
esac
