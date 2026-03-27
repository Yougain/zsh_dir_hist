# for zsh

DEBUG=L

FIX_DIR_KEY=alt
FIX_DIR_KEY=

if [ -n "$FIX_DIR_KEY" ]; then # alt key is used for moving cursor without changing directory
	no_alt_gl="global"
	alt_gl="local"
else
	no_alt_gl="local"
	alt_gl="global"
fi


require temp_path colors zsh_rb fpath prompt zed history

export ZLTMPD="$(temp_path zltmpd)"
mkdir -p "$ZLTMPD"


setopt EXTENDED_HISTORY

autoload -Uz add-zsh-hook

typeset -A HISTNO2PWD HISTNO2SID
typeset -A OtherPwdSameCmdNext OtherPwdSameCmdPrev OtherSidSameCmdNext OtherSidSameCmdPrev

SCRIPT_DIR=${${(%):-%N}:A:h}
def_ruby '
	require "'$SCRIPT_DIR'/zsh_dir_hist_support"
	def zsh_dir_hist_init pwd, sid, fc_path, src_path, info_path, hist_file
		do_zsh_dir_hist_init pwd, sid, fc_path, src_path, info_path, hist_file
	end
	def zsh_dir_hist_update cpwd, epochseconds, prev_cmd, new_histno
		do_zsh_dir_hist_update cpwd, epochseconds, prev_cmd, new_histno
	end
	def zsh_dir_hist_dir_msg histno
		do_zsh_dir_hist_dir_msg histno
	end
	def get_id_path_from_dir dir
		do_get_id_path_from_dir dir
	end
	def histno_to_id_path histno
		do_histno_to_id_path histno
	end
	def _get_bind_keyseq_for widget
		do_get_bind_keyseq_for widget
	end
	def initialize_bindkey_data bindkey_path
		do_initialize_bindkey_data bindkey_path
	end
	def _alt_keyseq *keyseq
		do_alt_keyseq *keyseq
	end
	def _keyseq keyname
		do_keyseq keyname
	end
	def _keyname keyseq
		do_keyname keyseq
	end
'

dir_hist_system_initialized=

FC_PATH="$(temp_path zsh_history_fc)"
SRC_PATH="$(temp_path zsh_history_src)"
BINDKEY_PATH="$(temp_path zsh_history_bindkey)"


dir_hist_system_init(){
	fc -l -t '%s' 1 > "$FC_PATH" 2>/dev/null
	zsh_dir_hist_init "$CPWD" "$SID" "$FC_PATH" "$SRC_PATH" "$ZSH_DIR_HIST_INTER_ZSH_INFO_DIR" "$HIST_FILE" "$HISTNO"
	. $SRC_PATH
	dir_hist_system_initialized=1
}

LAST_HIST_NO=0
zmodload zsh/datetime

update_local_and_pwd_hist_file(){

	if [ -z "$dir_hist_system_initialized" ];then
		dir_hist_system_init
	else

		if [ -z "$CPWD" ] || [ ! -d "$CPWD" ]; then
			return
		fi

		fc -l -t '%s' "$LAST_HIST_NO" -1 > "$FC_PATH" 2>/dev/null
		LAST_HIST_NO=$(tail -1 "$FC_PATH"|awk '{print $1}')
		zsh_dir_hist_update "$CPWD" "$epochsec_to_history" "$cmd_to_history" "$HISTNO"
		epochsec_to_history=
		cmd_to_history=
		. $SRC_PATH
	fi
}


hist_precmd() {
	if [ -z "$CPWD" ];then
		CPWD=$PWD
	fi
	up_key_pressed=
	precmd_called=1
	on_reset_editor
	update_local_and_pwd_hist_file
	zdh_update_links_on_precmd
	echo -ne > "$ZLTMPD/idle"
}
add-zsh-hook precmd hist_precmd


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

ZSH_DIR_HIST_INTER_ZSH_INFO_DIR=$(temp_ipc_path dir_hist)
mkdir -p "$ZSH_DIR_HIST_INTER_ZSH_INFO_DIR"


last_hist_entry(){
	fc -l -1 -1 | sed -E 's/^[[:space:]]*[0-9]+\*?[[:space:]]+//'
}

remove_last_hist_entry(){
	local last_hno="`fc -l -1 -1 | awk '{print $1}'`"
	history -d $last_hno
}

