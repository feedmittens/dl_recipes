#!/bin/bash
mkdir -p recipes
API="https://en.wikibooks.org/w/api.php"

declare -A visited
count=0

fetch_category() {
    local category="$1"
    echo "Fetching category: $category"

    local cmcontinue=""

    while :; do
        # Fetch members of the category (pages + subcategories)
        response=$(curl -s "$API?action=query&list=categorymembers&cmtitle=$category&cmlimit=500&format=json&cmcontinue=$cmcontinue")

        # Process each member
        echo "$response" | jq -r '.query.categorymembers[] | [.pageid, .title, .ns] | @tsv' | while IFS=$'\t' read -r pageid title ns; do
            if [ "$ns" -eq 14 ]; then
                # ns=14 = Category → recurse
                subcat=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$title")
                if [[ -z "${visited[$subcat]}" ]]; then
                    visited[$subcat]=1
                    fetch_category "$subcat"
                fi
            else
                # ns != 14 = actual recipe page
                slug=$(echo "$title" | tr ' ' '_' | tr ':' '_')
                echo "Downloading recipe: $title"
                encoded=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$title")
                curl -s "$API?action=parse&page=$encoded&prop=wikitext&format=json" \
                  | jq -r '.parse.wikitext["*"] // empty' > "recipes/${slug}.txt"
                ((count++))
            fi
        done

        # Handle continuation
        cmcontinue=$(echo "$response" | jq -r '.continue.cmcontinue // empty')
        if [ -z "$cmcontinue" ]; then
            break
        fi
    done
}

# Start from the root category
fetch_category "Category:Recipes"

echo "✅ Done! Downloaded $count recipes in total."

