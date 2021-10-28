#!/bin/bash

# Beschreibung:
# Das Skript liest Daten wie Temperaturen, Spannungen, etc. vom 1-Wire Bus
# mittels One Wire File System (owfs) und schreibt diese dann per knxtool (knxd)
# auf Gruppenadressen am KNX-Bus. Um die Buslast am KNX-Bus gering zu halten,
# werden die Daten nur dann geschrieben, wenn eine Änderung stattgefunden hat,
# oder ein definiertes Zeitintervall abgelaufen ist.
#
# Abhängigkeiten:   - owshell/owget (1-wire access programs)
#                   - owfs (1-wire file system)
#                   - knxd/knxtool (A stack for EIB/KNX)
#                   - bc (An arbitrary precision calculator language)
#
# Autor: Sebastian Schnittert (schnittert@gmail.com)
# Datum: 28.10.2021

# Intervall (in Sekunden) der zyklischen Abfrage der 1-Wire Daten
REFRESH_INTERVALL=20
# Intervall (in Sekunden) nach dem ein Datum auch ohne Änderung erneut auf den Bus gelegt werden soll
REPEAT_INTERVALL=900 # 15 min.

# Auflösung (in Bit) mit der die Daten gelesen werden sollen [9-12]
# Hinweis: Eine geringere Auflösung resultiert in schnelleren Lesezeiten, ergibt aber ungenauere Wert.
#          Die KNX-Buslast wird dadurch jedoch verringert, da sich der Wert seltener ändert.
DATA_RESOLUTION=10
# Sollen die Daten auf eine Nachkommastelle gerundet werden?
ROUND_TO_TENTH="TRUE"
# Mount-Punkt des 1-wire subsystems
OWFS_MOUNTPOINT="/mnt/1wire"

# IP-Adresse des knxd-Host ("localhost", wenn gleicher Rechner)
KNXD_HOST="localhost"
# Befehl zum Schreiben einer Gruppenadresse
KNX_GROUPWRITE="knxtool groupwrite ip:${KNXD_HOST}"

# Die Zuordnung der 1-wire Bus-Adressen zu den KNX-Gruppenadressen erfolgt in den folgenden Arrays
# Bedeutung der Felder: ('1-Wire Adresse' 'KNX-Gruppenadresse' 'KNX DPT Format' 'Beschreibung')
# Hinweis: Die letzten beiden Felder sind aktuell ungenutzt und dienen nur als Kontextinformation.

# Kellergeschoss (KG)

declare -a OW_NODE_1=('28.FF2E4DC11604' '7/0/0' '9.001' 't015 - Temperatur KG Decke Garage')
declare -a OW_NODE_2=('28.FF445CC11604' '7/0/1' '9.001' 't012 - Temperatur KG Decke Abstellraum')
declare -a OW_NODE_3=('28.FFC271C11604' '7/0/2' '9.001' 't025 - Temperatur KG Decke Keller 1')
declare -a OW_NODE_4=('28.FFCD9BC11604' '7/0/3' '9.001' 't017 - Temperatur KG Decke Flur')
declare -a OW_NODE_5=('28.FF056FC11604' '7/0/4' '9.001' 't011 - Temperatur KG Decke WC')
declare -a OW_NODE_6=('28.FF594BC11604' '7/0/5' '9.001' 't026 - Temperatur KG Decke Keller 2')
declare -a OW_NODE_7=('28.FF3DE3B41605' '7/0/6' '9.001' 't033 - Temperatur KG Decke Büro')

# Erdgeschoss (EG)

declare -a OW_NODE_8=('28.FF2689B51603' '7/0/7' '9.001' 't021 - Temperatur EG Decke Büro')
declare -a OW_NODE_9=('28.FF7A9AC11604' '7/0/8' '9.001' 't024 - Temperatur EG Decke Küche')
declare -a OW_NODE_10=('28.FF65A8B51603' '7/0/9' '9.001' 't035 - Temperatur EG Decke Essen')
declare -a OW_NODE_11=('28.FF4F9DB51603' '7/0/10' '9.001' 't023 - Temperatur EG Decke Wohnen')
declare -a OW_NODE_12=('28.FFEA57C11604' '7/0/11' '9.001' 't020 - Temperatur EG Decke WC')
declare -a OW_NODE_13=('28.FFEC91B41605' '7/0/12' '9.001' 't027 - Temperatur EG Decke Flur')

