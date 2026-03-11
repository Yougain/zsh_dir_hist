# for zsh

dbv
require zsh_wrap
dbv


require temp_path zsh_rb colors fpath prompt zed history


export ZLTMPD="$(temp_path zltmpd)"
mkdir -p "$ZLTMPD"


def_ruby '
	def __first_cmd c = nil
		if !c
			"__nocmd__"
		else
			data = c.strip
			arr = data.split
			progList = %W{vi vim ruby perl python supervise sv service sudo sh bash zsh rpm rpmbuild}
			cmdl = []
			arr.each do |e|
				next if progList.include? File.basename(e)
				next if e =~ /^\-/
				cmdl.push File.basename(e)
			end
			if data =~ /^(scr|\/usr\/bin\/scr|resu|resudo)(\s|$)/
				"__nocmd__"
			else
				cmdl.join(" ")
			end
		end
	end
'

def_ruby '
	def __clear_prev__ tmp
		require "Yk/path_aux"
		["cmd", "idle", "cmd-before"].each do |e|
			"#{ENV['ZLTMPD']}/#{e}.*".glob.each do |f|
				if f =~ /#{Regexp.escape e}.(\d+)/
					if !"/proc/#{tmp.to_i}".exist?
						f.unlink
					end
				end
			end
		end
	end
'
__clear_prev__ $$


autoload -Uz add-zsh-hook

hist_preexec() {
	local cmd
	__first_cmd $1
	cmd=$__first_cmd
	if [ "$cmd" != "__nocmd__" ]; then
		case $TERM in
		xterm*)
			echo -ne "\033]0;$cmd (${HOST%%.*}/`date +%H:%M:%S`)"; echo -ne "\007"
		    ;;
		screen)
			echo -ne "\033_$cmd (${HOST%%.*}/`date +%H:%M:%S`)"; echo -ne "\033\\"
		    ;;
		esac
		if [ -e "$ZLTMPD/cmd" ]; then
			mv -f "$ZLTMPD/cmd" "$ZLTMPD/cmd-before"
		fi
		echo -ne $1 > "$ZLTMPD/cmd"
		rm -f "$ZLTMPD/idle"
	fi
}
add-zsh-hook preexec hist_preexec

hist_precmd() {
	precmd_called=1
	on_reset_editor
	echo -ne > "$ZLTMPD/idle"
}
add-zsh-hook precmd hist_precmd

ST_hist=1 hist_preexec
ST_hist=0

resu() {
	/bin/su -c "if [ -e $ZLTMPD/cmd ]; then ( zsh -c 'cat $ZLTMPD/cmd;echo' >> ~/.zsh_history;zsh -l $ZLTMPD/cmd ); fi;exec zsh -l"
}
resudo() {
	if [ -e "$ZLTMPD/cmd" ]; then
		__sudo `cat "$ZLTMPD/cmd"`
	fi
}






current_jiffies(){
	printf "%010d" `sh -c 'awk '"'"'{print $22}'"'"' /proc/$$/stat'`
}

session_id(){
	local bt=$(printf "%010d" $SYS_BOOT_ID)
	local jiffies=$(printf "%012d" $(awk '{print $22}' /proc/$$/stat))
	local pid=$(printf "%08d" $$)
	echo -n "${bt}${pid}${jiffies}" # 30 digits
}

SID=$(session_id)

last_hist_entry(){
	fc -l -1 -1 | sed -E 's/^[[:space:]]*[0-9]+\*?[[:space:]]+//'
}

remove_last_hist_entry(){
	local last_hno="`fc -l -1 -1 | awk '{print $1}'`"
	history -d $last_hno
}

get_cmd_from_hist_entry(){
	local entry="$1"
	local cmd="${entry%;$CMD_MDATA_START *}"
	echo -n "$cmd"
}

get_wd_from_hist_entry(){
	local entry="$1"
	local decoded
	decoded="$(decode_suffix_from_hist_entry "$entry")"
	if [ -z "$decoded" ]; then
		echo -n ""
		return
	fi
	local wd="${decoded%%$CMD_MDATA_SEP*}"
	echo -n "$wd"
}

