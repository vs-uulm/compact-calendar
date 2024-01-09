#!/bin/sh

[[ "$(command -v curl)" ]] || { echo "curl is not installed" 1>&2; exit 1; }
[[ "$(command -v awk)" ]] || { echo "awk is not installed" 1>&2; exit 1; }
[[ "$(command -v jq)" ]] || { echo "jq is not installed" 1>&2; exit 1; }

(echo "$1" | grep -Eq  ^[0-9]{4}[sw]$) || { echo "Usage: $0 [year(s|w)] (e.g., $(date +%Y)s)" 1>&2; exit 1; }

YEAR=$(echo $1 | cut -c 1-4)
FILE="$1-compact.tex"

if [ "$(echo $1 | cut -c 5)" = "w" ]; then
    SEARCH="Wintersemester $YEAR"
else
    SEARCH="Sommersemester $YEAR"
fi

echo $SEARCH
IFS=';' read SEMESTER anfang zwischen ende <<< $(curl https://www.uni-ulm.de/studium/studienorganisation/vorlesungen/vorlesungszeiten/ | tr '\n' ' ' | sed 's/<tr/\n<tr/g' | grep '<tr' | grep "$SEARCH" | grep -i semester | sed 's/<\/tr.*//' | sed -e 's/<\/td[^<]*<td[^>]*>/\t/g' | sed 's/.*<td[^>]*>//' | sed 's/<.*//' | awk -F '\t' '{ print $1";"$3";"$5";"$7 }')

BEGIN=$(echo $anfang | sed 's/[^0-9]*//g' | sed 's/\(..\)\(..\)\(....\)/\3-\2-\1/')
BETWEEN=$(echo $zwischen | sed 's/[^0-9]*//g' | sed 's/\(..\)\(..\)\(....\)\(..\)\(..\)\(....\)/\3-\2-\1 and \6-\5-\4/')
END=$(echo $ende | sed 's/[^0-9]*//g' | sed 's/\(..\)\(..\)\(....\)/\3-\2-\1/')

FIRST=$(echo $BEGIN | sed 's/-..$/-01/')
LAST=$(echo $END | sed 's/-..$/-31/')

tee $FILE << EOM
\documentclass[a4paper]{article}

\usepackage{fontspec}
\setmainfont[
Mapping=tex-text,Numbers={OldStyle,Proportional},Scale=.96,
BoldFont={MetaPro-Bold},
BoldItalicFont={MetaPro-BoldItalic},
ItalicFont={MetaPro-BookItalic}
]{MetaPro-Book}

\usepackage{uulm-logos}
\usepackage[margin=2cm]{geometry}
\usepackage{tikz}
\usetikzlibrary{calendar,decorations.markings}
\def\pgfcalendarmonthname#1{%
\translate{\ifcase#1%
\or Januar
\or Februar
\or März
\or April
\or Mai
\or Juni
\or Juli
\or August
\or September
\or Oktober
\or November
\or Dezember
\fi}}

% Color Theme
\definecolor{uulm}{RGB}{130,161,180}
\definecolor{uulm-akzent}{rgb}{.663 .635 .553}
\definecolor{uulm-in}{rgb}{.639 .149 .230}
\definecolor{uulm-med}{rgb}{0.4901,0.6039,0.6666}
\definecolor{uulm-mawi}{rgb}{0.3372,0.6667,0.1098}
\definecolor{uulm-nawi}{rgb}{0.7411,0.3764,0.0196}

\pagestyle{empty}

\begin{document}
\noindent\begin{tikzpicture}
\fill[uulm-akzent!15,rounded corners] (0,0) rectangle (.95*\linewidth,3em);
\node[anchor=east] at (\linewidth,1.5em) {\vslogo};
\end{tikzpicture}

\par\vspace{2em}
\noindent{\large ${SEMESTER}}
\vspace{1em}

\tikzstyle{feiertag}=[uulm-akzent!40]
\tikzstyle{first}+=[black,font=\bfseries]
\tikzstyle{semester}+=[uulm-in,font=\bfseries]

\noindent\begin{tikzpicture}
\calendar[dates=$FIRST to $LAST, week list, month label left, month yshift=0, day yshift=2em] ($1)
if (at most=$BEGIN) [uulm-akzent!40] else [black!80]
if (at least=$END) [uulm-akzent!40]
$(echo "if (between=$BETWEEN) [uulm-akzent!40]" | grep and) %
% Feiertage
$(curl "https://feiertage-api.de/api/?jahr=${YEAR}&nur_land=BW" | jq -r '.[] | select( .hinweis == ""  ) | .datum' | sed 's/^\(.*\)$/if \(equals=\1\) [feiertag]/')
$(curl "https://feiertage-api.de/api/?jahr=$((YEAR + 1))&nur_land=BW" | jq -r '.[] | select( .hinweis == ""  ) | .datum' | sed 's/^\(.*\)$/if \(equals=\1\) [feiertag]/')
if (weekend) [uulm-akzent!40]
if (day of month=1) [first]
% Semesterbeginn/-ende
if (equals=$BEGIN) [semester]
if (equals=$END) [semester]
;

\coordinate (top) at ($1-$FIRST.south east);
\coordinate (bottom) at ($1-$FIRST.south east |- $1-$LAST.south east);

\draw[decorate,decoration={
markings,%
mark=between positions 0.0 and 1.0 step 2em with {%
\draw[uulm-akzent,dotted] (0pt,3.8cm) -- (0pt,14.4cm);
}}] (top) -- (bottom) -- ++(0,-1em);

\end{tikzpicture}
\end{document}
EOM
