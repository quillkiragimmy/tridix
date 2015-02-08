#!/usr/bin/bash

##############################
# text colors.
##############################
txtrst='\e[0m'    # Text Reset

txtblk='\e[0;30m' # Black - Regular
txtred='\e[0;31m' # Red
txtgrn='\e[0;32m' # Green
txtylw='\e[0;33m' # Yellow
txtblu='\e[0;34m' # Blueused by j/ldic.
txtblu='\e[0;34m' # Blue
txtpur='\e[0;35m' # Purple
txtcyn='\e[0;36m' # Cyan
txtwht='\e[0;37m' # White
txtdft='\e[0;39m' # Default

bldblk='\e[1;30m' # Black - Bold
bldred='\e[1;31m' # Red
bldgrn='\e[1;32m' # Green
bldylw='\e[1;33m' # Yellow
bldblu='\e[1;34m' # Blue
bldpur='\e[1;35m' # Purple
bldcyn='\e[1;36m' # Cyan
bldwht='\e[1;37m' # White

##############################
# gloable vars.
##############################
DICLIST=$HOME/tridixlist.list
DICHIST="$DICLIST"_history
MODE='En'	#en,ja,la.
TERMGEOM=( "$(tput lines)" "$(tput cols)" )
PAGER='more -df'
JPAGER='more -d' # pager for Asia font.
SOURCE=''
TEMP=''
LAST=''

PRONOUNCIATION=('')
WRITTENFORM=('')
DEFINITION=('')
ETYMOLOGY=('')
RELATIVE=('')
QUOTE=('')

Anki_Front=''
Anki_Back=''

CLEANUP=()

cleanup(){
	for target in ${CLEANUP[*]}; do
		rm -f $target
	done
}
trap cleanup 0

##############################
# dictionary functions.
##############################
engcolorize(){
	while read line; do
		echo -e "$(echo "$line"\
			| sed "s/^verb/\\$bldblu[Verb]\\$txtrst/g"\
			| sed "s/^noun/\\$bldblu[Noun]\\$txtrst/g"\
			| sed "s/^adjective/\\$bldblu[Adj.]\\$txtrst/g"\
			| sed "s/^adverb/\\$bldblu[Adv.]\\$txtrst/g"\
			| sed "s/\[Etymology]/\\$bldblu[Etymology]\\$txtrst/g"\
			| sed "s/\[Example]/\\$bldblu[Example]\\$txtrst/g"\
			| sed "s/^\([0-9]\{1,2\}\.\)/\\$bldylw\1\\$txtrst/")"
	done
}

linebreaker(){	# newline to break.
	echo -e "$@"| sed 's/$/ <br>/g'| tr -d '\n'
}

