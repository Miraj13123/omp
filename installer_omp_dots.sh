#!/bin/bash
#learn apply_theme and custom_theme_install function thoroughly


# Determine the source directory based on execution context
if [ -d "omp" ]; then
    # Called from root of repo
    SCRIPT_DIR="omp"
else
    # Called from within kitty folder
    SCRIPT_DIR="."
fi

INSTALL_DIR=$(cat "$SCRIPT_DIR/details.log" | grep -E "Install Directory: " | awk '{print $NF}')
INSTALL_DIR=$(whereis oh-my-posh | awk '{sub(/^[^:]+: /, ""); sub(/\/[^/]+$/, ""); print}')
#echo "$INSTALL_DIR"

THEMES_DIR="$HOME/.cache/oh-my-posh/themes"
#app="$INSTALL_DIR/oh-my-posh"
#echo "$app"

prompt_user(){
    local msg="$1"
    local response
    for(( i=0;i<3;i++ ));do
        read -p "$msg, [y/Y] : " response
        if [[ "$response" == "y" || "$response" == "Y" ]];then
            return 0
        elif [[ "$response" == "n" || "$response" == "N" ]];then
            return 1
        fi
    done
    return 1
}

cmd_exists(){ 
    command -v "$1" >/dev/null 2>&1
    return "$?"
}