get_sid_from_hist_entry(){
	local entry="$1"
	local decoded
	decoded="$(decode_suffix_from_hist_entry "$entry")"
	if [ -z "$decoded" ]; then
		echo -n ""
		return
	fi
	if [[ "$decoded" == *"$CMD_MDATA_SEP"* ]]; then
		echo -n "${decoded#*$CMD_MDATA_SEP}"
	else
		echo -n ""
	fi
}

on_prexec(){
	# no need to remove duplicated entries here because of setopt hist_ignore_dups
}


on_reset_editor(){ # called on precmd
	local last_entry=$(last_hist_entry)
	local last_cmd="$(get_cmd_from_hist_entry "$last_entry")"

	# Remove last history entry if it is empty command
	if [ "$last_cmd" = "" ]; then
		remove_last_hist_entry
	fi

	CPWD=$PWD
	hist_dir_arr=()
	hist_dir_arr_idx=
	orig_work_dir=
	zsh_d_size_max=
	ALL_BUFFER=
	if [ -n "$interrupted" -o "$is_nullbuff" ]; then
		interrupted=
		is_nullbuff=
		reset_prompt -n
	fi
}

tilderize_path(){
	local p="$1"
	if [[ "$p" = "$HOME/"* ]];then
		p="~/${p#"$HOME/"}"
	elif [ "$p" = "$HOME" ];then
		p="~"
	fi
	echo -n "$p"
}

