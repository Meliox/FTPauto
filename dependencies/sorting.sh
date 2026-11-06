#!/bin/bash
# Version 0.4

# Function to sort files based on their names
function sortFiles {
    # $1 is the argument passed using --sort=<Directory>. No trailing slash is needed
    if [[ -n "$1" ]]; then
        if [[ "$1" == "nosort" ]]; then
            msg plain "INFO: No sorting. Transferring to default complete directory: \"$complete\""
        else
            complete="${complete}${1}/"
            msg plain "INFO: Sorted to ${complete}"
        fi
    # Check file name patterns and sort accordingly
    elif [[ $orig_name =~ (\.(x86|x64|mac|android|iphone)) ]]; then
        complete=$complete"Appz/"
        msg plain "INFO: Sorted to ${complete}"
    elif [[ $orig_name =~ (PAL|NTSC|HDDVD|BluRay|WEB-DL|WEB|BDRip|DVDRip).+(DVDR|XviD|x264|x265|H(264|265)|H\.(264|265)) ]] && [[ ! $orig_name =~ (S[0-9][0-9]) ]] && [[ ! $orig_name =~ (S[0-9][0-9]E[0-9][0-9]) ]] && [[ ! $orig_name =~ (E[0-9][0-9]) ]] && [[ ! $orig_name =~ (S[0-9][0-9]) ]] && [[ ! $orig_name =~ (\.(episode|ep|e|Part|pt)\.(([0-9][0-9]?)|(I|II|III|IV|V|VI|VII|VIII|IIX|IX|X|XI|XII))\.) ]]  && [[ ! $orig_name =~ ([[:digit:]](x|of)[[:digit:]]) ]]; then
        complete=$complete"MOVIES/"
        msg plain "INFO: Sorted to ${complete}"
    elif [[ $orig_name =~ \.XXX\. ]]; then
        complete=$complete"XXX/"
        msg plain "INFO: Sorted to ${complete}"
    elif [[ $orig_name =~ (S[0-9][0-9]E[0-9][0-9]) ]] || [[ $orig_name =~ (\.E[0-9][0-9]?[0-9]?\.) ]] || [[ $orig_name =~ (S[0-9][0-9]) ]] || [[ $orig_name =~ (\.(episode|ep|e|Part|pt)\.(([0-9][0-9]?)|(I|II|III|IV|V|VI|VII|VIII|IIX|IX|X|XI|XII))\.) ]]  || [[ $orig_name =~ ([[:digit:]](x|of)[[:digit:]]) ]] || [[ $orig_name =~ ([[:digit:]]{4}.[[:digit:]]{2}.[[:digit:]]{2})|([[:digit:]]{2}.[[:digit:]]{2}.[[:digit:]]{4}) ]]; then
        # Sort to series folders if format matches
        local series_name="${orig_name%%.S[[:digit:]]*}"
        if [[ $orig_name == $series_name ]]; then
            complete=$complete"TV/"
            msg plain "INFO: Series name could not be found"
            msg plain "INFO: Sorted to: ${complete}"
        else
            series_name="${series_name//./ }" # replace dots with spaces 
            msg -n white "INFO: Series name: "
            msg success "$series_name"
            complete=$complete"TV/$series_name/"
            msg plain "INFO: Sorted to: ${complete}"
        fi
    else
        msg warning "INFO: Category could not be parsed"
        msg plain "INFO: Moving files upon finish to default directory: \"$complete\""
    fi
}
