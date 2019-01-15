if [ "$1" = "pull-sync" ]; then
    echo "> EXTRA SCRIPT"
    /var/www/vhosts/example.com/htdocs/bin/console cache:clear --no-warmup
    echo "< EXTRA SCRIPT"
fi
