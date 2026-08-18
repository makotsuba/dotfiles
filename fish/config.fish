# マシン固有の設定（バージョンマネージャの init、社内 CA バンドルなど）は
# ここに書かず ~/.config/fish/conf.d/local.fish（非トラッキング）に置く。
# conf.d は config.fish の内容と無関係に fish が自動 source するため、
# install.sh --components shell で config.fish を差し替えても影響を受けない。

# Terminal.app から起動した別アプリへ専用設定を持ち込まない。
# 非対話 fish でも実行し、VS Code automation などに引き継がれた専用環境変数を解除する。
if test "$TERM_PROGRAM" != Apple_Terminal
    if test "$FISH_STARSHIP_CONFIG_APPLE_TERMINAL" = 1
        set -e STARSHIP_CONFIG
        set -e FISH_STARSHIP_CONFIG_APPLE_TERMINAL
    end
end

if status is-interactive
    if test -x /opt/homebrew/bin/brew
        eval (/opt/homebrew/bin/brew shellenv fish)
    end

    if test (uname) = Darwin
        set -gx LANG ja_JP.UTF-8
    end

    if type -q starship
        if test "$TERM_PROGRAM" = Apple_Terminal
            if not set -q STARSHIP_CONFIG
                # Terminal.app は背景なしのミニマル表示を使う。
                set -gx STARSHIP_CONFIG "$HOME/.config/starship-terminal.toml"
                set -gx FISH_STARSHIP_CONFIG_APPLE_TERMINAL 1
            end
        end

        starship init fish | source
    end

    abbr --add gpf 'git push --force-with-lease --force-if-includes'

    # WSL では Windows 側の 1Password / OpenSSH を対話コマンドに使う。
    # conf.d は非対話 fish でも読まれるため、ここから明示的に読み込む。
    if test -r /proc/version
        if command grep -qi microsoft /proc/version
            if test -r "$HOME/.config/fish/wsl-abbreviations.fish"
                source "$HOME/.config/fish/wsl-abbreviations.fish"
            end
        end
    end
end