# Dachgeschoss (DG)

declare -a OW_NODE_14=('28.FFAD83B51603' '7/0/13' '9.001' 't034 - Temperatur DG Decke Abstell')
declare -a OW_NODE_15=('28.FFCEC2B51603' '7/0/14' '9.001' 't029 - Temperatur DG Decke Bad')
declare -a OW_NODE_16=('28.FF41E2B41605' '7/0/15' '9.001' 't018 - Temperatur DG Decke Wäsche')
declare -a OW_NODE_17=('28.FFBDF3B41605' '7/0/16' '9.001' 't022 - Temperatur DG Decke Ankleide')
declare -a OW_NODE_18=('28.FF5385B51603' '7/0/17' '9.001' 't032 - Temperatur DG Decke Schlafen')
declare -a OW_NODE_19=('28.FF56EBB41605' '7/0/18' '9.001' 't031 - Temperatur DG Decke Kind')
declare -a OW_NODE_20=('28.FF53A3B51603' '7/0/19' '9.001' 't028 - Temperatur DG Decke Flur')
declare -a OW_NODE_21=('28.FF9288B51603' '7/0/20' '9.001' 't014 - Temperatur SB Decke Kind')

# Sonnenspeicher

declare -a OW_NODE_22=('28.C9C24D0A0000' '7/2/0' '9.001' 't036 - Temperatur Speicher 5450 mm')
declare -a OW_NODE_23=('28.08EB4D0A0000' '7/2/1' '9.001' 't037 - Temperatur Speicher 5300 mm')
declare -a OW_NODE_24=('28.4F734E0A0000' '7/2/2' '9.001' 't038 - Temperatur Speicher 5130 mm')
declare -a OW_NODE_25=('28.BA754E0A0000' '7/2/3' '9.001' 't039 - Temperatur Speicher 4980 mm')
declare -a OW_NODE_26=('28.72FD4E0A0000' '7/2/4' '9.001' 't040 - Temperatur Speicher 4840 mm')
declare -a OW_NODE_27=('28.39764E0A0000' '7/2/5' '9.001' 't041 - Temperatur Speicher 4540 mm')
declare -a OW_NODE_28=('28.0164500A0000' '7/2/6' '9.001' 't042 - Temperatur Speicher 4250 mm')
declare -a OW_NODE_29=('28.BA574E0A0000' '7/2/7' '9.001' 't043 - Temperatur Speicher 3680 mm')
declare -a OW_NODE_30=('28.A3414E0A0000' '7/2/8' '9.001' 't044 - Temperatur Speicher 3110 mm')
declare -a OW_NODE_31=('28.C7614E0A0000' '7/2/9' '9.001' 't045 - Temperatur Speicher 2530 mm')
declare -a OW_NODE_32=('28.A6D94F0A0000' '7/2/10' '9.001' 't046 - Temperatur Speicher 1970 mm')
declare -a OW_NODE_33=('28.252F4E0A0000' '7/2/11' '9.001' 't047 - Temperatur Speicher 1400 mm')
declare -a OW_NODE_34=('28.D5DA4F0A0000' '7/2/12' '9.001' 't048 - Temperatur Speicher 840 mm')
declare -a OW_NODE_35=('28.DDD94D0A0000' '7/2/13' '9.001' 't049 - Temperatur Speicher 450 mm')
declare -a OW_NODE_36=('28.95764D0A0000' '7/2/14' '9.001' 't050 - Temperatur Speicher 170 mm')

# Höchste Knotennummer (nicht alle Knoten darunter müssen definiert sein).
OW_NODE_MAX=40

