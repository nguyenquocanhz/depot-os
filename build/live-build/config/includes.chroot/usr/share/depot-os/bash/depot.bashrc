# Depot OS — shell tương tác: dấu nhắc gọn kiểu macOS + lời chào fastfetch (logo Bóng ma)
# ~/.bashrc gọi file này ở cuối (hook 0720), nên đè được PS1 mặc định của Debian.
# Tắt lời chào: touch ~/.config/depot/no-fetch   ·   Dùng lại dấu nhắc Debian: export DEPOT_PROMPT=0 trước dòng gọi file này
# By WrenEvil.tech & nguyenquocanhz (nqatech)
case $- in *i*) ;; *) return ;; esac

if [ "${DEPOT_PROMPT:-1}" = 1 ]; then
    # user@máy (xám) · thư mục (xanh) · nhánh git (tím) · ❯ (trắng; đỏ khi lệnh trước lỗi). Tiêu đề cửa sổ = thư mục.
    __depot_git() {
        local b
        b=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null) || return
        printf ' %s' "$b"
    }
    __depot_ps1() {
        local e=$? dim='\[\e[38;2;93;98;114m\]' dir='\[\e[38;2;111;154;216m\]' git='\[\e[38;2;199;155;242m\]' r='\[\e[0m\]'
        local arrow='\[\e[38;2;232;236;245m\]❯'
        [ $e -ne 0 ] && arrow='\[\e[38;2;255;45;61m\]❯'
        local g=''
        command -v git >/dev/null 2>&1 && g=$(__depot_git)
        PS1="\[\e]0;\w\a\]${dim}\u@\h ${dir}\w${git}${g}${r} ${arrow}${r} "
    }
    PROMPT_COMMAND="__depot_ps1${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
fi

# lời chào: mỗi cửa sổ/tab terminal mới một lần (shell lồng bên trong không in lại), không in qua SSH hay màn chữ
if [ -z "${DEPOT_FETCHED:-}" ] && [ -n "${DISPLAY:-}" ] && [ -z "${SSH_CONNECTION:-}" ] &&
   [ ! -e "${XDG_CONFIG_HOME:-$HOME/.config}/depot/no-fetch" ] && command -v fastfetch >/dev/null 2>&1 &&
   [ "$(tput cols 2>/dev/null || echo 80)" -ge 72 ]; then
    export DEPOT_FETCHED=1
    fastfetch 2>/dev/null
fi
