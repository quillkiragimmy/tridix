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
BARS=''       # used by j/ldic.

PRONOUNCIATION=''
RELATIVE=''
QUOTE=''
DEFINITION=''
ETYMOLOGY=''

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
			| sed "s/etymology:/\\$bldblu[Etymology]\\$txtrst/g"\
			| sed "s/example:/\\$bldblu[Example]\\$txtrst/g"\
			| sed "s/^\([0-9]\{1,2\}\.\)/\\$bldylw\1\\$txtrst/")"
	done
}

linebreaker(){	# newline to break.
	echo -e "$@"| sed 's/$/ <br>/g'| tr -d '\n'
}

engallower(){	# mask vowls. $1=sentence, $2=target word.
	mask=$(echo "$2"| sed 's/[aeiou][nmr]/__/Ig; s/\([cs]\)[kh]/\1_/Ig; s/\([^aeiou]\)[^aeiou]/\1_/Ig; s/[aeiouy]/_/Ig')
	mask="${2:0:1}${mask:1: -1}${2: -1}"
	gallow_result=$(echo -e "$1"| sed "s/$2/$mask/Ig")

		# for words ended with postfixs.
	postfix=( 'e' 'y' 'ed' 'ing' 'ion' 'able' 'ical' 'ically' )
	for (( i=0; i<${#postfix[*]}; i++ )); do
		if [ "${2: -${#postfix[i]}}" == "${postfix[i]}" ]; then
			gallow_result=$(echo -e "$gallow_result"| sed "s/${2:0: -${#postfix[i]}}/${mask:0: -${#postfix[i]}}/Ig")
		fi
	done

	echo -e "$gallow_result"
}

jagallower(){
	kana='あいうえおかきくけこがぎぐげごさしすせそざじずぜぞたちつてとだぢづでどなにぬねのはひふへほばびぶべぼぱぴぷぺぽまみむめもやゆよらりるれろわんをアイウエオカキクケコガギグゲゴサシスセソザジズゼゾタチツテトダヂヅデドナニヌネノハヒフヘホバビブベボパピプペポマミムメモヤユヨラリルレロワンヲ'
	chisaikana='ゃゅょャュョ'

	gallow_result=$(echo "$1"| sed "s/[$kana]/－/g; s/[$chisaikana]/_/g")
	gallow_result="${gallow_result:0: -1}${1: -1}"
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
		PRONOUNCIATION="$(xmllint --html --htmlout --xpath '//span[@class="pron ipapron"]' $SOURCE 2>/dev/null\
			| perl -pe 's/<.*?>//g')\n"

		RELATIVE="$(cat $SOURCE| xmllint --html --htmlout --xpath '//*[@class="tail-box tail-type-relf"]' - 2>/dev/null\
			| perl -pe 's/<.*?>//g'\
			| grep -v '^$'\
			| sed 's/Related forms Expand/[Related]/g'\
			| sed 's/Derived Forms/[Derived]/g')"

		DEFINITION="$(xmllint --html --htmlout --xpath '(//div[@class="source-data"])[1]/div[@class="def-list"]' $SOURCE 2>/dev/null\
			| perl -pe 's/<.*?>//g'\
			| grep -v '^$'\
			| tr '\n' '@'\
			| sed 's|\([0-9]\{1,3\}\.\)@|\1) |g'\
			| tr '@' '\n')"

		ETYMOLOGY="etymology: $(xmllint --html --htmlout --xpath '//section[@id="source-etymon2"]/div[@class="source-box oneClick-area"]' $SOURCE 2>/dev/null\
			| perl -pe 's/<.*?>//g'\
			| grep -v '^$')"

			# incline examples.
		QUOTE="example: $(echo -e "$DEFINITION"\
			| grep '\.).*:'\
			| cut -d':' -f2\
			| head -n5\
			| grep "$@"\
			| sed 's/$/"/; s/^/"/')\n"
		# search quote from web.
		QUOTE+="\"$(xmllint --html --htmlout -xpath '//li[@class="example-sentence"]' $SOURCE 2>/dev/null\
			| sed 's|</li>|"\n<>"|g'\
			| perl -pe 's/<.*?>//g'\
			| head -n2)"

		echo -e "$PRONOUNCIATION$DEFINITION\n$ETYMOLOGY\n$QUOTE\n$RELATIVE" > $TEMP
		cat $TEMP| fold -w${TERMGEOM[1]} -s | engcolorize| $PAGER 	# more & fold conflict with escaping chars (real/logical length).

	fi
}

jadic(){
	curl http://www.weblio.jp/content/"$@" -s > $SOURCE
	if [ "$(cat $SOURCE| fgrep '見出し語は見つかりません')" == '' ]; then	# for error fetching.
		for (( i=1; i < 11; i++ )); do
			kiji_head=$(xmllint --html --htmlout --xpath "(//div[@class=\"NetDicHead\"])[$i]" $SOURCE 2>/dev/null| perl -pe 's/<.*?>//g')
			kiji_body=$(xmllint --html --htmlout --xpath "(//div[@class=\"NetDicBody\"])[$i]" $SOURCE 2>/dev/null\
				| sed 's/<span style="border/\n\t</g'\
				| sed 's/<div style="float:left/\n</g'\
				| perl -pe 's/<.*?>//g')
			[ -z "$kiji_body" ] && kiji_body=$(xmllint --html --htmlout --xpath "(//div[@class=\"Wkpja\"])[$i]/p" $SOURCE 2>/dev/null| perl -pe 's/<.*?>//g')
			[ -z "$kiji_body" ] && kiji_body=$(xmllint --html --htmlout --xpath "(//div[@class=\"Nhgkt\"])[$i]" $SOURCE 2>/dev/null| perl -pe 's/<.*?>//g')

			if [ ! -z "$kiji_body" ]; then
				echo -e "━━━━━━━━━━━━━━━━━━━━[ $i ]━━━━━━━━━━━━━━━━━━━━" >> $TEMP
				echo -e "$bldwht$kiji_head" >> $TEMP
				echo -e "$txtrst$kiji_body" >> $TEMP
			fi

		done
		[ -e $TEMP ] && ( cat $TEMP| $JPAGER )

	fi

}

ladic(){
	echo "$@"| words| tr -d '\r' > $SOURCE
	orig=$(cat $SOURCE| grep -n '=>$'| cut -d':' -f1)
	end=$(cat $SOURCE| grep -n '=>Raised'| cut -d':' -f1)
	cat $SOURCE| sed -n "$((orig+1)), $((end-1)) p"\
		| grep -v '^$'\
		| tr '\r' ' '\
		| fgrep -v 'RETURN/ENTER'\
		| fgrep -v 'Unexpected exception'\
		| sed 's/\(;.*\)$/\1\n━━━━━━━━━━━━━/' >> $TEMP

	BARS=( '1' $(fgrep -n "━━━━━━━━━━━━━" $TEMP| cut -d':' -f1) '$' )

	cat $TEMP| fold -w${TERMGEOM[1]} -s| $PAGER

}

header(){
	# another word or add previous to history.
	echo -e "$bldred$MODE)$bldgrn <word>|<index>|<command>|help; $txtrst($(wc -l $DICLIST | cut -d' ' -f1) listed. >>"
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
		''|1|2|3|4|5|6|7|8|9)
			if [ "$word" == '' ]; then word='1'; fi # enlist first word.

			if [ -e "$TEMP" ]; then

				if [ $MODE == 'En' ]; then
					Anki_Front="$(engallower "$(linebreaker "$DEFINITION\n$QUOTE")" "$LAST") "
					Anki_Back="$(linebreaker "$LAST\n$PRONOUNCIATION\n$ETYMOLOGY\n$RELATIVE")"
					echo -e "engallows\tBasic\t1\t$Anki_Front\t$Anki_Back" >> $DICLIST

				elif [ $MODE == 'Ja' ]; then
					kiji_head=$(xmllint --html --htmlout --xpath "(//div[@class=\"NetDicHead\"])[$word]" $SOURCE 2>/dev/null| perl -pe 's/<.*?>//g')
					kiji_body=$(xmllint --html --htmlout --xpath "(//div[@class=\"NetDicBody\"])[$word]" $SOURCE 2>/dev/null| perl -pe 's/<.*?>//g')
					[ -z "$kiji_body" ] && kiji_body=$(xmllint --html --htmlout --xpath "(//div[@class=\"Wkpja\"])[$word]/p" $SOURCE 2>/dev/null| perl -pe 's/<.*?>//g')
					[ -z "$kiji_body" ] && kiji_body=$(xmllint --html --htmlout --xpath "(//div[@class=\"Nhgkt\"])[$word]" $SOURCE 2>/dev/null| perl -pe 's/<.*?>//g')

					ETYMOLOGY="$(echo $kiji_body| perl -pe 's/.*(〔.*?〕).*/\1/g')"
					DEFINITION="$(echo $kiji_body| perl -pe 's/〔.*?〕//g')"
					PRONOUNCIATION="$(xmllint --html --htmlout --xpath "(//h2[@class=\"midashigo\"])[$word]/b[1]" $SOURCE 2>/dev/null\
						| perl -pe 's/<.*?>//g')"
					[ -z "$PRONOUNCIATION" ] && PRONOUNCIATION="$(xmllint --html --htmlout --xpath "(//h2[@class=\"midashigo\"])[$word]" $SOURCE 2>/dev/null\
						| perl -pe 's/<.*?>//g')"
					[ -z "$PRONOUNCIATION" ] && PRONOUNCIATION=$LAST

					QUOTE="$(echo $kiji_body\
						| perl -pe 's/<.*?>//g'\
						| perl -pe 's/.*?(「.*?」).*?/\1/g'\
						| sed 's/」/」\n/g'\
						| grep '－'\
						| sed 's/$/<br>/g'\
						| tr -d '\n')"

						# find kanji(if any).
					kanji=''
					if [[ $(echo $kiji_head| fgrep '【') ]]; then
						kanji="$(echo $kiji_head| perl -pe 's/.*?(【.*?】).*/\1/')"
					else
						kanji="$LAST"
					fi

					Anki_Front="$(jagallower "$PRONOUNCIATION")<br>$DEFINITION<br>$QUOTE"
					Anki_Back="$kanji<br>$PRONOUNCIATION<br>$ETYMOLOGY"
					echo -e "日本語謎々\tBasic\t1\t$Anki_Front\t$Anki_Back" >> $DICLIST
					LAST="$kanji"

				elif [ $MODE == 'La' ]; then
					slot=$(cat $TEMP\
						| sed -n "${BARS[word-1]}, ${BARS[word]} p"\
						| grep -v '━'\
						| sed 's/\s\{1,\}/ /g'\
						| sed 's/$/<br>/g'\
						| tr '\n' ' ')

					DEFINITION="$(echo $slot| sed 's/<br>/\n/g'| fgrep '[')"
					echo -e "VOCABULAE\tBasic\t1\t$LAST<br>$DEFINITION\t$(echo $slot)" >> $DICLIST

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
			touch $DICLIST $DICLIST
			;;

		d)
			echo -e "$bldylw >> delete last entry.$txtrst"
			tail -n1 $DICHIST| cut -d'<' -f1
			sed -i '$d' $DICLIST $DICHIST	# list all after deletion.
			;&

		ls)
			listtmp="$(cat $DICHIST\
				| sed s/Ja/\\$bldwht/ \
				| sed s/En/\\$bldylw/ \
				| sed s/La/\\$bldgrn/ ) $txtrst"

				echo -e "$listtmp" | more -d
			;;

		help)
			manpg
			;;

		*)
			rm -f "$TEMP" "$SOURCE"
			LAST='' # clean previous word & metas.
			PRONOUNCIATION=''
			DEFINITION=''
			QUOTE=''
			ETYMOLOGY=''
			RELATIVE=''

			Anki_Front=''
			Anki_Back=''
			

			SOURCE=/tmp/.tridixsrc_$RANDOM
			TEMP=/tmp/.tridixtmp_$RANDOM
			CLEANUP=( "$SOURCE" "$TEMP" )

			if [ $MODE == 'En' ]; then
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


