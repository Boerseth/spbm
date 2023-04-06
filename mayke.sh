posts=$(find posts -type f -name '*.md')


echo -n "Verifying headers..."
for file in $posts; do
    header=$(head -n 1 $file)
    valid_format=$(echo $header | grep "^# 20[0-9][0-9]-[01][0-9]-[0-3][0-9] .*$")
    [[ $valid_format ]] && continue
    echo "Error in file $file: $header"
    exit 1
done
echo "OK!"


echo -n "Converting to HTML..."
rm -rf temp
mkdir temp
mkdir temp/articles
touch temp/articles.html
touch temp/table_of_contents

for file in $posts; do
    header=$(head -n 1 $file)
    date=${header:2:10}
    title=${header:13}

    # Create URL-fragment and article-id by normalizing header
    article_id="#$(echo $header | sed -e 's/ /-/g' -e 's/[^-0-9A-Za-z]//g')"

    # Add link to TOC
    toc_item="<li><a href=\"$article_id\">${header:2}</a></li>"
    echo $toc_item >> temp/table_of_contents

    # Create html-file of article:
    tail -n +2 $file | pandoc > temp/article.html
    sed -e "s/<\!-- ARTICLE-ID -->/$article_id/" \
        -e "s/<\!-- TITLE -->/$title/" \
        -e "s/<\!-- DATE -->/$date/" \
        -e "/<\!-- ARTICLE -->/ r temp/article.html" \
        templates/article.html >> temp/articles/$date.html
done
# Sort Articles from newest to oldest
sort temp/table_of_contents --reverse -o temp/table_of_contents
articles=$(find temp/articles -type f -name '*.html' | sort --reverse)
cat $articles >> temp/articles.html
echo "OK!"


echo -n "Building page..."
rm -rf page
mkdir page
cp media/* page/
sed -e '/<\!-- TOC -->/ r temp/table_of_contents' \
    -e '/<\!-- ARTICLES -->/ r temp/articles.html' \
    templates/index.html >> page/index.html
echo "OK!"


echo -n "Cleaning up..."
rm -rf temp
echo "OK!"
