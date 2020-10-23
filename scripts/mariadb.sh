#!/usr/bin/env sh
set -eu
container_name="some-mariadb"
cid=$(docker container ls -a -f name="${container_name}" -q)
if [ -z "${cid}" ]
then
    docker run --name ${container_name} -e MYSQL_ROOT_PASSWORD=dev -v ${HOME}/work/jsu:/jsu -d mariadb
else
    docker start ${container_name}
fi

spin()
{
    spinstr="/-\\|"
    printf "\b%s" $( echo "${spinstr}" | sed -e \
            "s/.\{0,$(( $1 % ${#spinstr} ))\}\(.\).*/\1/" )
}

printf "Connect to MariaDB...  "
counter=0
set +e
while true
do
    message=$(docker exec ${container_name} sh -c "mysqladmin ping -uroot -pdev 2>&1")
    if [ "${message}" = "mysqld is alive" ]
    then
        printf "\b \b\n\n" 
        docker exec -it ${container_name} sh -c "mysql -uroot -pdev"
        break
    fi
    spin ${counter}
    counter=$(( ${counter} + 1 ))
done
set -e

docker stop ${container_name} > /dev/null
