#!/bin/bash

# MySQL info to backup all database granted to this user
DB_USER='user' # Make sure have privileges with lock tables
DB_PSWD='password'
DB_HOST='localhost'
DB_PORT='3306'

# S3 bucket where the file will be stored, please use trailing slash
S3_BUCKET="s3://bucket/db/mysql-$(date +"%d-%m-%Y_%T")/"
AWS_ACCESS_KEY='access'
AWS_SECRET_KEY='secret'

# Host for Digital Ocean Spaces
S3_ENDPOINT="endpoint_server"
S3_DNS_ENDPOINT="%(bucket)s.endpoint_server"

# Temporary local place for backup
DUMP_DIR="/backup"
DUMP_LOC="$DUMP_DIR/mysql-$(date +"%d-%m-%Y_%T")"

# How long the backup in local will be kept
DAYS_OLD="3"

# Logging
DATE_BAK="$(date +"%Y-%m-%d")"
DATE_EXEC="$(date "+%d+%b")"
DATE_EXEC_H="$(date "+%d %b %Y %H:%M")"


[ ! -d $DUMP_LOC ] && mkdir -p $DUMP_LOC || :

# Output for checking
echo "["$DATE_EXEC_H"] Backup process start.. "

for DB_NAME in $(MYSQL_PWD=$DB_PSWD mysql -u $DB_USER -P $DB_PORT -e 'show databases' | sed 1d)
do
    if [ $DB_NAME != 'information_schema' ] && [ $DB_NAME  != 'performance_schema' ] && [ $DB_NAME != 'test' ] && [ $DB_NAME != 'mysql' ]
    then
        START_TIME="$(date +"%s")"

        echo "Backing up "$DB_NAME"..."
        MYSQL_PWD=$DB_PSWD mysqldump --add-drop-table --lock-tables=true -u $DB_USER -h $DB_HOST -P $DB_PORT $DB_NAME | gzip -9 > $DUMP_LOC/$DB_NAME-$DATE_BAK.sql.gz

        # Counting filezie
        FILESIZE="$(ls -lah $DUMP_LOC/$DB_NAME-$DATE_BAK.sql.gz | awk '{print $5}')"

        echo "Send "$DB_NAME" to Amazon S3..."
        s3cmd --acl-private --delete-removed --skip-existing --no-preserve --host=$S3_ENDPOINT --host-bucket=$S3_DNS_ENDPOINT --access_key=$AWS_ACCESS_KEY --secret_key=$AWS_SECRET_KEY sync $DUMP_LOC/ $S3_BUCKET

        END_TIME="$(date +"%s")"
        DIFF_TIME=$(( $END_TIME - $START_TIME ))
        H=$(($DIFF_TIME/3600))
        M=$(($DIFF_TIME%3600/60))
        S=$(($DIFF_TIME%60))

        TWT_MSG="$DATE_EXEC+|+$DB_NAME+($FILESIZE)+in+$H+hour(s)+$M+minute(s)+$S+seconds"

        echo "Done: "$TWT_MSG
    fi
done

echo "Removing old files..."
find $DUMP_DIR/* -mtime +$DAYS_OLD -exec rm -rf {} \;