install_omp(){
    if cmd_exists oh-my-posh;then
        echo "'Oh-My-Posh' is already installed, exiting"
        return 0
    fi

    # Store the output of the command
    output=$(curl -s https://ohmyposh.dev/install.sh | bash -s)

    # for users
    echo "$output"

    # Extract each location and assign to variables
    INSTALL_DIR=$(echo "$output" | grep 'Installing oh-my-posh for linux-amd64 in' | awk '{print $NF}')
    THEMES_DIR=$(echo "$output" | grep 'Installing oh-my-posh themes in' | awk '{print $NF}')


    if cmd_exists oh-my-posh;then
        echo "'Oh-My-Posh' is installed successfully"
        custom_json_install force
        return 0
    else
        echo "'Oh-My-Posh' installation failed"
        return 1
    fi

    # Print the variables to verify
    #echo "Install Directory: $INSTALL_DIR"
    #echo "Download URL: $DOWNLOAD_URL"
    #echo "Themes Directory: $THEMES_DIR"
}
omp_installer() {
    if prompt_user "Do you want to install 'Oh-My-Posh'?";then
        echo "installing 'Oh-My-Posh' on your system ..."
        if ! install_omp;then
            return 1;
        fi

        if [ ! -f "$SCRIPT_DIR/details.log" ];then touch "$SCRIPT_DIR/details.log";fi

        echo "Install Directory: $INSTALL_DIR" > "$SCRIPT_DIR/details.log"
        echo "Themes Directory: $THEMES_DIR" >> "$SCRIPT_DIR/details.log"
        local temp=$(grep -E "$INSTALL_DIR" "$HOME/.bashrc")
        if [[ "$temp" == "" ]];then
            echo appending
            echo "PATH=\"\$PATH:$INSTALL_DIR\"" >> "$HOME/.bashrc";
        else
            echo "already included in system path"
        fi
        return 0
    else
        echo "aborting 'Oh-My-Posh' installation"
        return 1
    fi
}
custom_json_install() {
    local target_jsons="$THEMES_DIR"/*.json
    local custom_jsons=("$SCRIPT_DIR/custom"/*.json)

    # Ensure variables are defined
    if [ -z "$THEMES_DIR" ] || [ -z "$SCRIPT_DIR" ]; then
        echo "Error: THEMES_DIR or SCRIPT_DIR is not set" >&2
        return 1
    fi

    # Check if source and destination directories exist
    if [ ! -d "$SCRIPT_DIR/custom" ]; then
        echo "Error: $SCRIPT_DIR/custom does not exist" >&2
        return 1
    fi
    if [ ! -d "$THEMES_DIR" ]; then
        echo "Error: $THEMES_DIR does not exist" >&2
        return 1
    fi

    # Check if any .json files exist
    if [ ${#custom_jsons[@]} -eq 0 ] || [ ! -f "${custom_jsons[0]}" ]; then
        echo "No .json files found in $SCRIPT_DIR/custom" >&2
        return 1
    fi

    # Determine copy mode: force (-f), skip (-n), or default (error on failure)
    local cp_option=""
    case "$1" in
        "force")
            cp_option="-f"
            echo "Copy mode: Force (overwrite existing files)"
            ;;
        "skip")
            cp_option="-n"
            echo "Copy mode: Skip (do not overwrite existing files)"
            ;;
        "")
            cp_option=""
            echo "Copy mode: Default (fail if file exists)"
            ;;
        *)
            echo "Error: Invalid copy mode '$1'. Use 'force' or 'skip'." >&2
            return 1
            ;;
    esac

    # Copy each .json file to THEMES_DIR
    local success=true
    for name in "${custom_jsons[@]}"; do
        local dest_file="$THEMES_DIR/$(basename "$name")"
        if [ "$cp_option" = "-n" ] && [ -f "$dest_file" ]; then
            echo "Skipped $name (already exists in $THEMES_DIR)"
            continue
        fi
        if cp $cp_option "$name" "$THEMES_DIR/"; then
            echo "Copied $name to $THEMES_DIR"
        else
            echo "Error: Failed to copy $name to $THEMES_DIR" >&2
            success=false
        fi
    done

    # Return 1 if any copy failed, 0 otherwise
    if [ "$success" = true ]; then
        return 0
    else
        return 1
    fi
}
custom_json_install_prompt(){
    while true;do
        local cho=""
        echo "1. 'Force', replace duplicate files"
        echo "2. 'Skip', Skip already existing files"
        echo "3.  To fail if any custom file already exists"
        echo "[x] exit !!"
        read -p "Choose any option shown above: " cho
        case $cho in
            "x")
                break
                ;;
            "1")
                custom_json_install force
                ;;
            "2")
                custom_json_install skip
                ;;
            "3")
                custom_json_install
                ;;
        esac
    done
}

uninstall_omp(){
    local app="$INSTALL_DIR/oh-my-posh"
    echo "$app"
    if [ -f "$app" ];then
        rm -rf "$app" && echo "" > "$SCRIPT_DIR/details.log";
        
        local themes=$(grep -E "oh-my-posh init bash --config" "$HOME/.bashrc")
        local road=$(grep -E "$INSTALL_DIR" "$HOME/.bashrc")
        if [[ "$road" == "" ]];then
            echo "already excluded from system path"
        else
            if sed -i "s|$road||" "$HOME/.bashrc";then
                sed -i "s|$themes||" "$HOME/.bashrc";
                echo "successfull excluded from system path"
                return 0
            else
                echo "failed to exclude from system path"
                return 1
            fi
        
        fi
        return 0
    else
        echo "the executable binary couldn't be found !!";return 1
    fi
}
omp_uninstaller() {
    if prompt_user "Do you want to uninstall 'Oh-My-Posh'?";then
        if uninstall_omp;then echo uninstalled;
            if rm -rf "$HOME/.cache/oh-my-posh";then echo deleted themes;fi

            return 0
        else
            return 1
        fi
    else
        echo "aborting uninstallation";return 1
    fi
    
}

list_themes(){
    echo "$THEME_DIR"
    local JSON_FILES="$THEMES_DIR"/*.json
    
    if [ -z "${#JSON_FILES[@]}" ];then
        echo "there is no JSON files in dir: $THEMES_DIR"
    else
        local i=0
        for name in $JSON_FILES;do
            if [[ "$1" == "$i" && "$2" == "info" ]];then echo "$i. $name";return 0;fi
            if [[ "$1" == "all" ]];then echo "$i. $name";fi
            if [[ "$1" == "$i" && -z "$2" ]];then echo "$name";return 0;fi
            #echo "$i. $name";
            ((i++))
        done
    fi
}
list_themes_prompt(){
    local cho
    echo "opt: \"all\" for listing all themes"
    echo "opt: any number for listing specific theme"
    read -p "choose your option: " cho
    echo "";echo "";echo "listing starts here ---";
    if [[ "$cho" == "all" ]];then
        list_themes "all"
    else list_themes "$cho" "info"
    fi
    echo "listing ends here ---";echo ""
}
apply_theme() {
    # Get the theme path from list_themes
    local theme_path
    #theme_path=$(list_themes "$1")
    theme_path=$(list_themes "$1" | grep -E '\.json$' | tr -d '\n')
    
    # Ensure theme_path is a valid file
    if [ -f "$theme_path" ]; then echo "File found"
    else echo "Error: Theme file $theme_path does not exist" >&2;fi

    # Check if an oh-my-posh init line exists in .bashrc
    #echo "|"$HOME/.bashrc"|"
    local line
    line=$(grep -E "oh-my-posh init bash --config" "$HOME/.bashrc")
    echo "old line: |$line|"
    local new_line
    new_line="eval \"\$(oh-my-posh init bash --config $theme_path)\""
    echo "new line: |$new_line|"
    #local esc_line=$(echo "$line" | sed 's/[][\\^$.*+?{}|()/ ]/\\&/g')
    #echo "|$esc_line|"
    #local esc_new_line=$(echo "$new_line" | sed 's/[][\\^$.*+?{}|()/ ]/\\&/g')
    #echo "|$esc_new_line|"

    if [[ ! "$line" == "" ]];then
        echo changing
        if sed -i "s#$line#$new_line#" "$HOME/.bashrc";then
            echo "sed success"
        else
            echo "sed failed"
        fi
    else
        echo appending
        echo "$new_line" >> "$HOME/.bashrc";
    fi
}
theme_apply_default(){
    apply_theme 0
}
apply_theme_prompt(){
    local cho
    read -p "choose your theme with number: " cho
    apply_theme "$cho"
}


menu(){
    local info_install=""
    local enable_info=""
    if cmd_exists oh-my-posh;then info_install=" (installed)";else info_install=" (not installed)";fi
    line=$(grep -E "oh-my-posh init bash --config" "$HOME/.bashrc")
    if [[ "$line" == "" ]];then enable_info="(not enabled)"; else enable_info="(enabled)"; fi

    #clear
    while true;do
        echo "1. INSTALL oh-my-posh, $info_install"
        echo "2. enable oh-my-posh on 'bash', $enable_info"
        echo "3. add more custom themes"
        echo "4. LIST oh-my-posh themes"
        echo "5. APPLY oh-my-posh theme"
        echo "6. UNINSTALL oh-my-posh"
        echo "[x] Exit !!"

        local cho=""
        read -p "Select any option (number only): " cho
        if [[ "$cho" == "1" ]];then omp_installer
        elif [[ "$cho" == "2" ]];then theme_apply_default
        elif [[ "$cho" == "3" ]];then custom_json_install_prompt
        elif [[ "$cho" == "4" ]];then list_themes_prompt
        elif [[ "$cho" == "5" ]];then apply_theme_prompt
        elif [[ "$cho" == "6" ]];then omp_uninstaller
        elif [[ "$cho" == "x" ]];then break
        fi 
    done
    #menu
}

#omp_uninstaller
#list_themes "$1" "info"

#list_themes 2 "info"

#list_themes 1 "info"
#list_themes 1
#omp_installer
#custom_json_install
#list_themes 12
#apply_theme "$1"



#omp_uninstaller


menu