on_prexec(){
	# no need to remove duplicated entries here because of setopt hist_ignore_dups
	CPWD=$PWD
}


on_reset_editor(){ # called on precmd
	local last_entry=$(last_hist_entry)

	# Remove last history entry if it is empty command
	if [ "$last_entry" = "" ]; then
		remove_last_hist_entry
	fi
	if [ -n "$FOR_HIST_CD_IN_PRECMD" ]; then
		HISTNO=${FOR_HIST_CD_IN_PRECMD%% *}
		local direction=${FOR_HIST_CD_IN_PRECMD#* }
		unset FOR_HIST_CD_IN_PRECMD
		hist_cd "$direction"
	fi
	hist_dir_arr_reset
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

reset_space2(){
	prompt_before_embodyment2=$(getEmbodymentString $PROMPT_before)
	prompt_pre_sz2=$((${#prompt_before_embodyment2} - pwd_tilda_size))
	local prompt_after_embodyment2=$(getEmbodymentString $PROMPT_after)
	local prompt_post_sz2=${#prompt_after_embodyment2}
	ocaption2="$2 "
	pre_space2="$ocaption2$(getSpaces $((prompt_pre_sz2 - 1 - ${#ocaption2})))"
	post_space2=$(getSpaces $((prompt_post_sz2 - 1)))
}



reset_space


reset_prompt() {
	if [ "$1" = "-n" ];then
		local no_zle=1
		shift
	fi
	local szm="$zsh_d_size_max"
	local orgPwd="$1"
	local targetPwd="$2"
	local msg="$3"
	local sz=$(tilda_size "$PWD")
	local osz=
	local osz2=
	local padd=0
	local spaces=""
	local pre_prompt=""
	if [ -n "$orgPwd" ];then
		orgPwd=$(tilderize_path "$orgPwd")
		osz=${#orgPwd}
	fi
	if [ -n "$msg" ]; then
		reset_space2 "$msg"
		if [ -n "$targetPwd" ] ;then
			targetPwd=$(tilderize_path "$targetPwd")
			osz2=${#targetPwd}
		fi
	fi
	zsh_d_size_max=$(max_multi "$sz" "$osz" "$szm" "$osz2")
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
	if [ -n "$msg" ]; then
		if [ -n "$targetPwd" ] ;then
			local opadd2=$((szm - osz2))
			local ospaces2=$(getSpaces "$opadd2")
			pre_prompt="${pre_prompt}(${pre_space2}%F{yellow}${targetPwd}${ospaces2}%f)${post_space2}
"
		fi
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


hist_id_path(){
	local id_path="${histno_to_id_path[$1]}"
	if [ -n "$id_path" ]; then
		echo -n "$id_path"
	else
		get_id_path_from_dir "$PWD"
		echo -n "$get_id_path_from_dir"
	fi
}

hist_cd(){
	dbv $HISTNO $BUFFER 
	dbv $BUFFER
	if [ "$HISTNO" = "$histno_prev" ]; then
		return
	fi
	if [ -z "$CPWD" ];then
		CPWD=$PWD
		hist_dir_arr_reset
	fi
	#local d=$(get_wd "$org_buff")
	local id_path=
	if [ "$1" = "forward" ]; then
		id_path=${histno_to_proxy_for_id_path_in_forward[$HISTNO]}
	else
		id_path=${histno_to_proxy_for_id_path_in_backward[$HISTNO]}
	fi
	d="$(id_path_to_dir "$id_path")"
	dbv $d
	if [ -z "$d" ]; then
		d="$CPWD"
	fi
	x=0
	if [ -n "$d" ];then
		if [ "$d" != "$PWD" ];then
			pwd="$(print -P %~)"
			if [ -d "$d" -a -x "$d" ]; then
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
			else
				reset_prompt "" "$d"
			fi
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



is_first_line() { [[ $LBUFFER != *$'\n'* ]]; }  # カーソルが1行目
is_last_line()  { [[ $RBUFFER != *$'\n'* ]]; }  # カーソルが最終行


hist_dir_arr_reset(){
	hist_dir_arr=()
	hist_dir_arr_idx=
	hist_dir_histno_arr=()
}

id_path_to_dir(){
	local id_path="$1"
	echo -n "${id_path#${id_path%%/*}}"
}

hist-dir-only-cd(){
	d="$(id_path_to_dir "$id_path")"
	owd="$(id_path_to_dir "$owd_id_path")"
	if [ -d "$d" -a -x "$d" ]; then
		cd "$d" 2>/denv/null
		if [ "$PWD" = "$d" ]; then
			echo "cd to '$d' from $1" >> $HOME/.zsh_cd_history
			reset_prompt "$owd"
			return
		fi
	fi
	reset_prompt "$owd" "$d"
}

set_other_id_path(){
	local direction="$1"
	while true; do
		for e in ${hist_dir_arr[@]};do
			if [ "$e" = "$id_path" ];then
				if [ "$direction" = "left" ]; then
					hist="${other_id_path_prev[$hist]}"
				else
					hist="${other_id_path_next[$hist]}"
				fi
				if [ -z "$hist" ]; then
					return 1
				fi
				id_path=$(hist_id_path $hist)
				continue 2
			fi
		done
		return 0
	done
}


hist-dir-only(){
	to_global
	local direction="$1"
	local hist=$HISTNO
	local id_path="$(hist_id_path $hist)"
	local owd_id_path="$id_path"
	if [ ${#hist_dir_arr[@]} -eq 0 ];then
		hist_dir_arr_idx=1
		hist_dir_arr+=("$id_path")
		hist_dir_histno_arr+=("$hist")
	fi
	if [ "$direction" = "left" ]; then
		if (( ${#hist_dir_arr[@]} <= hist_dir_arr_idx ));then
			if ! set_other_id_path $direction; then
				return
			fi
			hist_dir_arr+=("$id_path")
			hist_dir_histno_arr+=("$hist")
			hist_dir_arr_idx=${#hist_dir_arr[@]}
		else
			hist_dir_arr_idx=$((hist_dir_arr_idx + 1))
			id_path="${hist_dir_arr[$hist_dir_arr_idx]}"
		fi
	else
		if (( hist_dir_arr_idx == 1 ));then
			if ! set_other_id_path $direction; then
				return
			fi
			hist_dir_arr=("$id_path" ${hist_dir_arr[@]})
			hist_dir_histno_arr=("$hist" ${hist_dir_histno_arr[@]})
			hist_dir_arr_idx=1
		else
			hist_dir_arr_idx=$((hist_dir_arr_idx - 1))
			id_path="${hist_dir_arr[$hist_dir_arr_idx]}"
		fi
	fi
	hist-dir-only-cd "hist_dir_arr : $hist_dir_arr_idx (${hist_dir_arr[$hist_dir_arr_idx]})"
}
	

hist-dir-only-left(){
	hist-dir-only left
}

hist-dir-only-right(){
	hist-dir-only right
}

keyseq(){
	local keyname="$1"
	_keyseq "$keyname"
	echo -n "$_keyseq"
}

zle -N show_warning_buffer

zle -N hist-dir-only-left
bindkey "$(keyseq alt-left)" hist-dir-only-left
zle -N hist-dir-only-right
bindkey "$(keyseq alt-right)" hist-dir-only-right

typeset -A widget_name_to_direction=(
	beginning-of-history backward
	beginning-of-buffer-or-history backward
	end-of-history forward
	end-of-buffer-or-history forward
)

widget_name_to_direction(){
	direc="${widget_name_to_direction[$1]}"
	if [ -n "$direc" ]; then
		echo -n "$direc"
	elif [[ "$1" == *forward* ]]; then
		echo -n "forward"
	elif [[ "$1" == *down* ]]; then
		echo -n "forward"
	else
		echo -n "backward"
	fi
}

bindkey_initialblobald=

get_bind_keyseq_for(){
	if [ -z "$bindkey_initialized" ]; then
		bindkey -M emacs > $BINDKEY_PATH
		initialize_bindkey_data $BINDKEY_PATH
		bindkey_initialized=1
	fi
	_get_bind_keyseq_for "$1"
	echo -n $_get_bind_keyseq_for
}

alt_keyseq(){
	_alt_keyseq "$@"
	echo -n "$_alt_keyseq"
}


co_bind_with_or_without_alt(){
	local w=
	for w in "${co_bind_with_or_without_alt[@]}"; do
		direc=$(widget_name_to_direction "$w")
		local cd_code=
		if [[ "${w[-1]}" == "*" ]]; then
			w="${w%*}"
		else
			cd_code="
				if [ \"\$HISTNO\" != \"\$i\" ]; then
					hist_dir_arr_reset
					hist_cd $direc
				fi
			"
		fi
		eval "
			$w-global() {
				emulate -L zsh
				local i=\"\$HISTNO\"
				to_global
				zle .$w   # 元の動作
				$cd_code
			}
			$w-local() {
				to_local
				zle .$w   # 元の動作
			}
	"
		zle -N $w $w-$no_alt_gl
		zle -N $w-$alt_gl
		local keyseq=($(get_bind_keyseq_for "$w"))
		local ks=
		local alt_keyseq=($(alt_keyseq "${keyseq[@]}"))
		local aks=
		for aks in "${alt_keyseq[@]}"; do
			bindkey "$aks" $w-$alt_gl
		done
	done
}

gl_mode=global

set_fc() {
	if [ "$gl_mode" = "$2" ]; then
		return
	fi
	local utcmd="$(histno_to_utcmd $1 $HISTNO)"
	gl_mode=$2
	if [ "$gl_mode" = "local" ]; then
		fc -p "./.zsh_history.local" 2>/dev/null
		fc -l -t '%s' 1 > "$FC_PATH" 2>/dev/null
		read_local_fc
	else
		fc -P 2>/dev/null
	fi
	HISTNO="$(utcmd_to_histno $2 $HISTNO)"
}

to_local() {
	set_fc global local
}

to_global() {
	set_fc local global
}


setopt EXTENDED_GLOB

co_bind_with_or_without_alt=(
	history-beginning-search-backward-end
	history-beginning-search-forward-end
	up-line-or-history
	down-line-or-history
	beginning-of-history
	end-of-history
	accept-line-and-down-history
	beginning-of-buffer-or-history
	end-of-buffer-or-history
	history-search-backward
	history-search-forward
	beginning-of-line-hist
	end-of-line-hist
	up-line-or-search
	down-line-or-search
	history-incremental-pattern-search-backward*
	history-incremental-pattern-search-forward*
	history-incremental-search-backward*
	history-incremental-search-forward*
)
co_bind_with_or_without_alt


accept-line-and-down-history-global() {
	to_global
   zle .accept-line-and-down-history
	typeset -g FOR_HIST_CD_IN_PRECMD="${histno_next[$HISTNO]} forward"
}

up-line-or-history-global(){
	to_global
	zle .up-line-or-history
	if [ -z "$up_key_pressed" ]; then
		up_key_pressed=1
		HISTNO=$((HISTNO - 1))
	fi
	hist_cd backward
}


up-line-or-history-local(){
	to_local
	zle .up-line-or-history
	if [ -z "$up_key_pressed" ]; then
		up_key_pressed=1
		HISTNO=$((HISTNO - 1))
	fi
}

zle-isearch-update() {
	if [ "$gl_mode" = "global" ]; then
		hist_cd
	fi
}

zle -N zle-isearch-update


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



function _raw_cmd_line {
	if [ -n "$precmd_called" ]; then
		precmd_called=""
		BUFFER="${BUFFER##[[:space:]]#}"   # 先頭の空白除去
		raw_cmd_line $BUFFER # only first line will be modified
		if [ -n "$raw_cmd_line" ]; then
			BUFFER=$raw_cmd_line
		fi
	fi
	ALL_BUFFER="$ALL_BUFFER
$BUFFER"
	#if zle_acceptable "$ALL_BUFFER"; then
	#	# 完成構文: ここで加工や付加情報を入れてから本来動作
	#	BUFFER="$ALL_BUFFER"
	#else
	#	# 未完成構文: 継続入力側へ
	#	BUFFER="$ALL_BUFFER"
	#fi
	if zle_acceptable "$ALL_BUFFER"; then
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
	fi
	zle accept-line
}


zle -N raw_cmd_line_widget _raw_cmd_line
bindkey '^J' raw_cmd_line_widget
bindkey '^M' raw_cmd_line_widget




# 例: 先頭スペース行は捨てる / " zrb_filter_on; " を除去して保存
zsh_history_hook() {
	emulate -L zsh
	local line="${1%$'\n'}"   # 末尾改行を外す
	[[ $options[histignorespace] == on ]] && [[ "$line" == ' '* ]] && return 1

	if [[ -z ${line//[[:space:]]/} ]]; then
		cmd_to_history="$line"
		epochsec_to_history="$EPOCHSECONDS"
		return 0
	fi
}

add-zsh-hook zshaddhistory zsh_history_hook


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
			dir=$(hist_id_path $key)
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
			dir=$(hist_id_path $key)
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


dbv


