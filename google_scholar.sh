#!/usr/bin/env bash

#project path
proj_dir="$(pwd)"

#if option is not within allowed options
if  [[ ($1 != "-i" && $1 != "-h" && $1 != "") || $2 != "" ]]; then
    echo "[ERRO] Parâmetro(s) não suportado(s)"
    exit 0
fi

#help option selected (-h):
if  [[ $1 = "-h" || $1 = "-help" ]]; then
    echo "Opção -i: descarrega a página associada a cada perfil e grava no subdiretório Scholar com o nome indicado como 2º elemento da linha"
    echo ""
    echo "Nenhuma opção indicada: procura no subdiretório Scholar os ficheiros HTML indicados como 2o elemento no ficheiro scholar_URLs.txt"
    echo ""
    exit 0
fi

#if scholar_URLs.txt does not exist
if ! find scholar_URLs.txt &> /dev/null; then
	echo "[ERRO] Não foi possivel encontrar ‘scholar_URLs.txt’"
	exit 0
fi

#if option -i is selected
if  [[ $1 = "-i" ]]; then
	#create directory Scholar only if it doesn't already exist
	mkdir -p Scholar
fi

#read file scholar_URLs.txt
#auxiliary file without commented URLs (#):
grep -v "#" scholar_URLs.txt > scholar_URLs_aux.txt

#read the file line by line
while read line; do
	URL="$(echo $line | cut -d "|" -f1)"
	filename="$(echo $line | cut -d "|" -f2)"
	
	cd Scholar 2> /dev/null || rm scholar_URLs_aux.txt	2> /dev/null
	
	echo "[A processar]: "$URL	
	#if option -i is selected
	if  [[ $1 = "-i" ]]; then
		wget -q "$URL" -O $filename 			
	#if no option is selected
	else		
		#if the file is not found, show error and go to next line to be read
		if ! find $filename &> /dev/null; then
			echo "[ERRO] Não foi possível encontrar o ficheiro ‘$filename’"
			echo ""			
			cd $proj_dir
			continue
		fi
		echo "[INFO] A utilizar o ficheiro local '$filename'"
	fi

	#file $filename.html checks file encoding
	#OUTPUT: HTML document, ISO-8859 text, with very long lines --> convert with iconv command and option -f 8859_1

	#get Scholar info and store it in variables
	name="$(iconv -f 8859_1 $filename | tr '>' '\n' | grep -A 12 "Seguir</" | tail -n 1 | cut -d '<' -f1)"
	name_trimmed="$(echo $name | tr -d ' ')"
	num_citations="$(iconv -f 8859_1 $filename | tr '>' '\n' | grep -A 3 "Citações</a" | tail -n 1 | cut -d '<' -f1)"
	num_citations_last_5years="$(iconv -f 8859_1 $filename | tr '>' '\n' | grep -A 5 "Citações</a" | tail -n 1 | cut -d '<' -f1)"
	h_index="$(iconv -f 8859_1 $filename | tr '>' '\n' | grep -A 3 "Índice h</a" | tail -n 1 | cut -d '<' -f1)"
	h_index_last_5years="$(iconv -f 8859_1 $filename | tr '>' '\n' | grep -A 5 "Índice h</a" | tail -n 1 | cut -d '<' -f1)"
	
	#show Scholar info
	echo "Scholar: '$name_trimmed'"
	echo "Citacoes - Total $num_citations, ultimos 5 anos: $num_citations_last_5years"
	echo "H-Index - Total: $h_index, ultimos 5 anos: $h_index_last_5years"

	#add to file .db with variables	
	grep -q "# Ficheiro:" $name_trimmed.db 2> /dev/null 	|| echo "# Ficheiro: '$name_trimmed.db'" >> $name_trimmed.db
	grep -q "# Info Scholar:" $name_trimmed.db 2> /dev/null || echo "# Info Scholar: '$name_trimmed'" >> $name_trimmed.db
	grep -q "# Criado em:" $name_trimmed.db 2> /dev/null 	|| echo "# Criado em: $(date +"%Y.%m.%d_%Hh%M:%S")" >> $name_trimmed.db
	grep -q "# Citacoes:" $name_trimmed.db 2> /dev/null 	|| echo "# Citacoes:Citacoes-5anos:h-index:h-index_5anos" >> $name_trimmed.db
	
	#count lines in .db file
	num_lines_dbfile="$(cat $name_trimmed.db | wc -l)"
	
	#if it's not the first time to add to file (lines != 4):
	if [ $num_lines_dbfile -ne 4 ]; then
		head -q -n $(($num_lines_dbfile-1)) $name_trimmed.db > $name_trimmed_aux.db
		echo "$(date +"%Y.%m.%d"):$num_citations:$num_citations_last_5years:$h_index:$h_index_last_5years" >> $name_trimmed_aux.db
		echo "# Ultima atualizacao: $(date +"%Y.%m.%d_%Hh%M:%S")" >> $name_trimmed_aux.db
		rm $name_trimmed.db; mv $name_trimmed_aux.db $name_trimmed.db
	else
		echo "$(date +"%Y.%m.%d"):$num_citations:$num_citations_last_5years:$h_index:$h_index_last_5years" >> $name_trimmed.db
		echo "# Ultima atualizacao: $(date +"%Y.%m.%d_%Hh%M:%S")" >> $name_trimmed.db
	fi	

	echo ""

	cd $proj_dir
done < scholar_URLs_aux.txt

rm scholar_URLs_aux.txt	2> /dev/null


#references:
#why use iconv: https://stackoverflow.com/questions/4739480/grep-regex-cant-find-accented-word --> convert file encoding
#how to read .txt files line by line: https://linuxhint.com/read_file_line_by_line_bash/
#how to set options on a unix shell script: https://stackoverflow.com/questions/14513305/how-to-write-unix-shell-scripts-with-options
