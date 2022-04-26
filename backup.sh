#!/bin/bash


#### Объявляем переменные

BACKUP_LOCK=/var/lock/backup_vm.lock
BACKUP_LOG=/var/log/backup.log
USED_SPACE=95
BACKUP_DURATION=30
REMOTE_BACKUP_DIR=backup                
USER=backup
PASSWORD="123654"
REMOTE_HOST=192.168.88.33     
BACKUP_DIR=/opt/nas
DT=`date '+%Y%m%d'`
BACKUP_SRC=/opt/Share
DBHOST="localhost"
DBNAME="our_site"
DBUSER="site_user"
DBPASS="db_secure_pass"


#### Объявляем функции 

function toLog {
    local message=$1
    echo "[`date \"+%F %T\"`] ${message}" >> $BACKUP_LOG
}

function checkUsedSpace {
        if [[ `df -h|grep //$REMOTE_HOST/$REMOTE_BACKUP_DIR|awk '{print $5}'|sed 's/%//g'` -ge $USED_SPACE ]]; then
                toLog "Used space on $REMOTE_HOST:$REMOTE_BACKUP_DIR higher then $USED_SPACE%."
                toLog "END"
                toLog ""
                rm -f $BACKUP_LOCK
                umount $BACKUP_DIR
                exit
        fi
}

function checkBackupDir {
        local backup_duration=$1
        find $BACKUP_DIR/$host/$backup_level -type f -mtime +$backup_duration -exec rm -rf {} \;
}



#### Алгоритм.

# Подготовительные операции

#проверяем по файлу-маркеру не запущен ли уже скрипт, если да, то ждем.
while [ -e $BACKUP_LOCK ]
do
    sleep 1
done

touch $BACKUP_LOCK #создаем файл -- маркер выполнения скрипта.
toLog "START"

#монтируем хранилище с бэкапами
mount -t cifs //$REMOTE_HOST/$REMOTE_BACKUP_DIR $BACKUP_DIR -o username=$USER,password=$PASSWORD,rw > /dev/null 2>&1
#проверяем успешность монтирования хранилища бэкапов и наличие свободного места по установленному лимиту
if [ $? -ne 0 ]; then 
        if [[ `df -h|grep //$REMOTE_HOST/$REMOTE_BACKUP_DIR|awk '{print $1 $6}'` == "//$REMOTE_HOST/$REMOTE_BACKUP_DIR$BACKUP_DIR" ]]; then
                checkUsedSpace
        else
                toLog "Problems with mounting directory"
                toLog "END"
                toLog ""
                rm -f $BACKUP_LOCK
                exit
        fi
fi

#### Механизм бекапа #####

#дамп бд sql 
mysqldump -u $DBUSER -p$DBPASS -h $DBHOST $DBNAME > /tmp/our_site.sql
#архивирование директории и бд в 1 архив с датой в названии 
tar -c $BACKUP_SRC /tmp/our_site.sql | pbzip2 -p4 -c > $BACKUP_DIR/$DT.tar.bz2


######

toLog "END"
toLog ""

umount $BACKUP_DIR #размонтируем хранилище бэкапов
rm -rf /tmp/our_site.sql #удаляем временные файлы
rm -f $BACKUP_LOCK #удаляем файл-маркер выполнения

exit
