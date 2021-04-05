#!/bin/bash

# VICHS AdBlockID v1.3.0
# Based on VICHS v2.26.3

# MIT License
# Copyright (c) 2021 Polish Filters Team


SCRIPT_PATH=$(dirname "$(realpath -s "$0")")

# MAIN_PATH is where the repository root is located (we assume that the script is in the
# directory 1 lower than the root of the repository)
MAIN_PATH="$SCRIPT_PATH"

# Go to the directory where the local git repository is located
cd "$MAIN_PATH" || exit

# Location of the configuration file
CONFIG=$SCRIPT_PATH/VICHS.config


for i in "$@"; do

    function externalCleanup {
        sed -i '/! Checksum/d' "$EXTERNAL_TEMP"
        sed -i '/!#include /d' "$EXTERNAL_TEMP"
        sed -i '/Adblock Plus 2.0/d' "$EXTERNAL_TEMP"
        sed -i '/! Dołączenie listy/d' "$EXTERNAL_TEMP"
        sed -i "s|^!$|!@|g" "$EXTERNAL_TEMP"
        sed -i "s|^! |!@ |g" "$EXTERNAL_TEMP"
    }

    function getOrDownloadExternal {
        # We assume that the directory containing other cloned repository is higher than
        # the directory of our own list
        if [[ -n "$CLONED_EXTERNAL" ]] && [[ -f "$MAIN_PATH/../$CLONED_EXTERNAL" ]]; then
            CLONED_EXTERNAL_FILE="$MAIN_PATH/../$CLONED_EXTERNAL"
        else
            if ! wget -O "$EXTERNAL_TEMP" "${EXTERNAL}"; then
                printf "%s\n" "$(gettext "Error during file download")"
                git checkout "$FINAL"
                rm -r "$EXTERNAL_TEMP"
                exit 0
            fi
        fi
    }

    function getConvertableRulesForHosts() {
        HOSTS_TEMP="$SECTIONS_DIR/TEMP_CONVERT.temp-hosts"
        {
            grep -o '^||.*^$' "$1"
            grep -o '^0.0.0.0.*' "$1"
            # shellcheck disable=SC2016
            grep -o '^||.*^$all$' "$1"
        } >>"$HOSTS_TEMP"
    }

    function convertToHosts() {
        sed -i "s|\$all$||" "$HOSTS_TEMP"
        sed -i "s|[|][|]|0.0.0.0 |" "$HOSTS_TEMP"
        sed -i 's/[\^]//g' "$HOSTS_TEMP"
        sed -i '/[/\*]/d' "$HOSTS_TEMP"
        sed -i -r "/0\.0\.0\.0 [0-9]?[0-9]?[0-9]\.[0-9]?[0-9]?[0-9]\.[0-9]?[0-9]?[0-9]\.[0-9]?[0-9]?[0-9]/d" "$HOSTS_TEMP"
        sed -r "/^0\.0\.0\.0 (www\.|www[0-9]\.|www\-|pl\.|pl[0-9]\.)/! s/^0\.0\.0\.0 /0.0.0.0 www./" "$HOSTS_TEMP" >"$HOSTS_TEMP.2"
        if [ -f "$HOSTS_TEMP.2" ]; then
            cat "$HOSTS_TEMP" "$HOSTS_TEMP.2" >"$HOSTS_TEMP.3"
            mv "$HOSTS_TEMP.3" "$HOSTS_TEMP"
            rm -r "$HOSTS_TEMP.2"
        fi
        sort -uV -o "$HOSTS_TEMP" "$HOSTS_TEMP"
        SECTION="$HOSTS_TEMP"
    }

    function convertToDomains() {
        sed -i "s|\$all$||" "$HOSTS_TEMP"
        sed -i "s|[|][|]||" "$HOSTS_TEMP"
        sed -i 's/[\^]//g' "$HOSTS_TEMP"
        sed -i '/[/\*]/d' "$HOSTS_TEMP"
        sed -r "/^(www\.|www[0-9]\.|www\-|pl\.|pl[0-9]\.|[0-9]?[0-9]?[0-9]\.[0-9]?[0-9]?[0-9]\.[0-9]?[0-9]?[0-9]\.[0-9]?[0-9]?[0-9])/! s/^/www./" "$HOSTS_TEMP" >"$HOSTS_TEMP.2"
        if [ -f "$HOSTS_TEMP.2" ]; then
            cat "$HOSTS_TEMP" "$HOSTS_TEMP.2" >"$HOSTS_TEMP.3"
            mv "$HOSTS_TEMP.3" "$HOSTS_TEMP"
            rm -r "$HOSTS_TEMP.2"
        fi
        sort -uV -o "$HOSTS_TEMP" "$HOSTS_TEMP"
        SECTION="$HOSTS_TEMP"
    }

    function getConvertableRulesForPH() {
        PH_TEMP="$SECTIONS_DIR/TEMP_CONVERT.temp-ph"
        {
            grep -o '^||.*\*.*^$' "$1"
            # shellcheck disable=SC2016
            grep -o '^||.*\*.*^$all$' "$1"
        } >>"$PH_TEMP"
    }

    function convertToPihole() {
        sed -i "s|\$all$||" "$PH_TEMP"
        sed -i "s|[|][|]|0.0.0.0 |" "$PH_TEMP"
        sed -i 's/[\^]//g' "$PH_TEMP"
        sed -i -r "/0\.0\.0\.0 [0-9]?[0-9]?[0-9]\.[0-9]?[0-9]?[0-9]\.[0-9]?[0-9]?[0-9]\.[0-9]?[0-9]?[0-9]/d" "$PH_TEMP"
        sed -r "/^0\.0\.0\.0 (www\.|www[0-9]\.|www\-|pl\.|pl[0-9]\.)/! s/^0\.0\.0\.0 //" "$PH_TEMP" >>"$PH_TEMP.2"
        sed -i '/^0\.0\.0\.0\b/d' "$PH_TEMP.2"
        sed -i 's|\.|\\.|g' "$PH_TEMP.2"
        sed -i 's|^|(^\|\\.)|' "$PH_TEMP.2"
        sed -i "s|$|$|" "$PH_TEMP.2"
        sed -i "s|\*|.*|" "$PH_TEMP.2"
        rm -rf "$PH_TEMP"
        mv "$PH_TEMP.2" "$PH_TEMP"
        sort -uV -o "$PH_TEMP" "$PH_TEMP"
        SECTION="$PH_TEMP"
    }

    function initVars() {
        EXTERNAL=$(awk -v instruction="@$1" '$1 == instruction { print $2; exit }' "$FINAL")
        CLONED_EXTERNAL=$(awk -v instruction="@$1" '$1 == instruction { print $3; exit }' "$FINAL")
        SECTION=${SECTIONS_DIR}/${EXTERNAL}.${SECTIONS_EXT}
    }

    function initCVars() {
        LOCAL=${SECTIONS_DIR}/$(awk -v instruction="@$1" '$1 == instruction { print $2; exit }' "$FINAL").${SECTIONS_EXT}
        EXTERNAL=$(awk -v instruction="@$1" '$1 == instruction { print $3; exit }' "$FINAL")
        CLONED_EXTERNAL=$(awk -v instruction="@$1" '$1 == instruction { print $4; exit }' "$FINAL")
    }

    function includeSection() {
        sed -e '0,/^@'"$1"'/!b; /@'"$1"'/{ r '"$SECTION"'' -e 'd }' "$FINAL" >"$TEMPORARY"
        mv "$TEMPORARY" "$FINAL"
        if [[ "$1" != "include" ]]; then
            rm -rf "$SECTION"
        fi
        if [ -f "$EXTERNAL_TEMP" ]; then
            rm -r "$EXTERNAL_TEMP"
        fi
    }

    # FILTERLIST is the name of the file (without extension) that we want to build
    FILTERLIST_FILE=$(basename "$i")
    FILTERLIST="${FILTERLIST_FILE%.*}"

    # Set the path to templates
    if grep -q "@templatesPath" "$CONFIG"; then
        TEMPLATE=$MAIN_PATH/$(grep -oP -m 1 '@templatesPath \K.*' "$CONFIG")/${FILTERLIST}.template
    else
        TEMPLATE=$MAIN_PATH/templates/${FILTERLIST}.template
    fi

    FINAL=$i
    FINAL_B=$MAIN_PATH/${FILTERLIST}.backup
    TEMPORARY=$MAIN_PATH/${FILTERLIST}.temp

    # Make a copy of the initial file
    cp -R "$FINAL" "$FINAL_B"

    # Replace the contents of the final file with template content
    cp -R "$TEMPLATE" "$FINAL"

    # Set a path to a section
    if grep -q "@path" "$FINAL"; then
        SECTIONS_DIR=$MAIN_PATH/$(grep -oP -m 1 '@path \K.*' "$FINAL")
    elif grep -q "@path" "$CONFIG"; then
        SECTIONS_DIR=$MAIN_PATH/$(grep -oP -m 1 '@path \K.*' "$CONFIG")
    else
        SECTIONS_DIR=$MAIN_PATH/sections/$FILTERLIST
    fi

    # Set section file extensions
    if grep -q "@sectionsExt" "$FINAL"; then
        SECTIONS_EXT="$(grep -oP -m 1 '@sectionsExt \K.*' "$FINAL")"
    elif grep -q "@sectionsExt" "$CONFIG"; then
        SECTIONS_EXT="$(grep -oP -m 1 '@sectionsExt \K.*' "$CONFIG")"
    else
        SECTIONS_EXT="txt"
    fi

    # Temporary file for saving external sections
    EXTERNAL_TEMP="$SECTIONS_DIR"/external.temp


    #
    # @include
    # ------------------------------------------------------------------------------------
    END=$(grep -oic '@include' "${TEMPLATE}")

    # Add sections to the right places
    for ((n = 1; n <= END; n++)); do
        initVars "include"
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            getOrDownloadExternal
            if [[ -n "$CLONED_EXTERNAL" ]] && [[ -f "$MAIN_PATH/../$CLONED_EXTERNAL" ]]; then
                touch "$EXTERNAL_TEMP"
                cp "$CLONED_EXTERNAL_FILE" "$EXTERNAL_TEMP"
            fi
            externalCleanup
            sed -i "1s|^|!@ >>>>>>>> $EXTERNAL\n|" "$EXTERNAL_TEMP"
            echo "!@ <<<<<<<< $EXTERNAL" >>"$EXTERNAL_TEMP"
            SECTION="$EXTERNAL_TEMP"
        fi
        includeSection "include"
    done


    #
    # @NWLinclude
    # ------------------------------------------------------------------------------------
    END_NWL=$(grep -oic '@NWLinclude' "${TEMPLATE}")

    # Add sections to the right places and replace them with exceptions
    for ((n = 1; n <= END_NWL; n++)); do
        initVars "NWLinclude"
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            getOrDownloadExternal
            if [[ -n "$CLONED_EXTERNAL" ]] && [[ -f "$MAIN_PATH/../$CLONED_EXTERNAL" ]]; then
                SECTION="$CLONED_EXTERNAL_FILE"
            else
                SECTION="$EXTERNAL_TEMP"
            fi
        fi
        WL_TEMP="$SECTIONS_DIR/$1.temp-wl"
        grep -o '^||.*^$' "$SECTION" >>"$WL_TEMP"
        sed -i "s|[|][|]|@@|" "$WL_TEMP"
        sed -i 's/[\^]//g' "$WL_TEMP"
        SECTION="$WL_TEMP"
        includeSection "NWLinclude"
    done


    #
    # @BNWLinclude
    # ------------------------------------------------------------------------------------
    END_BNWL=$(grep -oic '@BNWLinclude' "${TEMPLATE}")

    # Add sections to the right places and replace them with exceptions
    for ((n = 1; n <= END_BNWL; n++)); do
        initVars "BNWLinclude"
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            getOrDownloadExternal
            if [[ -n "$CLONED_EXTERNAL" ]] && [[ -f "$MAIN_PATH/../$CLONED_EXTERNAL" ]]; then
                SECTION="$CLONED_EXTERNAL_FILE"
            else
                SECTION="$EXTERNAL_TEMP"
            fi
        fi
        WL_TEMP="$SECTIONS_DIR/$1.temp-wl"
        grep -o '^||.*^$' "$SECTION" >>"$WL_TEMP"
        # shellcheck disable=SC2016
        grep -o '^||.*^$all$' "$SECTION" >>"$WL_TEMP"
        sed -i "s|\$all$|\$all,badfilter|" "$WL_TEMP"
        sed -i "s|\^$|\^\$badfilter|" "$WL_TEMP"
        SECTION="$WL_TEMP"
        includeSection "NWLinclude"
    done


    #
    # @URLUinclude
    # ------------------------------------------------------------------------------------
    END_URLU=$(grep -oic '@URLUinclude' "${TEMPLATE}")

    # Add unique rules from external lists
    for ((n = 1; n <= END_URLU; n++)); do
        EXTERNAL=$(awk '$1 == "@URLUinclude" { print $2; exit }' "$FINAL")
        CLONED_EXTERNAL=$(awk '$1 == "@URLUinclude" { print $3; exit }' "$FINAL")
        getOrDownloadExternal
        if [[ -n "$CLONED_EXTERNAL" ]] && [[ -f "$MAIN_PATH/../$CLONED_EXTERNAL" ]]; then
            touch "$EXTERNAL_TEMP"
            cp "$CLONED_EXTERNAL_FILE" "$EXTERNAL_TEMP"
        fi
        externalCleanup
        cp -R "$FINAL_B" "$TEMPORARY"
        sed -i "/!@>>>>>>>> ${EXTERNAL//\//\\/}/,/!@<<<<<<<< ${EXTERNAL//\//\\/}/d" "$TEMPORARY"
        sed -i "/!#if/d" "$TEMPORARY"
        sed -i "/!#endif/d" "$TEMPORARY"
        UNIQUE_TEMP=$SECTIONS_DIR/unique_external.temp
        diff "$EXTERNAL_TEMP" "$TEMPORARY" --new-line-format="" --old-line-format="%L" --unchanged-line-format="" >"$UNIQUE_TEMP"
        rm -rf "$EXTERNAL_TEMP"
        cp -R "$UNIQUE_TEMP" "$EXTERNAL_TEMP"
        rm -rf "$UNIQUE_TEMP"
        sed -i "1s|^|!@>>>>>>>> $EXTERNAL\n|" "$EXTERNAL_TEMP"
        echo "!@<<<<<<<< $EXTERNAL" >>"$EXTERNAL_TEMP"
        SECTION="$EXTERNAL_TEMP"
        includeSection "URLUinclude"
    done


    #
    # @COMBINEinclude
    # ------------------------------------------------------------------------------------
    END_COMBINE=$(grep -oic '@COMBINEinclude' "${TEMPLATE}")

    # Combine local and external sections into one and glue them to the right places
    for ((n = 1; n <= END_COMBINE; n++)); do
        initCVars "COMBINEinclude"
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            getOrDownloadExternal
            if [[ -n "$CLONED_EXTERNAL" ]] && [[ -f "$MAIN_PATH/../$CLONED_EXTERNAL" ]]; then
                touch "$EXTERNAL_TEMP"
                cp "$CLONED_EXTERNAL_FILE" "$EXTERNAL_TEMP"
                externalCleanup
                sort -u -o "$EXTERNAL_TEMP" "$EXTERNAL_TEMP"
            fi
            EXTERNAL_CTEMP="$EXTERNAL_TEMP"
        else
            EXTERNAL_CTEMP=${SECTIONS_DIR}/$(awk '$1 == "@COMBINEinclude" { print $3; exit }' "$FINAL").${SECTIONS_EXT}
        fi
        SECTIONS_TEMP=${SECTIONS_DIR}/temp/
        mkdir -p "$SECTIONS_TEMP"
        MERGED_TEMP=${SECTIONS_TEMP}/merged-temp.txt
        cat "$LOCAL" "$EXTERNAL_CTEMP" >>"$MERGED_TEMP"
        if [ -f "$FOP" ]; then
            python3 "${FOP}" --d "${SECTIONS_TEMP}"
        fi
        sort -uV -o "$MERGED_TEMP" "$MERGED_TEMP"
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            sed -i "1s|^|!@ >>>>>>>> $EXTERNAL + $(basename "$LOCAL")\n|" "$MERGED_TEMP"
            echo "!@ <<<<<<<< $EXTERNAL + $(basename "$LOCAL")" >>"$MERGED_TEMP"
        fi
        SECTION="$MERGED_TEMP"
        includeSection "COMBINEinclude"
        rm -rf "$SECTIONS_TEMP"
    done


    #
    # @HOSTSinclude
    # ------------------------------------------------------------------------------------
    END_HOSTS=$(grep -oic '@HOSTSinclude' "${TEMPLATE}")

    # Convert to hosts and add filter section/list content to the right places
    for ((n = 1; n <= END_HOSTS; n++)); do
        initVars "HOSTSinclude"
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            getOrDownloadExternal
            if [[ -n "$CLONED_EXTERNAL" ]] && [[ -f "$MAIN_PATH/../$CLONED_EXTERNAL" ]]; then
                SECTION="$CLONED_EXTERNAL_FILE"
            else
                SECTION="$EXTERNAL_TEMP"
            fi
        fi
        getConvertableRulesForHosts "$SECTION"
        convertToHosts
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            sed -i "1s|^|#@ >>>>>>>> $EXTERNAL => hosts\n|" "$HOSTS_TEMP"
            echo "#@ <<<<<<<< $EXTERNAL => hosts" >>"$HOSTS_TEMP"
        fi
        includeSection "HOSTSinclude"
    done


    #
    # @COMBINEHOSTSinclude
    # ------------------------------------------------------------------------------------
    END_HOSTSCOMBINE=$(grep -oic '@COMBINEHOSTSinclude' "${TEMPLATE}")

    # Combine local and external sections into one and glue them to the right places
    for ((n = 1; n <= END_HOSTSCOMBINE; n++)); do
        initCVars "COMBINEHOSTSinclude"
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            getOrDownloadExternal
            if [[ -n "$CLONED_EXTERNAL" ]] && [[ -f "$MAIN_PATH/../$CLONED_EXTERNAL" ]]; then
                SECTION="$CLONED_EXTERNAL_FILE"
            else
                SECTION="$EXTERNAL_TEMP"
            fi
        else
            SECTION=${SECTIONS_DIR}/$(awk '$1 == "@COMBINEHOSTSinclude" { print $3; exit }' "$FINAL").${SECTIONS_EXT}
        fi
        getConvertableRulesForHosts "$LOCAL"
        getConvertableRulesForHosts "$SECTION"
        convertToHosts
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            sed -i "1s|^|#@ >>>>>>>> $EXTERNAL + $(basename "$LOCAL") => hosts\n|" "$HOSTS_TEMP"
            echo "#@ <<<<<<<< $EXTERNAL + $(basename "$LOCAL") => hosts" >>"$HOSTS_TEMP"
        fi
        includeSection "COMBINEHOSTSinclude"
    done


    #
    # @DOMAINSinclude
    # ------------------------------------------------------------------------------------
    END_DOMAINS=$(grep -oic '@DOMAINSinclude' "${TEMPLATE}")

    # Convert to domains and add filter section/list content to the right places
    for ((n = 1; n <= END_DOMAINS; n++)); do
        initVars "DOMAINSinclude"
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            getOrDownloadExternal
            if [[ -n "$CLONED_EXTERNAL" ]] && [[ -f "$MAIN_PATH/../$CLONED_EXTERNAL" ]]; then
                SECTION="$CLONED_EXTERNAL_FILE"
            else
                SECTION="$EXTERNAL_TEMP"
            fi
        fi
        getConvertableRulesForHosts "$SECTION"
        convertToDomains
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            sed -i "1s|^|#@ >>>>>>>> $EXTERNAL => domains\n|" "$HOSTS_TEMP"
            echo "#@ <<<<<<<< $EXTERNAL => domains" >>"$HOSTS_TEMP"
        fi
        includeSection "DOMAINSinclude"
    done


    #
    # @COMBINEDOMAINSinclude
    # ------------------------------------------------------------------------------------
    END_DOMAINSCOMBINE=$(grep -oic '@COMBINEDOMAINSinclude' "${TEMPLATE}")

    # Combine local and external sections into one and glue them to the right places
    for ((n = 1; n <= END_DOMAINSCOMBINE; n++)); do
        initCVars "COMBINEDOMAINSinclude"
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            getOrDownloadExternal
            if [[ -n "$CLONED_EXTERNAL" ]] && [[ -f "$MAIN_PATH/../$CLONED_EXTERNAL" ]]; then
                SECTION="$CLONED_EXTERNAL_FILE"
            else
                SECTION="$EXTERNAL_TEMP"
            fi
        else
            SECTION=${SECTIONS_DIR}/$(awk '$1 == "@COMBINEDOMAINSinclude" { print $3; exit }' "$FINAL").${SECTIONS_EXT}
        fi
        getConvertableRulesForHosts "$LOCAL"
        getConvertableRulesForHosts "$SECTION"
        convertToDomains
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            sed -i "1s|^|#@ >>>>>>>> $EXTERNAL + $(basename "$LOCAL") => domains\n|" "$HOSTS_TEMP"
            echo "#@ <<<<<<<< $EXTERNAL + $(basename "$LOCAL") => domains" >>"$HOSTS_TEMP"
        fi
        includeSection "COMBINEDOMAINSinclude"
    done


    #
    # @PHinclude
    # ------------------------------------------------------------------------------------
    END_PH=$(grep -oic '@PHinclude' "${TEMPLATE}")

    # Convert to PiHole-compatible regex format and add filter section/list content to the
    # right places
    for ((n = 1; n <= END_PH; n++)); do
        initVars "PHinclude"
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            getOrDownloadExternal
            if [[ -n "$CLONED_EXTERNAL" ]] && [[ -f "$MAIN_PATH/../$CLONED_EXTERNAL" ]]; then
                SECTION="$CLONED_EXTERNAL_FILE"
            else
                SECTION="$EXTERNAL_TEMP"
            fi
        fi
        getConvertableRulesForPH "$SECTION"
        convertToPihole
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            sed -i "1s|^|#@ >>>>>>>> $EXTERNAL => Pi-hole RegEx\n|" "$PH_TEMP"
            echo "#@ <<<<<<<< $EXTERNAL => Pi-hole RegEx" >>"$PH_TEMP"
        fi
        includeSection "PHinclude"
    done


    #
    # @COMBINEPHinclude
    # ------------------------------------------------------------------------------------
    END_PHCOMBINE=$(grep -oic '@COMBINEPHinclude' "${TEMPLATE}")

    # Convert to PiHole-compatible regex format and combine local and external sections
    # into one and glue them to the right places
    for ((n = 1; n <= END_PHCOMBINE; n++)); do
        initCVars "COMBINEPHinclude"
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            getOrDownloadExternal
            if [[ -n "$CLONED_EXTERNAL" ]] && [[ -f "$MAIN_PATH/../$CLONED_EXTERNAL" ]]; then
                SECTION="$CLONED_EXTERNAL_FILE"
            else
                SECTION="$EXTERNAL_TEMP"
                externalCleanup
            fi
        else
            SECTION=${SECTIONS_DIR}/$(awk '$1 == "@COMBINEPHinclude" { print $3; exit }' "$FINAL").${SECTIONS_EXT}
        fi
        # shellcheck disable=SC2016
        if grep -qo '^||.*\*.*^$' "$LOCAL" || grep -qo '^||.*\*.*^$all$' "$LOCAL"; then
            getConvertableRulesForPH "$LOCAL"
            getConvertableRulesForPH "$SECTION"
            convertToPihole
        else
            getConvertableRulesForPH "$SECTION"
            convertToPihole
            cat "$LOCAL" >>"$PH_TEMP"
            sort -uV -o "$PH_TEMP" "$PH_TEMP"
        fi
        if [[ "$EXTERNAL" =~ ^(http(s):|ftp:) ]]; then
            sed -i "1s|^|#@ >>>>>>>> $EXTERNAL + $(basename "$LOCAL") => Pi-hole RegEx\n|" "$PH_TEMP"
            echo "#@ <<<<<<<< $EXTERNAL + $(basename "$LOCAL") => Pi-hole RegEx" >>"$PH_TEMP"
        fi
        includeSection "COMBINEPHinclude"
    done

    # Remove unnecessary instructions from the final file
    sed -i '/@path /d' "$FINAL"
    sed -i '/@sectionsExt /d' "$FINAL"

    # Go to the directory where the local git repository is located
    cd "$MAIN_PATH" || exit

    # Set a code name (shorter filter list name) to describe the commit depending on what
    # is typed in the "Codename:" field. If there is no such field, codename=nazwa_pliku.
    if grep -q "! Codename" "$i"; then
        filter=$(grep -oP -m 1 '! Codename: \K.*' "$i")
    else
        # shellcheck disable=SC2034
        filter="$FILTERLIST"
    fi

    # Setting the time zone
    TIMEZONE=$(grep -oP -m 1 '@tz \K.*' "$CONFIG")
    if [ -n "$TIMEZONE" ]; then
        export TZ="$TIMEZONE"
    fi

    # Delete a copy of the initial file
    if [ -f "$FINAL_B" ]; then
        rm -r "$FINAL_B"
    fi


    # Update the date and time in the "Last modified" field
    if grep -q '@modified' "$i"; then
        export LC_TIME="en_US.UTF-8"
        modified=$(date +"$(grep -oP -m 1 '@dateFormat \K.*' "$CONFIG")")
        sed -i "s|@modified|$modified|g" "$i"
    fi

    # Version update
    VERSION_FORMAT=$(grep -oP -m 1 '@versionFormat \K.*' "$CONFIG")
    if [[ "$VERSION_FORMAT" = "Year.Month.NumberOfCommitsInMonth" ]]; then
        version=$(date +"%Y").$(date +"%-m").$(git rev-list --count HEAD --after="$(date -d "-$(date +%d) days " "+%Y-%m-%dT23:59")" "$FINAL")
    elif [[ "$VERSION_FORMAT" = "Year.Month.Day.TodayNumberOfCommits" ]]; then
        version=$(date +"%Y").$(date +"%-m").$(date +"%-d").$(($(git rev-list --count HEAD --before="$(date '+%F' --date="tomorrow")"T24:00 --after="$(date '+%F' -d "1 day ago")"T23:59 "$FINAL")))
    elif grep -q -oP -m 1 '@versionDateFormat \K.*' "$CONFIG"; then
        version=$(date +"$(grep -oP -m 1 '@versionDateFormat \K.*' "$CONFIG")")
    else
        version=$(date +"%Y%m%d%H%M")
    fi

    if grep -q '@version' "$i"; then
        sed -i "s|@version|$version|g" "$i"
    fi
done
