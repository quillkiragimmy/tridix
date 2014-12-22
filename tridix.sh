#!/usr/bin/bash

	# text colors.
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

wowowo
diclist=~/tridixlist.list
mode='En'	#en,ja,la.
termgeom=( "$(tput lines)" "$(tput cols)" )
src=''
tmp=''
last=''
meta='' # related stuff.
bars=''       # used by j/ldic.

trap "rm -f $tmp $src && exit 0" SIGHUP SIGINT SIGTERM 

engcolorize(){
	while read line; do
		echo -e "$(echo "$line"\
			| sed "s/^verb/\\$bldblu[Verb]\\$txtrst/g"\
			| sed "s/^noun/\\$bldblu[Noun]\\$txtrst/g"\
			| sed "s/^adjective/\\$bldblu[Adj.]\\$txtrst/g"\
			| sed "s/^adverb/\\$bldblu[Adv.]\\$txtrst/g"\
			| sed "s/^\([0-9]\{1,2\}\.\)/\\$bldylw\1\\$txtrst/")"
	done
}

endic(){
	curl -sL http://dictionary.reference.com/browse/$(echo "$@"| tr ' ' '+')?s=t > $src

	if [ ! -z "$(fgrep 'Did you mean' $src)" ]; then
		xmllint --html --htmlout --xpath '//section[@class="more-suggestions"]' $src 2>/dev/null| w3m -T text/html| cat
	else
			# pronounce.
		pron="$(xmllint --html --htmlout --xpath '//*[@id="source-luna"]/div[1]/section/header/div[2]/div/span/span[2]' $src 2>/dev/null\
			| perl -pe 's/<.*?>//g')"
		echo $pron >> $tmp

			# relatives.
		rel="$(cat $src| xmllint --html --htmlout --xpath '//*[@class="tail-box tail-type-relf"]' - 2>/dev/null\
			| perl -pe 's/<.*?>//g'\
			| grep -v '^$'\
			| sed 's/Related forms Expand/[Related]/g'\
			| sed 's/Derived Forms/[Derived]/g')"

			# meaning.
		xmllint --html --htmlout --xpath '//section[@class="def-pbk"]' $src 2>/dev/null\
			| perl -pe 's/<.*?>//g'\
			| grep -v '^$'\
			| sed ':a;N;$!ba;s/\([0-9]\{1,2\}\.\)\n/\1) /g' >> $tmp

		echo "$rel" >> $tmp

		cat $tmp| fold -w${termgeom[1]} -s | engcolorize| more -df # more fold conflicts with escaping chars (real/logical length).

			# quote.
			# incline examples.
		quote="$(cat $tmp\
			| grep '\.).*:'\
			| cut -d':' -f2\
			| head -n3\
			| grep "$@"\
			| sed 's/$/<br>/'\
			| tr -d '\n')" 
		if [ -z "$quote" ]; then # search quote from web.
			quote="$(curl -s "$(cat $src | xmllint --html --htmlout --xpath '//*[@id="quotes-box"]/div/div/div[1]/a' - 2>/dev/null | cut -d'"' -f2) "\
				| xmllint --html --xpath '//*[@id="o111"]' - 2>/dev/null\
				| sed 's/<br>/. /g'| perl -pe 's/<.*?>//g'\
				| tr '\n' ' ')"

			# trim if over 100 chars.
			if (( "$(echo "$quote"| wc -c)" > 100 )); then
				quote="$(echo $quote\
					| sed 's/\([!?.]\)/\1\n/g'\
					| grep -i "$@" ) "
			fi
			if (( "$(echo "$quote"| wc -c)" > 100 )); then
				quote="$(echo $quote\
					| sed 's/\([,:]\)/\1\n/g'\
					| grep -i -A1 -B1 "$@" ) "
			fi
			quote="$(echo "$quote"| tr -d '\n')"
		fi

		meta="$pron<br>\"$quote\"<br>$(echo "$rel"| sed 's/$/<br>/'| tr -d '\n') "

	fi
}

jadic(){
	curl http://www.weblio.jp/content/"$@" -s > $src
	if [ "$(cat $src| fgrep '見出し語は見つかりません')" == '' ]; then	# for error fetching.
		xmllint --html --htmlout  --format --xpath '//div[@class="kijiWrp"]' $src 2>/dev/null\
			| sed 's/<!--開始/━━━━━━━━━━━━━\n@@/'\
			| perl -pe 's/<.*?>//g'\
			| sed 's/  /\n/g'\
			| grep -v '@@'\
			| grep -v '^$' > $tmp

		bars=( $(fgrep -n "━━━━━━━━━━━━━" $tmp| cut -d':' -f1) '$' )
		if [ "${bars[0]}" == '$' ]; then
			bars=( '1' $bars )
		fi
		sed -i -n "1,${bars[10]} p" $tmp 2>/dev/null

		cat $tmp| more -d

	fi

}