tilda_size(){
	local p="$1"
	local sz
	if [[ "$p" = "$HOME/"* ]];then
		sz=$((${#p} - ${#HOME} + 1))
	elif [ "$p" = "$HOME" ];then
		sz=1
	else
		sz=${#p}
	fi
	echo -n "$sz"
}

max_multi(){
	local max=0
	local v
	for v in "$@";do
		if [ -n "$v" ];then
			if ((v > max)); then
				max=$v
			fi
		fi
	done
	echo -n "$max"
}

pwd_tilda_size=$(tilda_size "$PWD")

getEmbodymentString(){
	local s="$1"
	local ps=$(print -r -- "$(print -P "$s")" | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g')
	echo -n "$ps"
}

getSpaces(){
	spaces=$(printf '%*s' "$1" '')
	echo -n "$spaces"
}

PROMPT_before="${bold_start}[$mode_color%n@%m %{$fg[yellow]%}%~%{${reset_color}%}${bold_start}"
PROMPT_after="]${prompt_symbol_with_color}$bold_end "



reset_space(){
	prompt_before_embodyment=$(getEmbodymentString $PROMPT_before)
	prompt_pre_sz=$((${#prompt_before_embodyment} - pwd_tilda_size))
	local prompt_after_embodyment=$(getEmbodymentString $PROMPT_after)
	local prompt_post_sz=${#prompt_bafter_embodyment}
	ocaption="orig work dir "
	pre_space="$ocaption$(getSpaces $((prompt_pre_sz - 1 - ${#ocaption})))"
	post_space=$(getSpaces $((prompt_post_sz - 1)))
}


reset_space


reset_prompt() {
	if [ "$1" = "-n" ];then
		local no_zle=1
		shift
	fi
	local szm="$zsh_d_size_max"
	local orgPwd="$1"
	local sz=$(tilda_size "$PWD")
	local osz
	local padd=0
	local spaces=""
	local pre_prompt=""
	if [ -n "$orgPwd" ];then
		orgPwd=$(tilderize_path "$orgPwd")
		osz=${#orgPwd}
	fi
	zsh_d_size_max=$(max_multi "$sz" "$osz" "$szm")
	szm="$zsh_d_size_max"
	padd=$((szm - sz))
	spaces=$(getSpaces "$padd")
	local nprompt="${PROMPT_before}${spaces}${PROMPT_after}"
	if [ -n "$orgPwd" ] ;then
		local opadd=$((szm - osz))
		local ospaces=$(getSpaces "$opadd")
		pre_prompt="(${pre_space}%F{magenta}${orgPwd}${ospaces}%f)${post_space}
"
	fi
	PROMPT="${pre_prompt}${nprompt}"
	if [ -z "$no_zle" ];then
		zle reset-prompt
	fi
	#if [ -n "$orgPwd" ] ;then
	#	local savecur=$CURSOR
	#	local savebuf=$BUFFER
	#	zle kill-whole-line
	#	print -P "%F{red}$savebuf%f"
	#	BUFFER=$savebuf
	#	CURSOR=$savecur
	#	#if [ -z "$no_zle" ];then
	#	#	zle reset-prompt
	#	#fi
	#fi
}


h_set_cd(){
	dbv $BUFFER
	local org_buff="$BUFFER"
	BUFFER=$(remove_extra_data_from_buffer)
	dbv $BUFFER
	if [ "$HISTNO" = "$histno_prev" ]; then
		return
	fi
	if [ -z "$CPWD" ];then
		CPWD=$PWD
		hist_dir_arr=()
		hist_dir_arr_idx=
	fi
	local d=$(get_wd_from_hist_entry "$org_buff")
	if [ -z "$d" ]; then
		d="$CPWD"
	fi
	x=0
	if [ -n "$d" ];then
		if [ "$d" != "$PWD" ];then
			pwd="$(print -P %~)"
			cd "$d"
			d="$(tilderize_path "$d")"
			if [ -n "$zsh_d_size_max" ]; then
				if ((zsh_d_size_max < ${#d})); then
					x=3
				 	zsh_d_size_max=${#d}
				elif ((zsh_d_size_max < ${#pwd})); then
					x=4
					zsh_d_size_max=${#pwd}
				fi
			elif ((#d > #pwd)); then
				x=1
				zsh_d_size_max=${#d}
			else
				x=2
				zsh_d_size_max=${#pwd}
			fi
			echo "x=$x #d=${#d} > #pwd=${#pwd} cd from '$pwd' to '$d' from history : $HISTNO : $BUFFER zsh_d_size_max=$zsh_d_size_max" >> $HOME/.zsh_cd_history
			reset_prompt
		fi
	fi
	histno_prev=$HISTNO
}

function hook_interrupt() {
	cd "$CPWD"
	on_reset_editor
	interrupted=1
	zle send-break
}
zle -N hook_interrupt
bindkey '^C' hook_interrupt
trap 'hook_interrupt' INT


function history-beginning-search-backward-end-pwd(){
	zle .history-beginning-search-backward
	h_set_cd
}

function history-beginning-search-forward-end-pwd(){
	zle .history-beginning-search-forward
	h_set_cd
}


function up-line-or-history-hook(){
	zle .up-line-or-history
	h_set_cd
}


function down-line-or-history-hook(){
	zle .down-line-or-history
	h_set_cd
}

hist_dir_arr=()
hist_dir_arr_idx=
orig_work_dir=
typeset -A hist_dir_cache


hist-dir-only-left(){
	local i=$HISTNO
	local owd=$(hist_dir -n $i)
	if [ ${#hist_dir_arr[@]} -eq 0 ];then
		hist_dir_arr_idx=1
		if [ -n "$owd" ];then
			hist_dir_arr+=("$owd")
		else
			hist_dir_arr+=("$PWD")
		fi
	fi
	if (( ${#hist_dir_arr[@]} <= hist_dir_arr_idx ));then
		while ((i > 0));do
			local d=$(hist_dir -n $i)
			if [ -n "$d" ] && [ "$d" != "$owd" ];then
				for e in ${hist_dir_arr[@]};do
					if [ "$e" = "$d" ];then
						i=$((i - 1))
						continue 2
					fi
				done
				hist_dir_arr+=("$d")
				hist_dir_arr_idx=${#hist_dir_arr[@]}
				cd "$d"
				echo "cd to '$d' from history : $i" >> $HOME/.zsh_cd_history
				reset_prompt "$owd"
				return
			fi
			i=$((i - 1))
		done
	else
		hist_dir_arr_idx=$((hist_dir_arr_idx + 1))
		local d="${hist_dir_arr[$hist_dir_arr_idx]}"
		cd "$d"
		echo "cd to '$d' from hist_dir_arr : $hist_dir_arr_idx" >> $HOME/.zsh_cd_history
		reset_prompt "$owd"
	fi
}
hist-dir-only-right(){
	local i=$HISTNO
	local owd=$(hist_dir -n $i)
	hist_last=$((`fc -l -1 | head -1 | awk '{print $1}'` + 1))
	if [ ${#hist_dir_arr[@]} -eq 0 ];then
		hist_dir_arr_idx=1
		if [ -n "$owd" ];then
			hist_dir_arr+=("$owd")
		else
			hist_dir_arr+=("$PWD")
		fi
	fi
	if (( hist_dir_arr_idx == 1 ));then
		while ((i <= hist_last));do
			local d=$(hist_dir -n $i)
			if [ -n "$d" ] && [ "$d" != "$owd" ];then
				for e in ${hist_dir_arr[@]};do
					if [ "$e" = "$d" ];then
						i=$((i + 1))
						continue 2
					fi
				done
				hist_dir_arr=("$d" ${hist_dir_arr[@]})
				hist_dir_arr_idx=1
				cd "$d"
				echo "cd to '$d' from history : $i" >> $HOME/.zsh_cd_history
				reset_prompt "$owd"
				return
			fi
			i=$((i + 1))
		done
	elif (( hist_dir_arr_idx > 1 ));then
		hist_dir_arr_idx=$((hist_dir_arr_idx - 1))
		local d="${hist_dir_arr[$hist_dir_arr_idx]}"
		cd "$d"
		echo "cd to '$d' from hist_dir_arr : $hist_dir_arr_idx (${hist_dir_arr[$hist_dir_arr_idx]})" >> $HOME/.zsh_cd_history
		reset_prompt "$owd"
	fi
}

zle -N show_warning_buffer

zle -N hist-dir-only-left
bindkey '^[[1;3D' hist-dir-only-left
zle -N hist-dir-only-right
bindkey '^[[1;3C' hist-dir-only-right

hist-dir-fix-up(){
	local i=$HISTNO
	local owd=$(hist_dir $i)
	i=$((i - 1))
	while ((i > 0));do
		if [ -n "${history[$i]}" ]; then
			local d=$(hist_dir $i)
			if [ -n "$d" ] && [ "$d" = "$owd" ];then
				HISTNO=$((i + 1))
				zle .up-history
				return
			fi
		fi
		i=$((i - 1))
	done
}
hist-dir-fix-down(){
	local i=$HISTNO
	local owd=$(hist_dir $i)
	i=$((i + 1))
	hist_last=$((`fc -l -1 | head -1 | awk '{print $1}'` + 1))
	while ((i <= hist_last));do
		if [ -n "${history[$i]}" ]; then
			local d=$(hist_dir $i)
			if [ -n "$d" ] && [ "$d" = "$owd" ];then
				HISTNO=$((i - 1))
				zle .down-history
				return
			fi
		fi
		i=$((i + 1))
	done
}

zle -N hist-dir-fix-up
bindkey '^[[1;3A' hist-dir-fix-up
zle -N hist-dir-fix-down
bindkey '^[[1;3B' hist-dir-fix-down

zle -N history-beginning-search-backward-end history-beginning-search-backward-end-pwd
zle -N history-beginning-search-forward-end history-beginning-search-forward-end-pwd
zle -N up-line-or-history up-line-or-history-hook
zle -N down-line-or-history down-line-or-history-hook


def_ruby '
	require "shellwords"
	require "Yk/path_aux"
	def raw_cmd_line buff = nil
		if buff
			carr = []
			begin
				carr = Shellwords.split(buff)
			rescue
				return ""
			end
			if carr[0] == "fnd" && (carr.size == 3 || carr.size == 2)
				carr.shift
				dir = "."
				fname = "*"
				if carr.size >= 2
					dir = carr[0]
					fname = carr[1]
				elsif carr.size == 1
					if carr[0] !~ /^(.*)\/([^\/]*)$/
						fname = carr[0]
					else
						fname = $2
						dir = $1
						if dir == ""
							dir = "/"
						end
					end
				end
				carr.clear
				carr.push "find"
				carr.push dir
				carr.push "-name"
				carr.push fname
				if carr[1] == "~"
					"find ~ " + Shellwords.shelljoin(carr[2..-1])
				elsif carr[1] =~ /^\~\//
					"find ~#{carr[1][1..-1].shellescape} " + Shellwords.shelljoin(carr[2..-1])
				else
					Shellwords.shelljoin(carr)
				end
			else
				carr.shift
				carr.each do |e|
					if e =~ /^[~\w_\.\/][~\w_\.\/-]*$/
						e = e.expand_path
						if e._d?
							"~/.command_arg_dirs".expand_path.write_la e.ln 
						elsif e._e?
							"~/.command_arg_files".expand_path.write_la e.ln
						end
					end
				end
				""
			end
		else
			""
		end
	end
'

function is_cursor_at_bottom() {
  # カーソル位置を取得
  exec < /dev/tty
  oldstty=$(stty -g)
  stty -echo -icanon time 0 min 0
  echo -ne '\e[6n' > /dev/tty
  IFS=';' read -r -d R -a pos
  stty "$oldstty"
  # pos[0]は"\e[row"なので、行番号だけ抽出
  row=${pos[0]#*[}
  # 端末の行数を取得
  lines=$(tput lines)
  if [[ "$row" == "$lines" ]]; then
    return 0  # 下端にいる
  else
    return 1  # 下端ではない
  fi
}

__custom_hist_id__(){
	return $?
}

create_temp_file(){
	local tmpfile=$(mktemp /tmp/zsh_raw_cmd.XXXXXX)
	cat > "$tmpfile"
	echo -n "$tmpfile"
}


ALL_BUFFER=

CMD_MDATA_START="༄༅"
CMD_MDATA_BYTE_PREFIX=";$CMD_MDATA_START "
CMD_MDATA_SEP="𖡄"
CMD_SECRET="𖡄"
CMD_SECRET_BYTE_PREFIX="$CMD_SECRET; "

SID_IEND=$(( -1 - ${#CMD_MDATA_END} ))
SID_ISTART=$(( SID_IEND - ${#SID} + 1))
WD_IEND=$(( SID_ISTART - 1 - ${#CMD_WD_END} ))

eval "
$CMD_MDATA_START() { # 何もしない、前の結果を転送するだけ
	return \$?
}
$CMD_SECRET() { # 何もしない、前の結果を転送するだけ
	return \$?
}
"
_correct_all_opt="${options[correct_all]}"
_correct_opt="${options[correct]}"

if [[ $_correct_all_opt == on ]]; then
	unsetopt CORRECT_ALL
	_correct_all_opt_cmd="setopt CORRECT_ALL"
else
	_correct_all_opt_cmd="unsetopt CORRECT_ALL"
fi
if [[ $_correct_opt == on ]]; then
	unsetopt CORRECT
	_correct_opt_cmd="setopt CORRECT"
else
	_correct_opt_cmd="unsetopt CORRECT"
fi


echo '
	CMD_MDATA_BYTE_PREFIX = "'"$CMD_MDATA_BYTE_PREFIX"'".b
	CMD_MDATA_BYTE_PREFIX_REGEX_STR = "".b
	CMD_MDATA_BYTE_PREFIX.each_byte do |c|
		CMD_MDATA_BYTE_PREFIX_REGEX_STR += format("\\\\x%02X".b, c)
	end
	CMD_MDATA_BYTE_PREFIX_REGEX = eval("/" + CMD_MDATA_BYTE_PREFIX_REGEX_STR + "[0-9a-fA-F]{2}/n")

	CMD_MDATA_BYTE_PREFIX_PARTIAL_REGEX_STR = "[0-9A-Fa-f]".b
	CMD_MDATA_BYTE_PREFIX.reverse.each_byte do |c|
		CMD_MDATA_BYTE_PREFIX_PARTIAL_REGEX_STR.replace(
			"#{format("\\\\x%02X", c)}(|#{CMD_MDATA_BYTE_PREFIX_PARTIAL_REGEX_STR})"
		)
	end
	CMD_MDATA_BYTE_PREFIX_PARTIAL_REGEX = eval("/" + CMD_MDATA_BYTE_PREFIX_PARTIAL_REGEX_STR + "$/n")

	CMD_SECRET_BYTE_PREFIX = "'"$CMD_SECRET_BYTE_PREFIX"'".b
	CMD_SECRET_BYTE_PREFIX_REGEX_STR = "".b
	CMD_SECRET_BYTE_PREFIX.each_byte do |c|
		CMD_SECRET_BYTE_PREFIX_REGEX_STR += format("\\\\x%02X".b, c)
	end
	CMD_SECRET_BYTE_REGEX = eval("/" + CMD_SECRET_BYTE_PREFIX_REGEX_STR + ".+?;\\\\s+;\\\\s*/n")
	CMD_SECRET_BYTE_PREFIX_REGEX = eval("/" + CMD_SECRET_BYTE_PREFIX_REGEX_STR + "/n")

	CMD_SECRET_BYTE_PREFIX_PARTIAL_REGEX_STR = CMD_SECRET_BYTE_PREFIX[-1].b
	CMD_SECRET_BYTE_PREFIX[0...-1].reverse.each_byte do |c|
		CMD_SECRET_BYTE_PREFIX_PARTIAL_REGEX_STR.replace(
			"#{format("\\\\x%02X", c)}(|#{CMD_SECRET_BYTE_PREFIX_PARTIAL_REGEX_STR})"
		)
	end
	CMD_SECRET_BYTE_PREFIX_PARTIAL_REGEX_STR += "$".b


	CMD_SECRET_BYTE_PREFIX_PARTIAL_REGEX = eval("/" + CMD_SECRET_BYTE_PREFIX_PARTIAL_REGEX_STR + "/n")

	STDERR.write "CMD_MDATA_BYTE_PREFIX_PARTIAL_REGEX = #{CMD_MDATA_BYTE_PREFIX_PARTIAL_REGEX.inspect}\\n"
	STDERR.write "CMD_MDATA_BYTE_PREFIX_REGEX = #{CMD_MDATA_BYTE_PREFIX_REGEX.inspect}\\n"

	STDERR.write "CMD_SECRET_BYTE_PREFIX_PARTIAL_REGEX = #{CMD_SECRET_BYTE_PREFIX_PARTIAL_REGEX.inspect}\\n"
	STDERR.write "CMD_SECRET_BYTE_PREFIX_REGEX = #{CMD_SECRET_BYTE_PREFIX_REGEX.inspect}\\n"

	def gsub str, left
	  	File.open("/tmp/test.zsh.log2", "ab") do |f|
			if !str.empty?
				f.write "-1 str = #{str.inspect}\\n"
				f.write "0 left = #{left.inspect}\\n"
				_left = nil
				str.gsub! CMD_MDATA_BYTE_PREFIX_REGEX do
					_left = $'"'"'
					""
				end
				if _left
					if _left =~ CMD_MDATA_BYTE_PREFIX_PARTIAL_REGEX
						str.replace str + $`
						left.replace $& + left
					end
				else
					if str =~ CMD_MDATA_BYTE_PREFIX_PARTIAL_REGEX
						str.replace $`
						left.replace $& + left
					end
				end

				f.write "-1 str = #{str.inspect}\\n"
				f.write "0 left = #{left.inspect}\\n"
				_left = nil
				str.gsub! CMD_SECRET_BYTE_REGEX do
					_left = $'"'"'
					""
				end
				if _left
					case _left
					when CMD_SECRET_BYTE_PREFIX_PARTIAL_REGEX
						str.replace str + $`
						left.replace $& + left
					when CMD_SECRET_BYTE_PREFIX_REGEX
						str.replace str + $`
						left.replace $& + left
					end
				else
					case str
					when CMD_SECRET_BYTE_PREFIX_PARTIAL_REGEX
						str.replace $`
						left.replace $& + left
					when CMD_SECRET_BYTE_PREFIX_REGEX
						str.replace $`
						left.replace $& + left
					end
				end
			elsif left == ";"
				f.write "1 str = #{str.inspect}\\n"
				f.write "2 left = #{left.inspect}\\n"
				str.replace ";"
				left.clear
				f.write "3 str = #{str.inspect}\\n"
				f.write "4 left = #{left.inspect}\\n"
			elsif left =~ CMD_SECRET_BYTE_PREFIX_REGEX && $` == ""
				f.write "1 str = #{str.inspect}\\n"
				f.write "2 left = #{left.inspect}\\n"
				str.replace $'"'"'.strip
				left.clear
			else
				f.write "5 str = #{str.inspect}\\n"
				f.write "6 left = #{left.inspect}\\n"
			end
		end
	end
' > $ZRB_FILTER_DIR/erase_zsh_cmd_mdata.rb

dbv $ZRB_FILTER_DIR/erase_zsh_cmd_mdata.rb
#実行してはいけない。実行するとデータが落ちる。kill -s USR1 $ZRB_FILTER_PID 2>/dev/null

encode_suffix(){
	local src="$1"
	if [ -z "$src" ]; then
		echo -n ""
		return
	fi
	print -rn -- "$src" \
	| od -An -tx1 -v \
	| tr -s ' ' '\n' \
	| sed '/^$/d' \
	| awk -v p=";$CMD_MDATA_START " '{printf "%s%s", p, toupper($1)}'
}

decode_suffix(){
	local encoded="$1"
	local prefix=";$CMD_MDATA_START "
	local hex="${encoded//$prefix/}"
	hex="$(print -rn -- "$hex" | tr -cd '0-9A-Fa-f')"
	if [ -z "$hex" ]; then
		echo -n ""
		return
	fi
	print -rn -- "$hex" | xxd -r -p
}

decode_suffix_from_hist_entry(){
	local entry="$1"
	local prefix=";$CMD_MDATA_START "
	if [[ "$entry" != *"$prefix"* ]]; then
		echo -n ""
		return
	fi
	local encoded="${entry#*"$prefix"}"
	decode_suffix "$prefix$encoded"
}



function _raw_cmd_line {
	if [ -n "$precmd_called" ]; then
		precmd_called=""
		BUFFER="${BUFFER##[[:space:]]#}"   # 先頭の空白除去
		raw_cmd_line $BUFFER # only first line will be modified
		if [ -n "$raw_cmd_line" ]; then
			BUFFER=$raw_cmd_line
		fi
	fi	
	local PRE_BUFFER=
	if [ -z "$_zrb_filter_on" ]; then
		PRE_BUFFER="$BUFFER"
		_zrb_filter_on=1
		dbv "turn on zrb_filter"
		BUFFER="$CMD_SECRET_BYTE_PREFIX""zrb_filter_on; echo -en \"\e[28m\"; $_correct_all_opt_cmd; $_correct_opt_cmd; ;$BUFFER"
	fi
	ALL_BUFFER="$ALL_BUFFER$BUFFER
"
	if zle_acceptable "$ALL_BUFFER"; then
		dbv "acceptable: $ALL_BUFFER"
		BUFFER="${BUFFER%%[[:space:]]#}"   # 末尾の空白除去
		export RAW_CMD_LINE="${ALL_BUFFER}"
		cmd_suffix=$(encode_suffix "$PWD$CMD_MDATA_SEP$SID")
		BUFFER="$BUFFER$cmd_suffix"
	else
		dbv "not acceptable: $ALL_BUFFER"
	fi
	echo -ne '\e7'
	echo -ne "\033[999C"
	echo -ne "\033[8D"
	echo -ne "\033[34m"
	date=`date +"%k:%M:%S"`
	echo -ne $date
	echo -ne "\033[0m"
	echo -ne '\e8'
	exec 1>&1
	echo "`date +"%Y-%m-%d %H:%M:%S"` $ALL_BUFFER" >> $HOME/.zsh_raw_cmd_lines
	if [ -n "$PRE_BUFFER" ]; then
		echo -en "$PRE_BUFFER\e[8m"
	fi
	zle accept-line
}

remove_extra_data_from_buffer(){
	local PRE_BUFFER="$BUFFER"
	local cleaned_buffer="$BUFFER"
	while [[ "$cleaned_buffer" == *"$CMD_SECRET_BYTE_PREFIX"*"; ;"* ]]; do
		local left_part="${cleaned_buffer%%"$CMD_SECRET_BYTE_PREFIX"*}"
		local rest_part="${cleaned_buffer#*"$CMD_SECRET_BYTE_PREFIX"}"
		rest_part="${rest_part#*"; ;"}"
		cleaned_buffer="${left_part}${rest_part}"
	done
	BUFFER="$cleaned_buffer"
	dbv $BUFFER
	dbv $CMD_MDATA_BYTE_PREFIX
	dbv "${BUFFER%"$CMD_MDATA_BYTE_PREFIX"*}"
	dbv "${BUFFER%%"$CMD_MDATA_BYTE_PREFIX"*}"
	BUFFER="${BUFFER%%"$CMD_MDATA_BYTE_PREFIX"*}"
	dbv $BUFFER
	echo -n "$BUFFER"
}

zle -N raw_cmd_line_widget _raw_cmd_line
bindkey '^J' raw_cmd_line_widget
bindkey '^M' raw_cmd_line_widget

# 例: 先頭スペース行は捨てる / " zrb_filter_on; " を除去して保存
zrb_rewrite_history() {
	emulate -L zsh
	local line="${1%$'\n'}"   # 末尾改行を外す


	[[ $options[histignorespace] == on ]] && [[ "$line" == ' '* ]] && return 1

	if [[ $line == 𖡄*'; ;'* ]]; then
		# 注入プレフィックスを取り除く
  		line="${line#𖡄*'; ;'}"

		# 元の登録を止め、書き換え後を履歴へ追加
		print -sr -- "$line"
		return 1
  	fi
  	return 0
}

add-zsh-hook zshaddhistory zrb_rewrite_history


hist(){
	dmax=0
	kmax=0
	asterisk=
	while read -r line; do
		key="${line%%  *}"
		key_no_star="${key%\*}"
		if [ $key != $key_no_star ]; then
			asterisk=1
		fi
		if [[ $key =~ '^[0-9]+(\*|)$' ]]; then
			dir=$(hist_dir -n $key)
			kmax=$(( ${#key} > kmax ? ${#key} : kmax ))
			dir=$(tilderize_path "$dir")
			dmax=$(( ${#dir} > dmax ? ${#dir} : dmax ))
		fi
	done < <(builtin history "$@")
	if [ -n "$asterisk" ]; then
		sspace=" "
	else
		sspace=""
	fi
	while read -r line; do
		key="${line%%  *}"
		key_no_star="${key%\*}"
		if [ $key != $key_no_star ]; then
			sspace=""
		fi
		if [[ $key =~ '^[0-9]+(\*|)$' ]]; then
			val="${line#*  }"
			dir=$(hist_dir -n $key)
			if [ -n "$dir" ]; then
				lpadd=$(( kmax - ${#key} ))
				lspaces=$(printf '%*s' "$lpadd" '')
				dir=$(tilderize_path "$dir")
				rpadd=$(( dmax - ${#dir} ))
				rspaces=$(printf '%*s' "$rpadd" '')
				firstline="$lspaces$key$sspace|$dir$rspaces|"
			else
				rspaces=$(printf '%*s' "$dmax" '')
				firstline="$lspaces$key$sspace|$rspaces|"
			fi
			echo -n "$firstline"
			local isFirstLine=1
			Arr=($val)
			lspaces=$(printf '%*s' $(( kmax + asterisk )) '')
			rspaces=$(printf '%*s' "$dmax" '')
			echo $val | while IFS= read -r l; do
				if [ "$isFirstLine" = "1" ]; then
					isFirstLine=0
				else
					echo -n "$lspaces|$rspaces|"
				fi
				echo "$l"
			done
		fi
	done < <(builtin history "$@")
}