engallower(){	# mask vowls. $1=sentence, $2=target word.
	mask=$(echo "$2"| sed 's/[aeiou][nmr]/__/Ig; s/\([cs]\)[kh]/\1_/Ig; s/\([^aeiou ]\)[^aeiou ]/\1_/Ig; s/[aeiouy]/_/Ig')
	mask="${2:0:1}${mask:1: -1}${2: -1}"
	gallow_result=$(echo -e "$1"| sed "s/$2/$mask/Ig")

		# for words ended with postfixs.
	postfix=( 'e' 'y' 'ed' 'er' 'or' 'ing' 'ion' 'ity' 'able' 'ical' 'ment' 'ically' )
	for (( i=0; i<${#postfix[*]}; i++ )); do
		if [ "${2: -${#postfix[i]}}" == "${postfix[i]}" ]; then
			gallow_result=$(echo -e "$gallow_result"| sed "s/${2:0: -${#postfix[i]}}/${mask:0: -${#postfix[i]}}/Ig")
		fi
	done

	echo -e "$gallow_result"
}

endic(){

# the sed.*\} line: bug fix for some indented sources.
# the tr.*\r line: bug fix for some ^Med sources.
	curl -sL http://dictionary.reference.com/browse/$(echo "$@"| tr ' ' '+')?s=t| tr -d '\r'| sed 's/^ \{1,\}//g' > $SOURCE

	if [[ $(fgrep 'Did you mean' $SOURCE) ]]; then
		xmllint --html --htmlout --xpath '//section[@class="more-suggestions"]' $SOURCE 2>/dev/null\
			| perl -pe 's/<.*?>//g'\
			| grep -v '^$'
	else

		for (( i=1; i<11; i++ )); do
			PRONOUNCIATION[i]="$(xmllint --html --htmlout --xpath "(//header[@class=\"main-header oneClick-disabled head-big\"])[$i]/div[2]/div[1]" $SOURCE 2>/dev/null\
				| tr -d '\n'\
				| perl -pe 's/<.*?>//g'\
				| grep -v '^$')"


			ETYMOLOGY[i]="[Etymology]\n$(xmllint --html --htmlout --xpath "(//div[@class=\"tail-wrapper\"])[$i]/div[1]/div[@class=\"tail-content\"]" $SOURCE 2>/dev/null\
				| perl -pe 's/<.*?>//g'\
				| grep -v '^$')"

			DEFINITION[i]="$(xmllint --html --htmlout --xpath "(//div[@class=\"source-data\"])[$i]/div[@class=\"def-list\"]" $SOURCE 2>/dev/null\
				| perl -pe 's/<.*?>//g'\
				| grep -v '^$'\
				| tr '\n' '@'\
				| sed 's|\([0-9]\{1,3\}\.\)@|\1) |g'\
				| tr '@' '\n')"

			# incline examples.
			QUOTE[i]="[Example] $(echo -e "${DEFINITION[i]}"\
				| grep '\.).*:'\
				| cut -d':' -f2\
				| head -n5\
				| grep "$@"\
				| sed 's/$/"/; s/^/"/')\n"

			if [[ ${DEFINITION[i]} ]]; then
				echo -e "____________________[ $i ]____________________" >> $TEMP
				echo -e "${PRONOUNCIATION[i]}\n${DEFINITION[i]}\n${ETYMOLOGY[i]}\n${QUOTE[i]}" >> $TEMP
			fi
		done

		echo -e "$QUOTE_ALL\n$ETYMOLOGY_ALL\n$RELATIVE_ALL" >> $TEMP
		cat $TEMP| fold -w${TERMGEOM[1]} -s | engcolorize| $PAGER	# more & fold conflict with escaping chars (real/logical length).

	fi
}

jagallower(){	# $1=definition, $2=pronounciation, $3=writtenform.
	kana='あいうえおかきくけこがぎぐげごさしすせそざじずぜぞたちつてとだぢづでどなにぬねのはひふへほばびぶべぼぱぴぷぺぽまみむめもやゆよらりるれろわんをアイウエオカキクケコガギグゲゴサシスセソザジズゼゾタチツテトダヂヅデドナニヌネノハヒフヘホバビブベボパピプペポマミムメモヤユヨラリルレロワンヲ'
	chisaikana='ゃゅょャュョァィゥェォ'

	mask=$(echo "$2"| sed "s/[$kana]/－/g; s/[$chisaikana]/_/g")
	(( ${#2} < 5 )) && mask="${mask:0: -1}${2: -1}"
	(( ${#2} >= 5 )) && mask="${2:0:1}${mask:1: -1}${2: -1}"

	gallow_result=$(echo -e "$1"| sed "s/$2/$mask/g")
	stem=$(echo "$2"| tr -d ' '| sed 's/・.*$//g; s/.$//')

	echo -e "$gallow_result"| perl -pe "s/\s$stem.*?(・.*?)\s/ 〜\1 /g; s/$3/【 】/g"

}

jadic(){
	jdicilst=( 'NetDicBody' 'Ingdj' 'Wkpja' 'Jajcw' 'Jtnhj' 'Nhgkt' 'Kyktb' 'Osaka' )
	curl http://www.weblio.jp/content/"$@" -sL > $SOURCE
	if [[ "$(cat $SOURCE| fgrep '見出し語は見つかりません')" ]]; then	# for error fetching.
		xmllint --html --htmlout -xpath '//div[@class="nrCntNbKw"]' $SOURCE 2>/dev/null | perl -pe 's/<.*?>//g'

	else
		for (( i=1, index=1; i<11; i++ )); do
			kiji=$(xmllint --html --htmlout --xpath "(//div[@class=\"kiji\"])[$i]" $SOURCE 2>/dev/null)
			[[ ! "$kiji" ]] && break

			for (( dicindex=0; dicindex<${#jdicilst[@]}; dicindex++ )); do
				if [[ $(echo $kiji| grep "class=\"${jdicilst[dicindex]}\"") ]]; then
					if [[ ${jdicilst[dicindex]} == 'NetDicBody' ]]; then # Daijirin.

						 for (( j=1; j<11; j++ )); do
							 kiji_head[index]=$(xmllint --html --htmlout --xpath "(//div[@class=\"NetDicHead\"])[$j]" $SOURCE 2>/dev/null| perl -pe 's/<.*?>//g')
							 [[ ! "${kiji_head[index]}" ]] && break

							 kiji_body[index]=$(xmllint --html --htmlout --xpath "(//div[@class=\"NetDicBody\"])[$j]" $SOURCE 2>/dev/null\
								 | sed 's/<span style="border/\n\t</g'\
								 | sed 's/<div style="float:left/\n</g'\
								 | perl -pe 's/<.*?>//g')

							 ETYMOLOGY[index]=$(echo ${kiji_body[index]}| fgrep '〔'| perl -pe 's/.*(〔.*?〕).*/\1/g')
							 DEFINITION[index]=$(echo ${kiji_body[index]}| perl -pe 's/〔.*?〕//g')

							 PRONOUNCIATION[index]=$(xmllint --html --htmlout --xpath "(//h2[@class=\"midashigo\"])[$j]/b[1]" $SOURCE 2>/dev/null\
								 | perl -pe 's/<.*?>//g'\
								 | sed 's/\s//g')

							 QUOTE[index]=$(echo ${kiji_body[index]}\
								 | perl -pe 's/<.*?>//g'\
								 | perl -pe 's/.*?(「.*?」).*?/\1/g'\
								 | sed 's/」/」\n/g'\
								 | grep '－'\
								 | sed 's/$/<br>/g'\
								 | tr -d '\n')

							 # find kanji(if any).
							 WRITTENFORM[index]="$@"
							 [[ $(echo ${kiji_head[index]}| fgrep '【') ]] && WRITTENFORM[index]=$(echo ${kiji_head[index]}| perl -pe 's/.*?【(.*?)】.*/\1/')

							 (( index++ ))
						 done
					
					else	# other Jishou.

						for (( j=1; j<11; j++ )); do
							kiji_head[index]=$(xmllint --html --htmlout --xpath "((//div[@class=\"kiji\"])[$i]/h2[@class=\"midashigo\"])[$j]" $SOURCE 2>/dev/null| perl -pe 's/<.*?>//g')
							[[ ! ${kiji_head[index]} ]] && break

							kiji_body[index]=$(xmllint --html --htmlout --xpath "(//div[@class=\"kiji\"])[$i]/div[$j]" $SOURCE 2>/dev/null\
								| perl -pe 's/<.*?>//g'\
								| grep -v '^$')

							DEFINITION[index]=${kiji_body[index]}
							WRITTENFORM[index]=${kiji_head[index]}

							PRONOUNCIATION[index]=$(echo "${DEFINITION[index]}"| grep '読み方：'| sed 's/.*：//'| tr -d ' ') 
							[[ ! ${PRONOUNCIATION[index]} ]] && PRONOUNCIATION[index]="$@"

							(( index++ ))
						done
					fi
				fi
			done
		done

		for (( i=1; i<index; i++ )); do
			echo -e "____________________[ $i ]____________________" >> $TEMP
			echo -e "$bldwht${kiji_head[i]}$txtrst" >> $TEMP
			echo -e "$txtrst${kiji_body[i]}" >> $TEMP
		done

		[ -e $TEMP ] && ( cat $TEMP| $JPAGER )


	fi

}

lagallower(){
	mask=$(echo "$2"| sed 's/[aeiou][nmr]/__/Ig; s/\([cs]\)[kh]/\1_/Ig; s/\([^aeiou ]\)[^aeiou ]/\1_/Ig; s/[aeiouy]/_/Ig')
	mask="${2:0:1}${mask:1: -1}${2: -1}"
	echo -e "$1"| tr -d '.'| sed "s/$2/$mask/g"
}

ladic(){
	src=$(echo "$@"| words| tr -d '\r')
	orig=$(echo "$src"| grep -n '=>$'| cut -d':' -f1)
	end=$(echo "$src"| grep -n '=>Raised'| cut -d':' -f1)
	echo "$src" | sed -n "$((orig+1)), $((end-1)) p"\
		| grep -v '^$'\
		| tr '\r' '\n'\
		| sed 's/\s\{2,\}/ /g'\
		| fgrep -v 'RETURN/ENTER'\
		| fgrep -v 'Unexpected exception' > $SOURCE

	last_is_def=false
	index=0
	while read line; do
	if echo "$line"| grep -q ';'; then
			if ! $last_is_def; then
				(( index++ ))
			fi
			DEFINITION[index]+="$line\n"
			last_is_def=true
		else
			WRITTENFORM[index+1]+="$line\n"
			last_is_def=false
		fi
	done < $SOURCE
	(( index++ ))

	for (( i=1; i<index; i++ )); do
		echo -e "____________________[ $i ]____________________" >> $TEMP
		echo -e "$bldwht${DEFINITION[i]}" >> $TEMP
		echo -e "$txtgrn${WRITTENFORM[i]}$txtrst" >> $TEMP
	done

	[ -e $TEMP ] && ( cat $TEMP| $PAGER )


}

header(){
	# another word or add previous to history.
	echo -e "$bldred$MODE)$bldgrn <word>|<index>|<command>|help; $txtrst($(wc -l $DICHIST | cut -d' ' -f1) listed. >>"
}

manpg(){
	echo -e "Usage: tridix.sh [-p | --pagerless] [-h | --help] [--list <file_path>]"
	echo -e ""
	echo -e "$txtylw\tWhen script is running, you can enter :$txtrst"
	echo "1. Any phrase like 'dictionary' '辞書'."
	echo "2. 'e' / 'j' / 'l' to switch to Eng / Jap / Lat mode"
	echo "3. '' / '1' ... '9' to add N'th word into list."
	echo "4. Commands below :"
	echo -e "\tls: show list entries"
	echo -e "\tpg: purge list"
	echo -e "\td: delete last item in list"
	echo -e "\thelp: this help"
}

##############################
# main program.
##############################

while (( $# != 0 )); do
	case "$1" in
		'-h'| '--help')
			manpg
			exit 0
			;;
		'-p'| '--pagerless')
			PAGER='cat'
			;;
		'--list')
			shift
			DICLIST="$1"
			DICHIST="$1"_history
			;;
	esac
	shift
done

touch $DICLIST $DICHIST
clear
header
while read -e word; do
	TERMGEOM=( "$(tput lines)" "$(tput cols)" )

	case "$word" in
		''|1|2|3|4|5|6|7|8|9|10)
			if [ "$word" == '' ]; then word='1'; fi # enlist first word.

			if [ -e "$TEMP" ]; then

				if [ $MODE == 'En' ]; then
					quote_all="\"$(xmllint --html --htmlout -xpath '//li[@class="example-sentence"]' $SOURCE 2>/dev/null\
						| sed 's|</li>|"\n<>"|g'\
						| perl -pe 's/<.*?>//g'\
						| head -n2)"

					etymology_all="$(xmllint --html --htmlout --xpath '//section[@id="source-etymon2"]/div[@class="source-box oneClick-area"]' $SOURCE 2>/dev/null\
						| perl -pe 's/<.*?>//g'\
						| grep -v '^$')"

					relative_all="$(cat $SOURCE| xmllint --html --htmlout --xpath '//*[@class="tail-box tail-type-relf"]' - 2>/dev/null\
						| perl -pe 's/<.*?>//g'\
						| grep -v '^$'\
						| sed 's/Related forms Expand/[Related]/g'\
						| sed 's/Derived Forms/[Derived]/g')"

					Anki_Front=$(engallower "$(linebreaker "$LAST\n${DEFINITION[word]}\n${QUOTE[word]}\n$quote_all" )" "$LAST" )
					Anki_Back=$(linebreaker "$LAST\n${PRONOUNCIATION[word]}\n${ETYMOLOGY[word]}\n$etymology_all\n$relative_all")
					echo -e "engallows\tBasic\t1\t$Anki_Front\t$Anki_Back" >> $DICLIST

				elif [ $MODE == 'Ja' ]; then
					Anki_Front=$(jagallower "$(linebreaker "${PRONOUNCIATION[word]}<br>${DEFINITION[word]}<br>${QUOTE[word]}" )" "${PRONOUNCIATION[word]}" "${WRITTENFORM[word]}" )
					Anki_Back=$(linebreaker "${WRITTENFORM[word]}<br>${PRONOUNCIATION[word]}<br>${ETYMOLOGY[word]}<br>${DEFINITION[word]}" )
					echo -e "日本語謎々\tBasic\t1\t$Anki_Front\t$Anki_Back" >> $DICLIST
					LAST="${WRITTENFORM[word]}"

				elif [ $MODE == 'La' ]; then
					Anki_Front=$(lagallower "$(linebreaker "$LAST\n${DEFINITION[word]}<br>${WRITTENFORM[word]}")" "$LAST")
					Anki_Back=$(linebreaker "$LAST\n${WRITTENFORM[word]}\n")
					echo -e "AENIGMAE.LATINAE\tBasic\t1\t$Anki_Front\t$Anki_Back" >> $DICLIST

				fi 
				echo -e "$(echo $Anki_Front| sed 's/<br>/\n/g')"
				echo -e "______________________________________"
				echo -e "$(echo $Anki_Back| sed 's/<br>/\n/g')"

				echo -e "$MODE\t$LAST" >> $DICHIST
				rm -f $TEMP
			fi
			;;

		e)
			echo -e "$bldylw >> English Mode.$txtrst"	
			MODE='En'
			rm -f $TEMP $SOURCE
			;;

		j)
			echo -e "$bldylw >> 日本語モード$txtrst"	
			MODE='Ja'
			rm -f $TEMP $SOURCE
			;;

		l)
			echo -e "$bldylw >> MODVSLATINVS$txtrst"	
			MODE='La'
			rm -f $TEMP $SOURCE
			;;

		pg)
			echo -e "$bldylw >> Purge list.$txtrst"	
			mv $DICLIST "$DICLIST"_bak
			rm -f $DICHIST
			touch $DICLIST $DICHIST
			;;

		d)
			echo -e "$bldylw >> delete last entry.$txtrst"
			tail -n1 $DICHIST| cut -d'<' -f1
			sed -i '$d' $DICLIST $DICHIST	# list all after deletion.
			;&

		ls)
			listtmp="$(cat -n $DICHIST\
				| sed s/Ja/\\$bldwht/ \
				| sed s/En/\\$bldylw/ \
				| sed s/La/\\$bldgrn/ \
				| sed s/$/\\$txtrst/) $txtrst"

				echo -e "$listtmp" | more -d
			;;

		help)
			manpg
			;;

		*)
			rm -f "$TEMP" "$SOURCE"
			LAST='' # clean previous word & metas.

			PRONOUNCIATION=('')
			DEFINITION=('')
			QUOTE=('')
			ETYMOLOGY=('')
			RELATIVE=('')
			WRITTENFORM=('')

			Anki_Front=''
			Anki_Back=''
			

			SOURCE=/tmp/.tridixsrc_$RANDOM
			TEMP=/tmp/.tridixtmp_$RANDOM
			CLEANUP=( "$SOURCE" "$TEMP" )

			if [ $MODE == 'En' ]; then
		#		tt
				endic "$word"
			elif [ $MODE == 'Ja' ]; then
				jadic "$word"
			elif [ $MODE == 'La' ]; then
				ladic "$word"
			fi

			LAST="$word"
			;;
	esac

	header

done


