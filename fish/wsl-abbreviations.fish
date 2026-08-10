# WSL の対話 session では Windows 側の 1Password / OpenSSH を使う。
# 各 .exe が利用できない環境では abbreviation を作らず、Linux 側の command を維持する。
if status is-interactive
    if type -q op.exe
        abbr --add --position command op op.exe
    end

    if type -q ssh.exe
        abbr --add --position command ssh ssh.exe
    end

    if type -q ssh-add.exe
        abbr --add --position command ssh-add ssh-add.exe
    end
end