ladic(){
	echo "$@"| words| tr -d '\r' > $src
	orig=$(cat $src| grep -n '=>$'| cut -d':' -f1)
	end=$(cat $src| grep -n '=>Raised'| cut -d':' -f1)
	cat $src| sed -n "$((orig+1)), $((end-1)) p"\
		| grep -v '^$'\
		| tr '\r' ' '\
		| fgrep -v 'RETURN/ENTER'\
		| fgrep -v 'Unexpected exception'\
		| sed 's/\(;.*\)$/\1\n━━━━━━━━━━━━━/' >> $tmp

	bars=( '1' $(fgrep -n "━━━━━━━━━━━━━" $tmp| cut -d':' -f1) '$' )

	cat $tmp| more -d

	rm -f "$src"
}

header(){
	# another word or add previous to history.
	echo -e "$bldred$mode)$bldgrn <word>|<index>|<command>|help; $txtrst($(wc -l $diclist | cut -d' ' -f1) listed. >>"
}

manpg(){
	echo -e "$txtylw\tYou can enter :$txtrst"
	echo "1. Any phrase like 'dictionary' '辞書'."
	echo "2. 'e' / 'j' / 'l' to switch to Eng / Jap / Lat mode."
	echo "3. '' / '1' ... '9' to add N'th word into list."
	echo "4. Commands below :"
	echo -e "\tls: show list entries"
	echo -e "\tpg: purge list"
	echo -e "\td: delete last item in list"
	echo -e "\thelp: this help"
}

clear
touch "$diclist"
header
while read -e word; do
	termgeom=( "$(tput lines)" "$(tput cols)" )

	case "$word" in
		''|1|2|3|4|5|6|7|8|9)
			if [ "$word" == '' ]; then word='1'; fi # enlist first word.

			if [ -e "$tmp" ]; then

				if [ $mode == 'En' ]; then
					echo -e "engmisc\tBasic\t1\t$last<br>$meta\t$(cat $tmp\
						| tr '\n' ' '\
						| sed 's/\( [0-9]\{1,2\}\.\)/ <br>\1/g')" >> $diclist

				elif [ $mode == 'Ja' ]; then
					slot=$(cat $tmp\
						| sed -n "${bars[word-1]}, ${bars[word]} p"\
						| egrep -v '^[ ]*$'\
						| grep -v '━'\
						| tr '\n' ' '\
						| tr -d ' ')

						# quote.
					meta="$(echo $slot\
						| tr -d '\n'\
						| sed 's/「/\n「/g' | sed 's/」.*/」/'\
						| grep '」' | head -n5\
						| grep '－'\
						| tr '\n' '#'| sed 's/#/<br>/g')"

						# find kanji(if any).
					kanji=''
					if [ ! -z "$(echo $slot| sed 's/\(.\{50,50\}\).*/\1/'| fgrep '【')" ]; then
						kanji="$(echo $slot| sed 's/\(.\{50,50\}\).*/\1/'| perl -pe 's/.*?(【.*?】).*/\1/')"
					else
						kanji="$last"
					fi
						# make kanji be the frontside if possible.
					echo -e "日本語雑魚\tBasic\t1\t$kanji<br>$meta\t$slot" >> $diclist

				elif [ $mode == 'La' ]; then
					slot=$(cat $tmp\
						| sed -n "${bars[word-1]}, ${bars[word]} p"\
						| grep -v '━'\
						| sed 's/\s\{1,99\}/ /g'\
						| sed 's/$/<br>/g'\
						| tr '\n' ' ')

					meta="$(echo $slot| sed 's/<br>/\n/g'| fgrep '[')"
					echo -e "VOCABULAE\tBasic\t1\t$last<br>$meta\t$(echo $slot)" >> $diclist

				fi 
				echo -e "$(echo -e "$last\n$meta"| sed 's/<br>/\n/g' ) "
				rm -f $tmp
			fi
			;;

		e)
			echo -e "$bldylw >> English Mode.$txtrst"	
			mode='En'
			;;

		j)
			echo -e "$bldylw >> 日本語モード$txtrst"	
			mode='Ja'
			;;

		l)
			echo -e "$bldylw >> MODVSLATINVS$txtrst"	
			mode='La'
			;;

		pg)
			echo -e "$bldylw >> Purge list.$txtrst"	
			mv $diclist "$diclist"_bak
			touch $diclist
			;;

		d)
			echo -e "$bldylw >> delete last entry.$txtrst"
			tail -n1 $diclist| cut -d'<' -f1
			sed -i '$d' $diclist
			;&

		ls)
			listtmp="$(cat $diclist\
				| cut -f1,4| cut -d'<' -f1\
				| sed s/日本語雑魚/\\$bldwht/ \
				| sed s/engmisc/\\$bldylw/ \
				| sed s/VOCABULAE/\\$bldgrn/ ) $txtrst"

				echo -e "$listtmp" | more -d
			;;

		help)
			manpg
			;;

		*)
			rm -f "$tmp"
			last='' # clean last_word & metas.
			meta=''

			src=/tmp/.dicsrc_$RANDOM
			tmp=/tmp/.dictmp_$RANDOM

			if [ $mode == 'En' ]; then
				endic "$word"
			elif [ $mode == 'Ja' ]; then
				jadic "$word"
			elif [ $mode == 'La' ]; then
				ladic "$word"
			fi

			last="$word"
			rm -f "$src"
			;;
	esac

	header

done