main() {
    # Skript wiederholen, solange ein owfs gemountet ist.
    while [ -n "$(ls -A "${OWFS_MOUNTPOINT}/system")" ]; do
        # Über die 1-Wire Nodes iterieren.
        i=1
        while [ "$i" -le "${OW_NODE_MAX}" ]; do
            # Adressen aus dem Array referenzieren
            local OW_ADR="OW_NODE_${i}[0]"
            local GRP_ADR="OW_NODE_${i}[1]"
            # Data-Cache und Timestamp referenzieren
            local CACHE="OW_DATA_CACHE_${i}"
            local TIMESTAMP="OW_TIMESTAMP_${i}"
            # Timestamp beim ersten Durchlauf setzen
            if [ -z "${!TIMESTAMP}" ]; then
                eval "${TIMESTAMP}=0"
            fi

            # Ist eine 1-Wire Adresse definiert?
            if [ -n "${!OW_ADR}" ] && [ -n "${!GRP_ADR}" ]; then
                # Das Datum vom 1-Wire File System holen. Leerzeichen entfernen.
                DEC="$(owget "/"${!OW_ADR}"/temperature"${DATA_RESOLUTION} | xargs)"
                # Falls aktiviert, auf eine Nachkommastelle runden
                if [ "${ROUND_TO_TENTH}" == "TRUE" ]; then
                    DEC="$(printf "%.1f" "${DEC}")"
                fi
                # Die Zeit seit der letzten Aktualisierung berechnen
                ELAPSED=$(($(date +%s)-${!TIMESTAMP}))
                # Hat eine Änderung des Datums stattgefunden? (KNX-Last verringern)
                # ODER ist das Wiederholungs-Intervall abgelaufen?
                if [ "${!CACHE}" != "${DEC}" ] || [ "${ELAPSED}" -ge "${REPEAT_INTERVALL}" ]; then
                    # Das neue Datum sichern
                    eval "${CACHE}=${DEC}"
                    # Den aktuellen Timestamp setzen
                    eval "${TIMESTAMP}=$(date +%s)"
                    # In das DPT-Format konvertieren
                    HEX="$(dec_to_dpt_9 "${DEC}")"
                    # Die Gruppenadresse beschreiben
                    eval "${KNX_GROUPWRITE} ${!GRP_ADR} ${HEX} &> /dev/null"
                fi
            fi
            i=$(($i + 1))
        done
        # Abwarten
        sleep "${REFRESH_INTERVALL}"
    done
}

# Funktionsbeschreibung:
# Der Eingabeparameter in Dezimalschreibweise (z.B. 154.93) wird 
# in das KNX DPT 9.xxx Format umgewandelt und als 2-Byte Hex zurückgegeben.
# Binärformat des DPT 9.xxx:    FEEEEMMM MMMMMMMM
#                               F = 0/1 -> positiver/negativer Wert
#                               E = Exponent
#                               M = Mantisse
# Uwandlung: Dezimalwert = ((1-2*F) * 2^E * M) / 100
#
# Funktionsparameter: $1 - Dezimalwert zur Umrechnung in DPT 9.xxx
#                     $2 - Multiplikationsfaktor (z.B. um Einheiten anzupassen)
#
# Abhängigkeiten:   - bc (An arbitrary precision calculator language)
#
# Autor: Sebastian Schnittert (schnittert@gmail.com)
# Datum: 18.10.2020
dec_to_dpt_9() {

    # Multiplikationsfaktor setzen
    FACT="1"
    if [[ $# -gt 1 ]] ; then
        FACT=$2
    fi

    # Exponent initialisieren
    let E=0
    # Zwei Dezimalstellen mitnehmen
    M=$(bc <<< "$1*$FACT*100/1")

    # Exponenten bestimmen
    while [ "$M" -gt 2047 ] || [ "$M" -lt -2047 ]; do
        M=$(bc <<< "$M/2")
        let E++
    done

    # Zweier-Komplement für negative Werte
    if [ "$M" -lt 0 ]; then
        M=$(bc <<< "2^12+$M")
    fi
        
    # Binärwerte zusammenbauen
    EB=$(printf "%4b" "$(bc <<< "obase=2; $E")" | sed 's^ ^0^g')
    MB=$(printf "%12b" "$(bc <<< "obase=2; $M")" | sed 's^ ^0^g')
    B=$(cut -c -1 <<< "$MB")${EB}$(cut -c 2- <<< "$MB")

    # Als Hex formatieren
    H=$(printf "%04X" "$(bc <<< "obase=10;ibase=2; $B")")
    echo "$(cut -c -2 <<< "$H") $(cut -c 3- <<< "$H")"
}

# Main-Funktion mit allen Kommandozeilen-Parametern aufrufen
main "$@"